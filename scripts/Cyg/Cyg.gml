/// @ignore [MAJOR-MINOR-PATCH]
#macro __CYG_VERSION			"4.0.0"
/// @ignore Show warning messages in the console.
#macro __CYG_DEBUG_WARNINGS		true
/// @ignore Show error messages in the console.
#macro __CYG_DEBUG_ERRORS		true
/// @ignore If true, fatal errors crash the game.
#macro __CYG_STRICT_MODE		false
/// @ignore Whether to create a backup (.bak) before overwriting save files.
#macro __CYG_USE_BACKUPS		true
/// @ignore Whether to compress buffers before saving.
#macro __CYG_USE_COMPRESS		false
/// @ignore Default master key for ChaCha20-Poly1305 (32 ASCII bytes in an array).
#macro CYG_MASTER_KEY			[67, 89, 71, 95, 77, 65, 83, 84, 69, 82, 95, 75, 69, 89, 95, 68, 69, 70, 65, 85, 76, 84, 95, 51, 50, 95, 66, 89, 84, 69, 83, 33]

/// @ignore XOR mask used to obfuscate encryption keys when provided as a byte array. This is not a security mechanism, only light obfuscation to avoid plain-text keys in code.
#macro __CYG_XOR_MASK			42
/// @ignore Depth used when creating the Cyg manager object.
#macro __CYG_MANAGER_DEPTH		-10000

show_debug_message($"Cyg: Cyg v{__CYG_VERSION}. Made by toto.");

/// @desc Simple and robust save/load system.
/// Manages game data, stores it as JSON,
/// supports optional encryption,
/// and handles save migrations through fixer functions.
function Cyg()
{
	/// @ignore Main in-memory data store.
    static __data = 
	{
        __cyg_version: __CYG_VERSION,
        __file_version: -1,
    };
	
	/// @ignore Encryption key used by Export/Import.
	static __custom_key = undefined;
    
	/// @ignore Current save-data version.
    static __version = -1;

	/// @ignore Struct that stores migration fixer functions per version.
    static __fixers = {};

	/// @ignore Avoids repeating warnings for invalid master keys.
	static __master_key_warned = false;

	/// @ignore DS map used to track pending async operations.
	static async_requests = ds_map_create();
    
	#region Private Methods

	/// @ignore Converts a byte array into a string.
	static __Cyg_Byte_Array_To_String = function(_bytes)
	{
		if (!is_array(_bytes) || array_length(_bytes) <= 0) return "";

		var _key = "";
		var i = 0;
		repeat(array_length(_bytes))
		{
			var _ascii = ((_bytes[i] & 255) mod 95) + 32;
			_key += chr(_ascii);
			i++;
		}

		return _key;
	}

	/// @ignore Expands an arbitrary key into 32 bytes for ChaCha20.
	static __Cyg_Derive_ChaCha_Key32 = function(_source_key)
	{
		var _src_len = string_byte_length(_source_key);
		if (_src_len <= 0) return "";

		if (_src_len == 32) return _source_key;

		var _out = array_create(32, 0);
		var i = 0;
		repeat(32)
		{
			var _src = string_byte_at(_source_key, (i mod _src_len) + 1);
			_out[i] = (_src + ((i * 73) & 255) + ((_src_len * 17) & 255)) & 255;
			i++;
		}

		var _round = 0;
		repeat(4)
		{
			i = 0;
			repeat(32)
			{
				var _mix = string_byte_at(_source_key, ((i + _round) mod _src_len) + 1);
				var _prev = _out[(i + 31) mod 32];
				_out[i] = (_out[i] ^ ((_mix + _prev + i + (_round * 11)) & 255)) & 255;
				i++;
			}
			_round++;
		}

		return __Cyg_Byte_Array_To_String(_out);
	}

	/// @ignore Validates CYG_MASTER_KEY (array of 32 numeric bytes 0..255).
	static __Cyg_Is_Master_Key_Valid = function()
	{
		if (!is_array(CYG_MASTER_KEY)) return false;
		if (array_length(CYG_MASTER_KEY) != 32) return false;

		var i = 0;
		repeat(32)
		{
			var _b = CYG_MASTER_KEY[i];
			if (!is_real(_b)) return false;
			if (_b < 0 || _b > 255) return false;
			i++;
		}

		return true;
	}

	/// @ignore Returns the effective key: custom key (if set) or CYG_MASTER_KEY.
	static __Cyg_Get_Effective_Key = function()
	{
		if (!is_undefined(__custom_key))
		{
			return __custom_key;
		}

		if (!__Cyg_Is_Master_Key_Valid())
		{
			if (!__master_key_warned)
			{
				__cyg_error("CYG_MASTER_KEY is invalid. It must be an array of 32 ASCII values between 0 and 255.");
				__master_key_warned = true;
			}
			return "";
		}

		return __Cyg_Byte_Array_To_String(CYG_MASTER_KEY);
	}

	/// @ignore Indicates whether a valid key is available for encrypt/decrypt.
	static __Cyg_Has_Encryption_Key = function()
	{
		var _key = __Cyg_Get_Effective_Key();
		return string_byte_length(_key) > 0;
	}

	/// @ignore Generates a random 12-byte nonce for ChaCha20-Poly1305.
	static __Cyg_Generate_Nonce = function()
	{
		var _nonce = "";
		var i = 0;
		repeat(12)
		{
			_nonce += chr(irandom_range(32, 126));
			i++;
		}

		return _nonce;
	}

	/// @ignore Returns timestamp in YYYYMMDD_HHMMSS format.
	static __Cyg_Get_Timestamp = function()
	{
		var _dt = date_current_datetime();
		var _year = string_format(date_get_year(_dt), 4, 0);
		var _month = string_format(date_get_month(_dt), 2, 0);
		var _day = string_format(date_get_day(_dt), 2, 0);
		var _hour = string_format(date_get_hour(_dt), 2, 0);
		var _minute = string_format(date_get_minute(_dt), 2, 0);
		var _second = string_format(date_get_second(_dt), 2, 0);

		return $"{_year}{_month}{_day}_{_hour}{_minute}{_second}";
	}

	/// @ignore Validates file path format without restricting valid desktop absolute paths.
	static __Cyg_Validate_IO_Path = function(_path, _operation)
	{
		if (!is_string(_path))
		{
			__cyg_error($"{_operation}: path must be a string.");
			return false;
		}

		var _trimmed = string_trim(_path);
		if (string_length(_trimmed) <= 0)
		{
			__cyg_error($"{_operation}: path cannot be empty.");
			return false;
		}

		var _len = string_length(_trimmed);
		for (var _i = 1; _i <= _len; ++_i)
		{
			if (string_byte_at(_trimmed, _i) == 0)
			{
				__cyg_error($"{_operation}: path contains null bytes and has been rejected.");
				return false;
			}
		}

		// File APIs expect local/sandbox paths, not URL schemes.
		if (string_pos("://", _trimmed) > 0)
		{
			__cyg_error($"{_operation}: URL-style paths are not supported by file APIs ('{_trimmed}').");
			return false;
		}

		return true;
	}

	/// @ignore Returns the latest backup path for a save file (timestamped or legacy .bak).
	static __Cyg_Find_Latest_Backup_Path = function(_path)
	{
		var _best = undefined;
		var _legacy = _path + ".bak";
		if (file_exists(_legacy)) _best = _legacy;

		var _mask = _path + "_*.bak";
		var _item = file_find_first(_mask, 0);
		if (_item != "")
		{
			if (is_undefined(_best) || _item > _best) _best = _item;

			_item = file_find_next();
			while (_item != "")
			{
				if (_item > _best) _best = _item;
				_item = file_find_next();
			}

			file_find_close();
		}

		return _best;
	}

	/// @ignore Encrypts with ChaCha20-Poly1305 and packs nonce+tag+ciphertext.
	static __Cyg_ChaCha_Encrypt_Packed = function(_plain_buffer, _key)
	{
		var _key32 = __Cyg_Derive_ChaCha_Key32(_key);
		if (string_byte_length(_key32) != 32)
		{
			__cyg_error("ChaCha20-Poly1305: could not derive a 32-byte key.");
			return undefined;
		}

		var _nonce = __Cyg_Generate_Nonce();
		var _enc = chacha20_poly1305_encrypt(_plain_buffer, _key32, _nonce, undefined, 1);
		if (!(_enc[$ "success"] ?? false))
		{
			return undefined;
		}

		var _cipher = _enc[$ "ciphertext_buffer"];
		var _tag = _enc[$ "tag_buffer"];
		var _cipher_size = buffer_get_size(_cipher);
		var _packed = buffer_create(12 + 16 + _cipher_size, buffer_fixed, 1);

		buffer_write(_packed, buffer_string, _nonce);
		buffer_seek(_packed, buffer_seek_start, 12);
		buffer_copy(_tag, 0, 16, _packed, 12);
		buffer_copy(_cipher, 0, _cipher_size, _packed, 28);
		buffer_seek(_packed, buffer_seek_start, 0);

		buffer_delete(_cipher);
		buffer_delete(_tag);

		return _packed;
	}

	/// @ignore Decrypts a packed nonce+tag+ciphertext buffer.
	static __Cyg_ChaCha_Decrypt_Packed = function(_packed_buffer, _key)
	{
		var _size = buffer_get_size(_packed_buffer);
		if (_size < 28)
		{
			__cyg_error("ChaCha20-Poly1305: buffer cifrado inválido (muy pequeño).");
			return undefined;
		}

		var _key32 = __Cyg_Derive_ChaCha_Key32(_key);
		if (string_byte_length(_key32) != 32)
		{
			__cyg_error("ChaCha20-Poly1305: could not derive a 32-byte key.");
			return undefined;
		}

		var _nonce_buf = buffer_create(12, buffer_fixed, 1);
		buffer_copy(_packed_buffer, 0, 12, _nonce_buf, 0);
		buffer_seek(_nonce_buf, buffer_seek_start, 0);
		var _nonce = buffer_read(_nonce_buf, buffer_string);
		buffer_delete(_nonce_buf);

		var _tag = array_create(16, 0);
		var i = 0;
		repeat(16)
		{
			buffer_seek(_packed_buffer, buffer_seek_start, 12 + i);
			_tag[i] = buffer_read(_packed_buffer, buffer_u8);
			i++;
		}

		var _cipher_size = _size - 28;
		var _cipher = buffer_create(_cipher_size, buffer_fixed, 1);
		buffer_copy(_packed_buffer, 28, _cipher_size, _cipher, 0);

		var _dec = chacha20_poly1305_decrypt(_cipher, _key32, _nonce, _tag, undefined, 1);
		buffer_delete(_cipher);

		if (!(_dec[$ "success"] ?? false) || !(_dec[$ "tag_ok"] ?? false))
		{
			return undefined;
		}

		return _dec[$ "plaintext_buffer"];
	}

	/// @desc RC4 stream cipher. It is symmetric, so the same operation is used for encryption and decryption.
	/// @param {Buffer} buffer_data Buffer containing input data.
	/// @param {String} key Encryption key.
	/// @ignore 
	static __Cyg_RC4 = function(_buffer_data, _key)
	{
		var S = array_create(256);
		var i = 0;
		repeat(256) { S[i] = i; i++; }
		
		var j = 0;
		var _key_len = string_length(_key);
		
		i = 0; repeat(256)
		{
			j = (j + S[i] + string_byte_at(_key, (i % _key_len) + 1)) & 255;
			var _temp = S[i];
			S[i] = S[j];
			S[j] = _temp;
			i++;
		}

		i = 0; 
		j = 0;
		
		// RC4-drop to reduce known early-keystream statistical weaknesses.
		repeat(256)
		{
			i = (i + 1) & 255;
			j = (j + S[i]) & 255;
			var _temp = S[i];
			S[i] = S[j];
			S[j] = _temp;
		}

		var _data_len = buffer_get_size(_buffer_data);
		var _result_buffer = buffer_create(_data_len, buffer_fixed, 1);
		buffer_seek(_buffer_data, buffer_seek_start, 0);

		repeat(_data_len)
		{
			i = (i + 1) & 255;
			j = (j + S[i]) & 255;

			var _temp = S[i];
			S[i] = S[j];
			S[j] = _temp;

			var _keystream_byte = S[(S[i] + S[j]) & 255];
			var _data_byte = buffer_read(_buffer_data, buffer_u8);
		
			buffer_write(_result_buffer, buffer_u8, _data_byte ^ _keystream_byte);
		}

		return _result_buffer;
	}

	/// @desc Prepares data buffer for export (encrypt and/or compress).
	/// @ignore
    static __Cyg_Prepare_Data_Buffer = function(_string, _encrypt, _compress)
    {
        var _temp_buffer = buffer_create(string_byte_length(_string) + 1, buffer_fixed, 1);
        buffer_write(_temp_buffer, buffer_string, _string);

        if (_encrypt)
		{
			var _effective_key = __Cyg_Get_Effective_Key();
			var _encrypted_buffer = __Cyg_ChaCha_Encrypt_Packed(_temp_buffer, _effective_key);
			if (is_undefined(_encrypted_buffer))
			{
				buffer_delete(_temp_buffer);
				return undefined;
			}
			buffer_delete(_temp_buffer);
			_temp_buffer = _encrypted_buffer;
        }

		if (_compress) 
		{
            var _size = buffer_get_size(_temp_buffer);
            var _compressed_buffer = buffer_compress(_temp_buffer, 0, _size);
			
            buffer_delete(_temp_buffer);
            _temp_buffer = _compressed_buffer;
        }

        return _temp_buffer;
    }

	/// @desc Extracts JSON string from the loaded buffer (decompress and/or decrypt).
	/// @ignore
    static __Cyg_Extract_Data_String = function(_data_buffer, _encrypt, _compress)
    {
		var _working_buffer = buffer_create(buffer_get_size(_data_buffer), buffer_fixed, 1);
		buffer_copy(_data_buffer, 0, buffer_get_size(_data_buffer), _working_buffer, 0);

		if (_compress)
		{
			var _decompressed_buffer = buffer_decompress(_working_buffer);
			if (buffer_get_size(_decompressed_buffer) > 0)
			{
				buffer_delete(_working_buffer);
				_working_buffer = _decompressed_buffer;
			} 
			else 
			{
				__cyg_alert("Decompression failed. Treating data as uncompressed.");
				buffer_delete(_decompressed_buffer);
		    }
		}
        
		if (_encrypt)
		{
			var _effective_key = __Cyg_Get_Effective_Key();
		    var _decrypted_buffer = __Cyg_ChaCha_Decrypt_Packed(_working_buffer, _effective_key);
			if (is_undefined(_decrypted_buffer))
			{
				buffer_delete(_working_buffer);
				return "";
			}
		    buffer_delete(_working_buffer);
		    var _working_buffer = _decrypted_buffer;
		}
        
		buffer_seek(_working_buffer, buffer_seek_start, 0);
		var _final_string = buffer_read(_working_buffer, buffer_string);
		buffer_delete(_working_buffer);
        
		return _final_string;
    }

	/// @ignore Ensures manager object exists in the game.
    static __Cyg_Init_Manager = function()
    {
        if (!instance_exists(o_cyg_manager) )
        {
			__cyg_alert("Creating o_cyg_manager instance.");
            instance_create_depth(0, 0, __CYG_MANAGER_DEPTH, o_cyg_manager);
        }
        else
        {
            instance_activate_object(o_cyg_manager);
        }
    }

	/// @ignore Builds the final buffer ready to be saved.
	static __Cyg_Build_Export_Buffer = function(_key, _encrypt, _compress)
	{
	    var _string;
	    if (_key != undefined)
		{
	        var _value_to_save = Get(_key);
			var _export_struct = { __cyg_version: __CYG_VERSION, __file_version: __version, __data: _value_to_save };
			
			_string = json_stringify(_export_struct);
	    } 
		else 
		{
	        __data.__file_version = __version;
	        _string = json_stringify(__data);
	    }
        
        if (_encrypt && !__Cyg_Has_Encryption_Key())
        {
			__cyg_alert("Encryption requested without a valid key. Use CYG_MASTER_KEY or SetEncryptKey().");
            _encrypt = false;
        }

	    var _data_buffer =	__Cyg_Prepare_Data_Buffer(_string, _encrypt, _compress);
		if (is_undefined(_data_buffer))
		{
			return undefined;
		}
	    var _hash =			cyg_sha256_buffer(_data_buffer, 0, buffer_get_size(_data_buffer));
	    var _final_buffer =	buffer_create(1, buffer_grow, 1);
        
	    buffer_write(_final_buffer, buffer_string, _hash);
	    buffer_copy(_data_buffer, 0, buffer_get_size(_data_buffer), _final_buffer, buffer_tell(_final_buffer));
	    buffer_delete(_data_buffer);
        
	    return _final_buffer;
	}
    
	/// @ignore Processes a loaded buffer and returns final data.
    static __Cyg_Process_Import_Buffer = function(_loaded_buffer, _path, _encrypt, _compress)
    {
		static DFix = function(_struct) { return _struct; }
		
        var _saved_hash = buffer_read(_loaded_buffer, buffer_string);
		var _data_offset = buffer_tell(_loaded_buffer);
		var _data_size = buffer_get_size(_loaded_buffer) - _data_offset;
        
        if (_data_size <= 0) 
		{
			__cyg_error($"File '{_path}' is empty or corrupted.");
			return { success: false, data: undefined };
        }
        
		var _calculated_hash = cyg_sha256_buffer(_loaded_buffer, _data_offset, _data_size);
		if (_saved_hash != _calculated_hash) 
		{
			__cyg_error($"Checksum failed! File '{_path}' is corrupted or has been modified.");
			return { success: false, data: undefined };
		}
        
		var _data_buffer = buffer_create(_data_size, buffer_fixed, 1);
		buffer_copy(_loaded_buffer, _data_offset, _data_size, _data_buffer, 0);
		
		if (_encrypt && !__Cyg_Has_Encryption_Key()) 
        {
			__cyg_alert("Decryption requested without a valid key. Use CYG_MASTER_KEY or SetEncryptKey().");
            buffer_delete(_data_buffer);
            return { success: false, data: undefined };
        }
        
		var _string = __Cyg_Extract_Data_String(_data_buffer, _encrypt, _compress);
        buffer_delete(_data_buffer);
		if (_string == "")
		{
			return { success: false, data: undefined };
		}

		var _parsed_data = json_parse(_string);
		
		if (!is_struct(_parsed_data) && !is_array(_parsed_data) ) 
		{
			__cyg_alert($"Imported file '{_path}' does not contain valid JSON.");
			return { success: false, data: undefined };
		}
		
        var _file_version =	_parsed_data[$ "__file_version"] ?? _parsed_data[$ "__FileVersion"] ?? -1;
        var _fixer_func = __fixers[$ string(_file_version)] ?? DFix;
        var _data_to_fix = struct_exists(_parsed_data, "__data") ? _parsed_data.__data : _parsed_data;
        var _final_data = _fixer_func(_data_to_fix);
        
		return { success: true, data: _final_data };
    }
	
	#endregion

	#region API

	/// @desc Sets the version of data that will be saved.
	/// @param {Real} version Version number to set.
	/// @return {self} Enables method chaining.
	static SetVersion = function(_version)
	{
		__version = _version;
		return self;
	}

	/// @desc Sets the encryption key used by Export and Import.
	/// @param {String} key Encryption key.
	/// @return {self} Enables method chaining.
	static SetEncryptKey = function(_key)
	{
		if (is_undefined(_key))
		{
			__custom_key = undefined;
			return self;
		}

		if (is_array(_key) )
		{
			var _key_result = "";
			var i=0; repeat(array_length(_key) ) { _key_result += chr(_key[i++] ^ __CYG_XOR_MASK); }
			
			__custom_key = _key_result;
		}
		else 
		{
			__custom_key = _key;
		}
		
		return self;
	}

	/// @desc Registers a fixer function for a specific save-file version.
	/// @param {Real|String} version_key File version that triggers this fixer.
	/// @param {Method} callback Fixer function. Must accept a struct and return a struct.
	/// @return {self} Enables method chaining.
	static AddFixer = function(_version_key, _callback)
	{
		if (!is_callable(_callback) )
		{
			__cyg_error($"The fixer provided for version {_version_key} is not a function, it is {typeof(_callback)}.");
			return self;
		}
		
		__fixers[$ string(_version_key)] = _callback;
		return self;
	}

	/// @desc Saves data to a file ASYNCHRONOUSLY.
	/// @param {String}	path		Full file path.
	/// @param {String}	[key]		Key of data to save.
	/// @param {Bool}	[encrypt]	Enables encryption.
	/// @param {Method}	callback	Callback when finished. `function(success:Bool)`
	static Export = function(_path, _key=undefined, _encrypt=false, _callback=undefined)
	{
		__cyg_alert($"Export iniciado, path={_path}, key={_key}, encrypt={_encrypt}");
		__Cyg_Init_Manager();

		if (!__Cyg_Validate_IO_Path(_path, "Export"))
		{
			if (is_callable(_callback)) _callback(false);
			return;
		}
		
		if (__CYG_USE_BACKUPS && file_exists(_path) ) 
		{
			var _timestamp = __Cyg_Get_Timestamp();
			var _backup_path = $"{_path}_{_timestamp}.bak";
			file_rename(_path, _backup_path);
			__cyg_alert($"Backup created: {_backup_path}");
		}

		var _final_buffer =	__Cyg_Build_Export_Buffer(_key, _encrypt, __CYG_USE_COMPRESS);
		if (is_undefined(_final_buffer))
		{
			if (is_callable(_callback)) _callback(false);
			return;
		}
		var _size =	buffer_get_size(_final_buffer);
		var _async_id =	buffer_save_async(_final_buffer, _path, 0, _size);
		if (_async_id < 0)
		{
			__cyg_error($"Could not start async save for '{_path}'. This can happen on sandboxed targets when the path is not writable.");
			if (buffer_exists(_final_buffer)) buffer_delete(_final_buffer);
			if (is_callable(_callback)) _callback(false);
			return;
		}
		
		__cyg_alert($"Export async_id={_async_id}, buffer_size={_size}");
		
		async_requests[? _async_id] = {
			type:		"export",
			callback:	_callback,
			buffer:		_final_buffer
		};
	}

	/// @desc Loads data from a file ASYNCHRONOUSLY.
	/// @param {String} path Full file path.
	/// @param {String} [key] Key where imported data will be stored.
	/// @param {Bool}   [encrypt] Enables decryption.
	/// @param {Method} callback Callback on completion. Receives (success:Bool, data:Any).
    static Import = function(_path, _key=undefined, _encrypt=false, _callback=undefined)
    {
        __cyg_alert($"Import iniciado, path={_path} file_exists={file_exists(_path)}, key={_key}");
		__Cyg_Init_Manager();

		if (!__Cyg_Validate_IO_Path(_path, "Import"))
		{
			if (is_callable(_callback)) _callback(false, undefined);
			return;
		}
        
		if (!file_exists(_path) ) 
		{
			if (is_callable(_callback) ) _callback(false, undefined);
            exit;
        }
		
		// Create a target buffer where async load writes data.
        var _target_buffer = buffer_create(1, buffer_grow, 1);
        var _async_id = buffer_load_async(_target_buffer, _path, 0, -1);
        if (_async_id < 0)
        {
			__cyg_error($"Could not start async load for '{_path}'.");
            buffer_delete(_target_buffer);

			if (is_callable(_callback) ) _callback(false, undefined);
            
			exit;
        }
        __cyg_alert($"Import async_id={_async_id} created buffer");
        
        async_requests[? _async_id] = {
            type:		"import",
            callback:	_callback,
            key:		_key,
            encrypt:	_encrypt,
            path:		_path,
			// Keep a reference to target buffer.
            buffer:     _target_buffer
        };
    }

	/// @desc Processes async events. Must be called from Async - Save/Load event.
	/// @param {DS_Map} async_load ds_map provided by GameMaker.
	static ProcessAsyncEvent = function(_async_load)
	{
		var _id = _async_load[? "id"];
		if (!ds_map_exists(async_requests, _id) ) return;
		
		var _request = async_requests[? _id];
		var _status = _async_load[? "status"];
		var _callback = _request.callback;
		
		if (_request.type == "export") 
		{
			__cyg_alert($"ProcessAsyncEvent export, status={string(_status)}");
			if (!_status)
			{
				__cyg_error("Export async status=false. On sandboxed targets, write operations are limited to the save area unless sandbox is disabled on desktop.");
			}

			try
			{
				buffer_delete(_request.buffer);
				if (is_callable(_callback)) _callback(_status);
			}
			catch (_error)
			{
				__cyg_error($"Exception in ProcessAsyncEvent (export): {_error}");
				if (is_callable(_callback))
				{
					try
					{
						_callback(false);
					}
					catch (_callback_error)
					{
						__cyg_error($"Exception in export callback fallback: {_callback_error}");
					}
				}
			}
		}
		else if (_request.type == "import")
		{
			__cyg_alert($"ProcessAsyncEvent import, status={string(_status)}");
			if (!_status)
			{
				__cyg_error("Import async status=false. Verify file location and sandbox rules for the active target platform.");
			}
			var _loaded_buffer = _request.buffer;
			var _final_data = undefined;

			try
			{
				if (!_status)
				{
					if (is_callable(_callback) ) _callback(false, _final_data);
				}
				else
				{
					__cyg_alert($"Import buffer processing, size={string(buffer_get_size(_loaded_buffer))}");
					
					var _result = __Cyg_Process_Import_Buffer(_loaded_buffer, _request.path, _request.encrypt, __CYG_USE_COMPRESS);
					__cyg_alert($"Import result.success={string(_result.success)}");

					if (_result.success)
					{
						_final_data = _result.data;
						if (_request.key == undefined)
						{
								__data = _final_data;
						}
						else
						{
								Add(_request.key, _final_data);
						}
					}

					if (is_callable(_callback)) _callback(_result.success, _final_data);
				}
			}
			catch (_error)
			{
				__cyg_error($"Exception in ProcessAsyncEvent (import): {_error}");
				if (is_callable(_callback))
				{
					try
					{
						_callback(false, undefined);
					}
					catch (_callback_error)
					{
						__cyg_error($"Exception in import callback fallback: {_callback_error}");
					}
				}
			}

			try
			{
				if (buffer_exists(_loaded_buffer)) buffer_delete(_loaded_buffer);
			}
			catch (_cleanup_error)
			{
				__cyg_error($"Exception cleaning import buffer: {_cleanup_error}");
			}
		}
		
		try
		{
			ds_map_delete(async_requests, _id);
		}
		catch (_cleanup_error)
		{
			__cyg_error($"Exception removing async request {_id}: {_cleanup_error}");
		}
	}

	/// @desc Restores a save file from its backup (.bak).
	/// @param {string} path Original save-file path (example: "save/slot1.sav").
	/// @return {Bool} Returns true if backup restoration succeeds.
	static RestoreBackup = function(_path)
	{
		if (!__Cyg_Validate_IO_Path(_path, "RestoreBackup"))
		{
			return false;
		}

		var _backup_path = __Cyg_Find_Latest_Backup_Path(_path);
		if (__CYG_USE_BACKUPS && !is_undefined(_backup_path) && file_exists(_backup_path) ) 
		{
			if (file_exists(_path) ) file_delete(_path);
			file_rename(_backup_path, _path);
			
			return true;
		}
		
		__cyg_alert($"No backup file found for '{_path}'.");
		
		return false;
	}

	/// @desc Adds or overwrites a value in the data store.
	/// @param {String} key Key used to store the value.
	/// @param {Struct} value Struct value to serialize.
	/// @return {self} Enables method chaining.
	static Add = function(_key, _value)
	{
		__data[$ _key] = _value;
		
		return self;
	}

	/// @desc Gets a value from the data store.
	/// @param  {String} key Key to retrieve.
	/// @param  {Any*}   [default_value] Value returned if key does not exist.
	/// @return {Any} Stored value or default value.
	static Get = function(_key, _default=undefined)
	{
		return __data[$ _key] ?? _default;
	}

	/// @desc Checks whether a key exists in the data store.
	/// @param {String} key Key to check.
	/// @return {Bool} Returns true if key exists.
	static Exists = function(_key)
	{
		return struct_exists(__data, _key);
	}

	/// @desc Removes a key and its associated value from the data store.
	/// @param {String} key Key to remove.
	/// @return {Any} Removed value, or undefined if key did not exist.
	static Remove = function(_key)
	{
		if (struct_exists(__data, _key) )
		{
			var _removed_value = __data[$ _key];
			struct_remove(__data, _key);
			return _removed_value;
		}
		
		return undefined;
	}

	/// @desc Deletes a file from disk.
	/// @param {string} path Full path of file to delete.
	/// @return {Bool} Returns true if file was deleted.
	static DeleteFile = function(_path)
	{
		if (!__Cyg_Validate_IO_Path(_path, "DeleteFile"))
		{
			return false;
		}

		if (__CYG_USE_BACKUPS)
		{
			var _backup_path = _path + ".bak";
			if (file_exists(_backup_path) ) file_delete(_backup_path);

			var _mask = _path + "_*.bak";
			var _item = file_find_first(_mask, 0);
			if (_item != "")
			{
				if (file_exists(_item)) file_delete(_item);

				_item = file_find_next();
				while (_item != "")
				{
					if (file_exists(_item)) file_delete(_item);
					_item = file_find_next();
				}

				file_find_close();
			}
		}
		
		if (file_exists(_path) ) 
		{
			file_delete(_path); 
			
			return true;
		}

		return false;
	}

	/// @desc Resets Cyg state completely.
	static Cleanup = function()
	{
		static_get(Cyg).__data = 
		{
			__cyg_version: __CYG_VERSION,
			__file_version: -1,
		};
	}

	#endregion
}

/// @ignore
function __cyg_alert(_msg)
{
	if (__CYG_DEBUG_WARNINGS)
	{
		show_debug_message($"Cyg Warning:: {_msg}");
	}
}

/// @ignore
function __cyg_error(_msg)
{
	if (__CYG_DEBUG_ERRORS) { show_debug_message($"Cyg Error:: {_msg}"); }
	if (__CYG_STRICT_MODE)
	{
		show_error($"Cyg Fatal Error:: {_msg}", true);
	}
}

/// @ignore 32-bit right rotation.
function __cyg_sha256_rotr(_value, _bits)
{
	_value &= 0xFFFFFFFF;
	return ((_value >> _bits) | (_value << (32 - _bits))) & 0xFFFFFFFF;
}

/// @ignore Reads one byte from a logical SHA-256 message with standard padding.
function __cyg_sha256_message_byte(_buffer, _offset, _size, _zero_pad, _index, _bit_hi, _bit_lo)
{
	if (_index < _size)
	{
		return buffer_peek(_buffer, _offset + _index, buffer_u8) & 0xFF;
	}

	if (_index == _size)
	{
		return 0x80;
	}

	var _len_index = _size + 1 + _zero_pad;
	if (_index < _len_index)
	{
		return 0;
	}

	var _tail = _index - _len_index;
	switch (_tail)
	{
		case 0: return (_bit_hi >> 24) & 0xFF;
		case 1: return (_bit_hi >> 16) & 0xFF;
		case 2: return (_bit_hi >> 8) & 0xFF;
		case 3: return _bit_hi & 0xFF;
		case 4: return (_bit_lo >> 24) & 0xFF;
		case 5: return (_bit_lo >> 16) & 0xFF;
		case 6: return (_bit_lo >> 8) & 0xFF;
		case 7: return _bit_lo & 0xFF;
	}

	return 0;
}

/// @desc Computes SHA-256 over a buffer range and returns lowercase hex.
/// @param {Buffer} _buffer Source buffer.
/// @param {Real} [_offset=0] Offset in bytes.
/// @param {Real} [_size=-1] Number of bytes to hash. If -1, hashes until buffer end.
/// @return {String} 64-char lowercase SHA-256 hex digest, or empty string on error.
function cyg_sha256_buffer(_buffer, _offset = 0, _size = -1)
{
	if (!buffer_exists(_buffer))
	{
		__cyg_error("cyg_sha256_buffer: invalid buffer.");
		return "";
	}

	var _buf_size = buffer_get_size(_buffer);
	var _start = max(0, floor(_offset));
	if (_start > _buf_size) _start = _buf_size;

	var _count = _size;
	if (!is_real(_count) || _count < 0)
	{
		_count = _buf_size - _start;
	}
	_count = floor(_count);
	if (_start + _count > _buf_size)
	{
		_count = _buf_size - _start;
	}

	var _bit_len_lo = ((_count & 0xFFFFFFFF) * 8) & 0xFFFFFFFF;
	var _bit_len_hi = floor((_count * 8) / 4294967296) & 0xFFFFFFFF;
	var _zero_pad = (56 - ((_count + 1) mod 64) + 64) mod 64;
	var _total = _count + 1 + _zero_pad + 8;

	var _h0 = 0x6A09E667;
	var _h1 = 0xBB67AE85;
	var _h2 = 0x3C6EF372;
	var _h3 = 0xA54FF53A;
	var _h4 = 0x510E527F;
	var _h5 = 0x9B05688C;
	var _h6 = 0x1F83D9AB;
	var _h7 = 0x5BE0CD19;

	var _k = [
		0x428A2F98, 0x71374491, 0xB5C0FBCF, 0xE9B5DBA5, 0x3956C25B, 0x59F111F1, 0x923F82A4, 0xAB1C5ED5,
		0xD807AA98, 0x12835B01, 0x243185BE, 0x550C7DC3, 0x72BE5D74, 0x80DEB1FE, 0x9BDC06A7, 0xC19BF174,
		0xE49B69C1, 0xEFBE4786, 0x0FC19DC6, 0x240CA1CC, 0x2DE92C6F, 0x4A7484AA, 0x5CB0A9DC, 0x76F988DA,
		0x983E5152, 0xA831C66D, 0xB00327C8, 0xBF597FC7, 0xC6E00BF3, 0xD5A79147, 0x06CA6351, 0x14292967,
		0x27B70A85, 0x2E1B2138, 0x4D2C6DFC, 0x53380D13, 0x650A7354, 0x766A0ABB, 0x81C2C92E, 0x92722C85,
		0xA2BFE8A1, 0xA81A664B, 0xC24B8B70, 0xC76C51A3, 0xD192E819, 0xD6990624, 0xF40E3585, 0x106AA070,
		0x19A4C116, 0x1E376C08, 0x2748774C, 0x34B0BCB5, 0x391C0CB3, 0x4ED8AA4A, 0x5B9CCA4F, 0x682E6FF3,
		0x748F82EE, 0x78A5636F, 0x84C87814, 0x8CC70208, 0x90BEFFFA, 0xA4506CEB, 0xBEF9A3F7, 0xC67178F2
	];

	var _w = array_create(64, 0);
	for (var _chunk = 0; _chunk < _total; _chunk += 64)
	{
		for (var _i = 0; _i < 16; ++_i)
		{
			var _base = _chunk + (_i * 4);
			var _b0 = __cyg_sha256_message_byte(_buffer, _start, _count, _zero_pad, _base + 0, _bit_len_hi, _bit_len_lo);
			var _b1 = __cyg_sha256_message_byte(_buffer, _start, _count, _zero_pad, _base + 1, _bit_len_hi, _bit_len_lo);
			var _b2 = __cyg_sha256_message_byte(_buffer, _start, _count, _zero_pad, _base + 2, _bit_len_hi, _bit_len_lo);
			var _b3 = __cyg_sha256_message_byte(_buffer, _start, _count, _zero_pad, _base + 3, _bit_len_hi, _bit_len_lo);
			_w[_i] = ((_b0 << 24) | (_b1 << 16) | (_b2 << 8) | _b3) & 0xFFFFFFFF;
		}

		for (var _j = 16; _j < 64; ++_j)
		{
			var _x = _w[_j - 15];
			var _y = _w[_j - 2];
			var _s0 = (__cyg_sha256_rotr(_x, 7) ^ __cyg_sha256_rotr(_x, 18) ^ ((_x >> 3) & 0x1FFFFFFF)) & 0xFFFFFFFF;
			var _s1 = (__cyg_sha256_rotr(_y, 17) ^ __cyg_sha256_rotr(_y, 19) ^ ((_y >> 10) & 0x003FFFFF)) & 0xFFFFFFFF;
			_w[_j] = (_w[_j - 16] + _s0 + _w[_j - 7] + _s1) & 0xFFFFFFFF;
		}

		var _a = _h0;
		var _b = _h1;
		var _c = _h2;
		var _d = _h3;
		var _e = _h4;
		var _f = _h5;
		var _g = _h6;
		var _h = _h7;

		for (var _t = 0; _t < 64; ++_t)
		{
			var _S1 = (__cyg_sha256_rotr(_e, 6) ^ __cyg_sha256_rotr(_e, 11) ^ __cyg_sha256_rotr(_e, 25)) & 0xFFFFFFFF;
			var _ch = ((_e & _f) ^ ((~_e) & _g)) & 0xFFFFFFFF;
			var _temp1 = (_h + _S1 + _ch + _k[_t] + _w[_t]) & 0xFFFFFFFF;
			var _S0 = (__cyg_sha256_rotr(_a, 2) ^ __cyg_sha256_rotr(_a, 13) ^ __cyg_sha256_rotr(_a, 22)) & 0xFFFFFFFF;
			var _maj = ((_a & _b) ^ (_a & _c) ^ (_b & _c)) & 0xFFFFFFFF;
			var _temp2 = (_S0 + _maj) & 0xFFFFFFFF;

			_h = _g;
			_g = _f;
			_f = _e;
			_e = (_d + _temp1) & 0xFFFFFFFF;
			_d = _c;
			_c = _b;
			_b = _a;
			_a = (_temp1 + _temp2) & 0xFFFFFFFF;
		}

		_h0 = (_h0 + _a) & 0xFFFFFFFF;
		_h1 = (_h1 + _b) & 0xFFFFFFFF;
		_h2 = (_h2 + _c) & 0xFFFFFFFF;
		_h3 = (_h3 + _d) & 0xFFFFFFFF;
		_h4 = (_h4 + _e) & 0xFFFFFFFF;
		_h5 = (_h5 + _f) & 0xFFFFFFFF;
		_h6 = (_h6 + _g) & 0xFFFFFFFF;
		_h7 = (_h7 + _h) & 0xFFFFFFFF;
	}

	var _hex = "0123456789abcdef";
	var _out = "";
	var _words = [_h0, _h1, _h2, _h3, _h4, _h5, _h6, _h7];
	for (var _w_i = 0; _w_i < 8; ++_w_i)
	{
		var _word = _words[_w_i] & 0xFFFFFFFF;
		for (var _shift = 28; _shift >= 0; _shift -= 4)
		{
			var _n = (_word >> _shift) & 15;
			_out += string_char_at(_hex, _n + 1);
		}
	}

	return _out;
}

/// @ignore 32-bit left rotation.
function __chacha20_rotl(_value, _bits)
{
	_value &= 0xFFFFFFFF;
	return ((_value << _bits) | (_value >> (32 - _bits))) & 0xFFFFFFFF;
}

/// @ignore Converts 4 little-endian bytes into a 32-bit integer.
function __chacha20_from_bytes(_bytes, _index)
{
	return (_bytes[_index]
		| (_bytes[_index + 1] << 8)
		| (_bytes[_index + 2] << 16)
		| (_bytes[_index + 3] << 24)) & 0xFFFFFFFF;
}

/// @ignore Serializes a 32-bit integer into 4 little-endian bytes.
function __chacha20_to_bytes(_value, _bytes, _index)
{
	_value &= 0xFFFFFFFF;
	_bytes[_index + 0] = _value & 0xFF;
	_bytes[_index + 1] = (_value >> 8) & 0xFF;
	_bytes[_index + 2] = (_value >> 16) & 0xFF;
	_bytes[_index + 3] = (_value >> 24) & 0xFF;
}

/// @ignore ChaCha20 quarter-round.
function __chacha20_quarter_round(_state, _a, _b, _c, _d)
{
	_state[_a] = (_state[_a] + _state[_b]) & 0xFFFFFFFF;
	_state[_d] = __chacha20_rotl(_state[_d] ^ _state[_a], 16);
	_state[_c] = (_state[_c] + _state[_d]) & 0xFFFFFFFF;
	_state[_b] = __chacha20_rotl(_state[_b] ^ _state[_c], 12);
	_state[_a] = (_state[_a] + _state[_b]) & 0xFFFFFFFF;
	_state[_d] = __chacha20_rotl(_state[_d] ^ _state[_a], 8);
	_state[_c] = (_state[_c] + _state[_d]) & 0xFFFFFFFF;
	_state[_b] = __chacha20_rotl(_state[_b] ^ _state[_c], 7);
}

/// @ignore Generates a 64-byte ChaCha20 keystream block.
function __chacha20_block(_key_bytes, _nonce_bytes, _counter)
{
	var _state = array_create(16, 0);
	_state[0]  = 0x61707865;
	_state[1]  = 0x3320646e;
	_state[2]  = 0x79622d32;
	_state[3]  = 0x6b206574;
	var i = 0;
	repeat(8)
    {
		_state[4 + i] = __chacha20_from_bytes(_key_bytes, i * 4);
		i++;
    }

	_state[12] = _counter & 0xFFFFFFFF;
	_state[13] = __chacha20_from_bytes(_nonce_bytes, 0);
	_state[14] = __chacha20_from_bytes(_nonce_bytes, 4);
	_state[15] = __chacha20_from_bytes(_nonce_bytes, 8);

	var _working = array_create(16, 0);
	i = 0;
	repeat(16)
    {
		_working[i] = _state[i];
        i++;
    }

	repeat(10)
	{
		__chacha20_quarter_round(_working, 0, 4, 8, 12);
		__chacha20_quarter_round(_working, 1, 5, 9, 13);
		__chacha20_quarter_round(_working, 2, 6, 10, 14);
		__chacha20_quarter_round(_working, 3, 7, 11, 15);
		__chacha20_quarter_round(_working, 0, 5, 10, 15);
		__chacha20_quarter_round(_working, 1, 6, 11, 12);
		__chacha20_quarter_round(_working, 2, 7, 8, 13);
		__chacha20_quarter_round(_working, 3, 4, 9, 14);
	}

	var _output = array_create(64, 0);
	i = 0;
	repeat(16)
	{
		var _value = (_working[i] + _state[i]) & 0xFFFFFFFF;
		__chacha20_to_bytes(_value, _output, i * 4);
		i++;
	}

	return _output;
}

/// @ignore Converts string to bytes and validates expected length.
function __chacha20_bytes_from_string(_string, _expected_length, _name)
{
	var _length = string_byte_length(_string);
	if (_length != _expected_length)
	{
		__cyg_error($"ChaCha20: {_name} must be {_expected_length} bytes, got {_length}.");
		return undefined;
	}

	var _bytes = array_create(_expected_length, 0);
	var i = 0;
	repeat(_expected_length)
	{
		_bytes[i] = string_byte_at(_string, i + 1);
		i++;
	}

	return _bytes;
}

/// @ignore Converts bytes to buffer.
function __chacha20_bytes_to_buffer(_bytes)
{
	var _size = array_length(_bytes);
	var _buffer = buffer_create(_size, buffer_fixed, 1);
	var i = 0;
	repeat(_size)
	{
		buffer_write(_buffer, buffer_u8, _bytes[i] & 0xFF);
		i++;
	}
	buffer_seek(_buffer, buffer_seek_start, 0);
	return _buffer;
}

/// @ignore Reads an entire buffer as byte array without changing final position.
function __chacha20_buffer_to_bytes(_buffer)
{
	var _size = buffer_get_size(_buffer);
	var _bytes = array_create(_size, 0);
	var _pos = buffer_tell(_buffer);

	buffer_seek(_buffer, buffer_seek_start, 0);
	var i = 0;
	repeat(_size)
	{
		_bytes[i] = buffer_read(_buffer, buffer_u8);
		i++;
	}

	buffer_seek(_buffer, buffer_seek_start, _pos);
	return _bytes;
}

/// @ignore Encrypts/decrypts bytes using ChaCha20.
function __chacha20_xor_bytes(_input_bytes, _key_bytes, _nonce_bytes, _counter)
{
	var _size = array_length(_input_bytes);
	var _output = array_create(_size, 0);
	var _pos = 0;

	while (_pos < _size)
	{
		var _stream = __chacha20_block(_key_bytes, _nonce_bytes, _counter);
		_counter = (_counter + 1) & 0xFFFFFFFF;
		var _left = min(64, _size - _pos);

		var j = 0;
		repeat(_left)
		{
			_output[_pos + j] = (_input_bytes[_pos + j] ^ _stream[j]) & 0xFF;
			j++;
		}

		_pos += _left;
	}

	return _output;
}

/// @ignore Converts a byte sequence to base-2^13 limbs for Poly1305.
function __poly1305_bytes_to_limbs130(_bytes, _offset, _count, _append_one)
{
	var _limbs = array_create(10, 0);
	var i = 0;
	repeat(_count)
	{
		var _b = _bytes[_offset + i] & 0xFF;
		var _bit = 0;
		repeat(8)
		{
			if ((_b & (1 << _bit)) != 0)
			{
				var _bit_index = i * 8 + _bit;
				var _limb = floor(_bit_index / 13);
				var _shift = _bit_index mod 13;
				if (_limb < 10) _limbs[_limb] |= (1 << _shift);
			}
			_bit++;
		}
		i++;
	}

	if (_append_one)
	{
		var _bit_index2 = _count * 8;
		var _limb2 = floor(_bit_index2 / 13);
		var _shift2 = _bit_index2 mod 13;
		if (_limb2 < 10) _limbs[_limb2] |= (1 << _shift2);
	}

	return _limbs;
}

/// @ignore Converts base-2^13 limbs to little-endian bytes.
function __poly1305_limbs_to_bytes(_limbs, _byte_count)
{
	var _bytes = array_create(_byte_count, 0);
	var i = 0;
	repeat(_byte_count)
	{
		var _v = 0;
		var _bit = 0;
		repeat(8)
		{
			var _bit_index = i * 8 + _bit;
			var _limb = floor(_bit_index / 13);
			var _shift = _bit_index mod 13;
			if (_limb < 10)
			{
				if (((_limbs[_limb] >> _shift) & 1) != 0)
				{
					_v |= (1 << _bit);
				}
			}
			_bit++;
		}

		_bytes[i] = _v & 0xFF;
		i++;
	}

	return _bytes;
}

/// @ignore Modular reduction for Poly1305 in base 2^13.
function __poly1305_reduce(_value)
{
	var _base = 8192;

	var _pass = 0;
	repeat(2)
	{
		var i = 0;
		repeat(9)
		{
			var _carry = floor(_value[i] / _base);
			_value[i] -= _carry * _base;
			_value[i + 1] += _carry;
			i++;
		}

		var _carry9 = floor(_value[9] / _base);
		_value[9] -= _carry9 * _base;
		_value[0] += _carry9 * 5;
		_pass++;
	}

	var j = 0;
	repeat(9)
	{
		var _carry2 = floor(_value[j] / _base);
		_value[j] -= _carry2 * _base;
		_value[j + 1] += _carry2;
		j++;
	}

	var _carry3 = floor(_value[9] / _base);
	_value[9] -= _carry3 * _base;
	_value[0] += _carry3 * 5;

	j = 0;
	repeat(9)
	{
		var _carry4 = floor(_value[j] / _base);
		_value[j] -= _carry4 * _base;
		_value[j + 1] += _carry4;
		j++;
	}

	var _ge = true;
	var k = 9;
	repeat(10)
	{
		var _pi = (k == 0) ? (_base - 5) : (_base - 1);
		if (_value[k] > _pi) break;
		if (_value[k] < _pi)
		{
			_ge = false;
			break;
		}
		k--;
	}

	if (_ge)
	{
		var _borrow = 0;
		var n = 0;
		repeat(10)
		{
			var _pn = (n == 0) ? (_base - 5) : (_base - 1);
			var _v = _value[n] - _pn - _borrow;
			if (_v < 0)
			{
				_v += _base;
				_borrow = 1;
			}
			else
			{
				_borrow = 0;
			}

			_value[n] = _v;
			n++;
		}
	}

	return _value;
}

/// @ignore Modular multiplication for Poly1305.
function __poly1305_mul_mod(_a, _b)
{
	var _t = array_create(20, 0);
	var i = 0;
	repeat(10)
	{
		var j = 0;
		repeat(10)
		{
			_t[i + j] += _a[i] * _b[j];
			j++;
		}
		i++;
	}

	var k = 19;
	repeat(10)
	{
		_t[k - 10] += _t[k] * 5;
		_t[k] = 0;
		k--;
	}

	var _out = array_create(10, 0);
	i = 0;
	repeat(10)
	{
		_out[i] = _t[i];
		i++;
	}

	return __poly1305_reduce(_out);
}

/// @ignore Creates Poly1305 context.
function __poly1305_init(_poly_key_32)
{
	var _r_bytes = array_create(16, 0);
	var _s_bytes = array_create(16, 0);
	var i = 0;
	repeat(16)
	{
		_r_bytes[i] = _poly_key_32[i] & 0xFF;
		_s_bytes[i] = _poly_key_32[16 + i] & 0xFF;
		i++;
	}

	_r_bytes[3]  &= 15;
	_r_bytes[7]  &= 15;
	_r_bytes[11] &= 15;
	_r_bytes[15] &= 15;
	_r_bytes[4]  &= 252;
	_r_bytes[8]  &= 252;
	_r_bytes[12] &= 252;

	return {
		r: __poly1305_bytes_to_limbs130(_r_bytes, 0, 16, false),
		s: _s_bytes,
		acc: array_create(10, 0)
	};
}

/// @ignore Feeds bytes into Poly1305.
function __poly1305_update(_ctx, _bytes)
{
	var _len = array_length(_bytes);
	var _pos = 0;
	while (_pos < _len)
	{
		var _block_len = min(16, _len - _pos);
		var _block = __poly1305_bytes_to_limbs130(_bytes, _pos, _block_len, true);

		var i = 0;
		repeat(10)
		{
			_ctx.acc[i] += _block[i];
			i++;
		}

		_ctx.acc = __poly1305_mul_mod(_ctx.acc, _ctx.r);
		_pos += _block_len;
	}
}

/// @ignore Returns final Poly1305 tag (16 bytes).
function __poly1305_finish(_ctx)
{
	_ctx.acc = __poly1305_reduce(_ctx.acc);
	var _acc128 = __poly1305_limbs_to_bytes(_ctx.acc, 16);

	var _tag = array_create(16, 0);
	var _carry = 0;
	var i = 0;
	repeat(16)
	{
		var _v = _acc128[i] + _ctx.s[i] + _carry;
		_tag[i] = _v & 0xFF;
		_carry = floor(_v / 256);
		i++;
	}

	return _tag;
}

/// @ignore Serializes a 64-bit little-endian integer into 8 bytes using hi/lo 32-bit parts.
function __chacha20_encode_u64le(_len)
{
	var _lo = _len & 0xFFFFFFFF;
	var _hi = floor(_len / 4294967296);
	if (_hi < 0) _hi = 0;
	if (_hi > 0xFFFFFFFF) _hi = 0xFFFFFFFF;

	return [
		_lo & 0xFF,
		(_lo >> 8) & 0xFF,
		(_lo >> 16) & 0xFF,
		(_lo >> 24) & 0xFF,
		_hi & 0xFF,
		(_hi >> 8) & 0xFF,
		(_hi >> 16) & 0xFF,
		(_hi >> 24) & 0xFF
	];
}

/// @ignore Converts bytes to raw string.
function __chacha20_bytes_to_string(_bytes)
{
	var _s = "";
	var i = 0;
	var _n = array_length(_bytes);
	repeat(_n)
	{
		_s += chr(_bytes[i] & 0xFF);
		i++;
	}
	return _s;
}

/// @ignore Converts bytes to hexadecimal string.
function __chacha20_bytes_to_hex(_bytes)
{
	var _hex = "0123456789abcdef";
	var _s = "";
	var i = 0;
	var _n = array_length(_bytes);
	repeat(_n)
	{
		var _v = _bytes[i] & 0xFF;
		_s += string_char_at(_hex, ((_v >> 4) & 15) + 1);
		_s += string_char_at(_hex, (_v & 15) + 1);
		i++;
	}
	return _s;
}

/// @ignore Converts tag string/array/buffer to 16-byte array.
function __chacha20_tag_to_bytes(_tag)
{
	if (is_array(_tag))
	{
		if (array_length(_tag) != 16) return undefined;
		var _out_a = array_create(16, 0);
		var _i = 0;
		repeat(16)
		{
			_out_a[_i] = _tag[_i] & 0xFF;
			_i++;
		}
		return _out_a;
	}

	if (is_string(_tag))
	{
		if (string_byte_length(_tag) != 16) return undefined;
		return __chacha20_bytes_from_string(_tag, 16, "tag");
	}

	if (!is_undefined(_tag) && buffer_exists(_tag))
	{
		if (buffer_get_size(_tag) != 16) return undefined;
		return __chacha20_buffer_to_bytes(_tag);
	}

	return undefined;
}

/// @ignore Constant-time comparison of 16-byte tags.
function __chacha20_tag_equals(_a, _b)
{
	if (_a == undefined || _b == undefined) return false;
	var _diff = 0;
	var i = 0;
	repeat(16)
	{
		_diff |= (_a[i] ^ _b[i]);
		i++;
	}
	return _diff == 0;
}

/// @ignore Builds Poly1305 tag for AEAD ChaCha20-Poly1305.
function __chacha20_poly1305_tag(_key_bytes, _nonce_bytes, _aad_bytes, _cipher_bytes)
{
	var _block0 = __chacha20_block(_key_bytes, _nonce_bytes, 0);
	var _poly_key = array_create(32, 0);
	var i = 0;
	repeat(32)
	{
		_poly_key[i] = _block0[i] & 0xFF;
		i++;
	}

	var _ctx = __poly1305_init(_poly_key);

	var _aad_len = array_length(_aad_bytes);
	if (_aad_len > 0) __poly1305_update(_ctx, _aad_bytes);
	if ((_aad_len mod 16) != 0)
	{
		var _aad_pad = array_create(16 - (_aad_len mod 16), 0);
		__poly1305_update(_ctx, _aad_pad);
	}

	var _cipher_len = array_length(_cipher_bytes);
	if (_cipher_len > 0) __poly1305_update(_ctx, _cipher_bytes);
	if ((_cipher_len mod 16) != 0)
	{
		var _cipher_pad = array_create(16 - (_cipher_len mod 16), 0);
		__poly1305_update(_ctx, _cipher_pad);
	}

	var _aad_len_64 = __chacha20_encode_u64le(_aad_len);
	var _cipher_len_64 = __chacha20_encode_u64le(_cipher_len);
	__poly1305_update(_ctx, _aad_len_64);
	__poly1305_update(_ctx, _cipher_len_64);

	return __poly1305_finish(_ctx);
}

/// @desc Encrypts a buffer using ChaCha20.
function chacha_encrypt(_input_buffer, _key_string, _nonce_string, _counter = 1)
{
	if (is_undefined(_input_buffer) || !buffer_exists(_input_buffer))
	{
		__cyg_error("ChaCha20: _input_buffer is not a valid buffer.");
		return undefined;
	}

	if (!is_string(_key_string) || !is_string(_nonce_string))
	{
		__cyg_error("ChaCha20: key and nonce must be byte-strings.");
		return undefined;
	}

	if (!is_real(_counter))
	{
		__cyg_error("ChaCha20: _counter must be numeric.");
		return undefined;
	}

	try
	{
		var _key_bytes = __chacha20_bytes_from_string(_key_string, 32, "key");
		var _nonce_bytes = __chacha20_bytes_from_string(_nonce_string, 12, "nonce");
		if (_key_bytes == undefined || _nonce_bytes == undefined) return undefined;

		var _in_bytes = __chacha20_buffer_to_bytes(_input_buffer);
		var _out_bytes = __chacha20_xor_bytes(_in_bytes, _key_bytes, _nonce_bytes, floor(_counter) & 0xFFFFFFFF);
		return __chacha20_bytes_to_buffer(_out_bytes);
	}
	catch (_error)
	{
		__cyg_error($"ChaCha20: exception during encryption: {_error}");
		return undefined;
	}
}

/// @desc Decrypts a buffer using ChaCha20.
function chacha_decrypt(_input_buffer, _key_string, _nonce_string, _counter = 1)
{
	return chacha_encrypt(_input_buffer, _key_string, _nonce_string, _counter);
}

/// @desc Encrypts using AEAD ChaCha20-Poly1305.
/// @return {Struct} { success, ciphertext_buffer, tag_buffer, tag_bytes, tag_string, tag_hex }
function chacha20_poly1305_encrypt(_plain_buffer, _key_string, _nonce_string, _aad_buffer = undefined, _counter = 1)
{
	if (is_undefined(_plain_buffer) || !buffer_exists(_plain_buffer))
	{
		__cyg_error("ChaCha20-Poly1305: _plain_buffer is not a valid buffer.");
		return { success: false, ciphertext_buffer: undefined, tag_buffer: undefined, tag_bytes: undefined, tag_string: "", tag_hex: "" };
	}

	if (_aad_buffer != undefined && (is_undefined(_aad_buffer) || !buffer_exists(_aad_buffer)))
	{
		__cyg_error("ChaCha20-Poly1305: _aad_buffer is not a valid buffer.");
		return { success: false, ciphertext_buffer: undefined, tag_buffer: undefined, tag_bytes: undefined, tag_string: "", tag_hex: "" };
	}

	try
	{
		var _key_bytes = __chacha20_bytes_from_string(_key_string, 32, "key");
		var _nonce_bytes = __chacha20_bytes_from_string(_nonce_string, 12, "nonce");
		if (_key_bytes == undefined || _nonce_bytes == undefined)
		{
			return { success: false, ciphertext_buffer: undefined, tag_buffer: undefined, tag_bytes: undefined, tag_string: "", tag_hex: "" };
		}

		var _plain_bytes = __chacha20_buffer_to_bytes(_plain_buffer);
		var _cipher_bytes = __chacha20_xor_bytes(_plain_bytes, _key_bytes, _nonce_bytes, floor(_counter) & 0xFFFFFFFF);
		var _aad_bytes = (_aad_buffer == undefined) ? [] : __chacha20_buffer_to_bytes(_aad_buffer);
		var _tag_bytes = __chacha20_poly1305_tag(_key_bytes, _nonce_bytes, _aad_bytes, _cipher_bytes);

		var _cipher_buffer = __chacha20_bytes_to_buffer(_cipher_bytes);
		var _tag_buffer = __chacha20_bytes_to_buffer(_tag_bytes);

		return {
			success: true,
			ciphertext_buffer: _cipher_buffer,
			tag_buffer: _tag_buffer,
			tag_bytes: _tag_bytes,
			tag_string: __chacha20_bytes_to_string(_tag_bytes),
			tag_hex: __chacha20_bytes_to_hex(_tag_bytes)
		};
	}
	catch (_error)
	{
		__cyg_error($"ChaCha20-Poly1305: exception in encrypt: {_error}");
		return { success: false, ciphertext_buffer: undefined, tag_buffer: undefined, tag_bytes: undefined, tag_string: "", tag_hex: "" };
	}
}

/// @desc Decrypts using AEAD ChaCha20-Poly1305.
/// @return {Struct} { success, plaintext_buffer, tag_ok }
function chacha20_poly1305_decrypt(_cipher_buffer, _key_string, _nonce_string, _tag, _aad_buffer = undefined, _counter = 1)
{
	if (is_undefined(_cipher_buffer) || !buffer_exists(_cipher_buffer))
	{
		__cyg_error("ChaCha20-Poly1305: _cipher_buffer is not a valid buffer.");
		return { success: false, plaintext_buffer: undefined, tag_ok: false };
	}

	if (_aad_buffer != undefined && (is_undefined(_aad_buffer) || !buffer_exists(_aad_buffer)))
	{
		__cyg_error("ChaCha20-Poly1305: _aad_buffer is not a valid buffer.");
		return { success: false, plaintext_buffer: undefined, tag_ok: false };
	}

	try
	{
		var _key_bytes = __chacha20_bytes_from_string(_key_string, 32, "key");
		var _nonce_bytes = __chacha20_bytes_from_string(_nonce_string, 12, "nonce");
		var _tag_bytes = __chacha20_tag_to_bytes(_tag);
		if (_key_bytes == undefined || _nonce_bytes == undefined || _tag_bytes == undefined)
		{
			__cyg_error("ChaCha20-Poly1305: invalid key, nonce, or tag.");
			return { success: false, plaintext_buffer: undefined, tag_ok: false };
		}

		var _cipher_bytes = __chacha20_buffer_to_bytes(_cipher_buffer);
		var _aad_bytes = (_aad_buffer == undefined) ? [] : __chacha20_buffer_to_bytes(_aad_buffer);
		var _expected_tag = __chacha20_poly1305_tag(_key_bytes, _nonce_bytes, _aad_bytes, _cipher_bytes);

		if (!__chacha20_tag_equals(_tag_bytes, _expected_tag))
		{
			__cyg_error("ChaCha20-Poly1305: authentication failed (invalid tag).");
			return { success: false, plaintext_buffer: undefined, tag_ok: false };
		}

		var _plain_bytes = __chacha20_xor_bytes(_cipher_bytes, _key_bytes, _nonce_bytes, floor(_counter) & 0xFFFFFFFF);
		var _plain_buffer = __chacha20_bytes_to_buffer(_plain_bytes);

		return { success: true, plaintext_buffer: _plain_buffer, tag_ok: true };
	}
	catch (_error)
	{
		__cyg_error($"ChaCha20-Poly1305: exception in decrypt: {_error}");
		return { success: false, plaintext_buffer: undefined, tag_ok: false };
	}
}

// Inicializa las variables estáticas del sistema Cyg.
script_execute(Cyg);