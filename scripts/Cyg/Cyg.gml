/// @ignore [MAJOR-MINOR-PATCH]
#macro CYG_VERSION			"1_1_0"

/// @ignore Show warning messages in the console.
#macro CYG_LOG_ALERTS		true

/// @ignore Show error messages in the console.
#macro CYG_LOG_ERRORS		true

/// @ignore If true, fatal errors crash the game.
#macro CYG_FATAL_ERRORS		false

/// @ignore Whether to create a backup before overwriting save files.
#macro CYG_BACKUPS_ENABLED	true

/// @ignore Pattern used to identify timestamped backup files. {0} is the file name, {1} is the timestamp placeholder.
#macro CYG_BACKUP_FILENAME_FORMAT	"{0}_{1}.bak"

/// @ignore Maximum number of timestamped backups kept per save file. When a new backup
/// pushes the count over this limit, the oldest ones are deleted. Use 0 to keep none.
#macro CYG_BACKUP_MAX_COUNT	1

/// @ignore Whether to compress buffers before saving.
#macro CYG_COMPRESS_ENABLED	false

/// @ignore Depth used when creating the Cyg manager object.
#macro CYG_MANAGER_DEPTH	-10000

/// @ignore Default master key for ChaCha20-Poly1305 (32 ASCII bytes in an array).
#macro CYG_MASTER_KEY		[67, 89, 71, 95, 77, 65, 83, 84, 69, 82, 95, 75, 69, 89, 95, 68, 69, 70, 65, 85, 76, 84, 95, 51, 50, 95, 66, 89, 84, 69, 83, 33]

__cyg_alert($"Cyg v{CYG_VERSION}. Made by toto.");

/// @desc Simple and robust save/load system. Manages game data, stores it as JSON,
/// supports optional encryption, and handles save migrations through fixer functions.
function Cyg()
{
	#region PRIVATE

		#region FIELDS

		/// @ignore
		/// @type {Struct}
		/// @desc Main in-memory data store.
		static __data =
		{
			__cyg_version:  CYG_VERSION,
			__file_version: -1,
		};

		/// @ignore
		/// @type {String|Array<Real>|Id.Buffer|Undefined}
		/// @desc Encryption key used by Export/Import, undefined when CYG_MASTER_KEY is used.
		static __custom_key = undefined;

		/// @ignore
		/// @type {Real}
		/// @desc Current save-data version.
		static __version = -1;

		/// @ignore
		/// @type {Struct<Real, Method>}
		/// @desc Migration fixer functions keyed by file version.
		static __fixers = {};

		/// @ignore
		/// @type {Bool}
		/// @desc Avoids repeating warnings for invalid master keys.
		static __master_key_warned = false;

		/// @ignore
		/// @type {Struct<Real, Struct>}
		/// @desc Pending async operations keyed by async request id.
		static __async_requests = {};

		/// @ignore
		/// @type {Real}
		/// @desc Hash of the current file version for integrity checks.
		static __hash_file_version = variable_get_hash("__file_version");

		/// @ignore
		/// @type {Real}
		/// @desc Hash of the Cyg version string for integrity checks.
		static __hash_cyg_version = variable_get_hash("__cyg_version");

		/// @ignore
		/// @type {Real}
		/// @desc Hash of the data for integrity checks.
		static __hash_data = variable_get_hash("__data");

		#endregion

		#region METHODS

		/// @ignore
		/// @desc Validates CYG_MASTER_KEY (array of 32 numeric bytes 0..255).
		/// @return {Bool} Whether the master key is a usable 32-byte array.
		static __IsMasterKeyValid = function()
		{
			if (!is_array(CYG_MASTER_KEY) ) return false;
			if (array_length(CYG_MASTER_KEY) != 32) return false;

			var i = 0; repeat(32)
			{
				var _b = CYG_MASTER_KEY[i++];
				if (!is_real(_b) ) return false;
				if (_b < 0 || _b > 255) return false;
			}

			return true;
		}

		/// @ignore
		/// @desc Returns the effective key: custom key (if set) or CYG_MASTER_KEY.
		/// @return {String|Array<Real>|Id.Buffer} Key bytes, or an empty string when no key is valid.
		static __GetEffectiveKey = function()
		{
			if (!is_undefined(__custom_key) ) return __custom_key;

			if (!__IsMasterKeyValid() )
			{
				if (!__master_key_warned)
				{
					__cyg_error("CYG_MASTER_KEY is invalid. It must be an array of 32 ASCII values between 0 and 255.");
					__master_key_warned = true;
				}

				return "";
			}

			return CYG_MASTER_KEY;
		}

		/// @ignore
		/// @desc Indicates whether a valid key is available for encrypt/decrypt.
		/// @return {Bool} Whether a usable 32-byte key exists.
		static __HasEncryptionKey = function()
		{
			var _key = __GetEffectiveKey();
			if (is_string(_key) ) return string_byte_length(_key) == 32;
			if (is_array(_key) ) return array_length(_key) == 32;
			if (buffer_exists(_key) ) return buffer_get_size(_key) == 32;
			return false;
		}

		/// @ignore
		/// @desc Generates a random 12-byte nonce for ChaCha20-Poly1305.
		/// @return {Array<Real>} Twelve random bytes in the 0..255 range.
		static __GenerateNonce = function()
		{
			var _nonce = array_create(12, 0);
			var i = 0; repeat(12)
			{
				_nonce[i++] = irandom(255);
			}

			return _nonce;
		}

		/// @ignore
		/// @desc Returns timestamp in YYYYMMDD_HHMMSS format.
		/// @return {String} The current date and time as a sortable stamp.
		static __GetTimestamp = function()
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

		/// @ignore
		/// @desc Executes a callback function safely, catching any exceptions and logging them.
		/// @param {Method} callback Callback to invoke.
		/// @param {Bool} success Whether the operation succeeded.
		/// @param {Any} data Data handed to the callback.
		static __ExecuteCallback = function(_callback, _success, _data)
		{
			try
			{
				_callback(_success, _data);
			}
			catch (_exception)
			{
				__cyg_error($"Exception in callback: {string(_exception)}");
			}
		}

		/// @ignore
		/// @desc Returns every existing backup path for a save file, ordered oldest to newest.
		/// @param {String} path Save-file path whose backups are listed.
		/// @return {Array<String>} Existing backup paths.
		static __GetBackupPaths = function(_path)
		{
			var _paths = [];
			var _directory = filename_path(_path);
			var _has_directory = string_length(_directory) > 0;
			var _mask = string(CYG_BACKUP_FILENAME_FORMAT, filename_name(_path), "*");
			var _item = file_find_first(_has_directory ? fp_join_path(_directory, _mask) : _mask, 0);

			while (_item != "")
			{
				// file_find_first() drops the directory it was given, so it is rebuilt here.
				if (_has_directory && !fp_is_absolute(_item) ) _item = fp_join_path(_directory, _item);

				array_push(_paths, _item);
				_item = file_find_next();
			}

			if (array_length(_paths) > 0) file_find_close();

			// Timestamps sort chronologically as strings.
			array_sort(_paths, true);

			return _paths;
		}

		/// @ignore
		/// @desc Returns the latest backup path for a save file.
		/// @param {String} path Save-file path whose backups are inspected.
		/// @return {String|Undefined} Newest backup path, or undefined when none exists.
		static __FindLatestBackupPath = function(_path)
		{
			var _backups = __GetBackupPaths(_path);
			var _count = array_length(_backups);

			return (_count > 0) ? _backups[_count - 1] : undefined;
		}

		/// @ignore
		/// @desc Deletes the oldest backups so at most CYG_BACKUP_MAX_COUNT remain.
		/// @param {String} path Save-file path whose backups are pruned.
		static __PruneBackups = function(_path)
		{
			var _max = max(0, floor(CYG_BACKUP_MAX_COUNT) );
			var _backups = __GetBackupPaths(_path);
			var _excess = array_length(_backups) - _max;

			for (var i = 0; i < _excess; i++)
			{
				if (file_exists(_backups[i]) ) file_delete(_backups[i]);
			}
		}

		/// @ignore
		/// @desc Resolves the path handed to the asynchronous buffer functions.
		/// A relative path stays relative, and a path inside the save area becomes relative while
		/// the sandbox is enabled because the sandbox rejects absolute paths. Validation and
		/// normalization come from fixpath's fp_resolve_path().
		/// @param {String} path Path to resolve.
		/// @return {String|Undefined} Usable path, or undefined when the path is not usable.
		static __ResolvePath = function(_path)
		{
			return fp_resolve_path(_path);
		}

		/// @ignore
		/// @desc Resolves the same file for the synchronous file functions (backups, delete, find).
		/// buffer_save_async() writes a relative path inside a "default" folder of the save area that
		/// no other file function adds, and fixpath's fp_sync_path() is the single call that handles
		/// it: it accepts the logical name, an absolute save-area path or an already resolved path,
		/// adds that folder exactly once and keeps the result relative while the sandbox is enabled.
		/// @param {String} path Path passed to Export, Import, Delete or RestoreBackup.
		/// @return {String|Undefined} Path the synchronous file functions must use.
		static __ResolveSyncPath = function(_path)
		{
			return fp_sync_path(_path);
		}

		/// @ignore
		/// @desc Encrypts with ChaCha20-Poly1305 and packs nonce+tag+ciphertext.
		/// @param {Id.Buffer} plain_buffer Buffer holding the plaintext.
		/// @param {String|Array<Real>|Id.Buffer} key 32-byte encryption key.
		/// @return {Id.Buffer|Undefined} Packed buffer, or undefined when encryption fails.
		static __ChaChaEncryptPacked = function(_plain_buffer, _key)
		{
			var _nonce = __GenerateNonce();
			var _enc = chacha20_poly1305_encrypt(_plain_buffer, _key, _nonce, undefined, 1);
			if (!_enc.success) return undefined;

			var _cipher = _enc.ciphertext_buffer;
			var _tag = _enc.tag_buffer;
			var _cipher_size = buffer_get_size(_cipher);
			var _packed = buffer_create(12 + 16 + _cipher_size, buffer_fixed, 1);

			var i = 0; repeat(12)
			{
				buffer_write(_packed, buffer_u8, _nonce[i++]);
			}

			buffer_seek(_packed, buffer_seek_start, 12);
			buffer_copy(_tag, 0, 16, _packed, 12);
			buffer_copy(_cipher, 0, _cipher_size, _packed, 28);
			buffer_seek(_packed, buffer_seek_start, 0);

			buffer_delete(_cipher);
			buffer_delete(_tag);

			return _packed;
		}

		/// @ignore
		/// @desc Decrypts a packed nonce+tag+ciphertext buffer.
		/// @param {Id.Buffer} packed_buffer Buffer produced by __ChaChaEncryptPacked.
		/// @param {String|Array<Real>|Id.Buffer} key 32-byte encryption key.
		/// @return {Id.Buffer|Undefined} Plaintext buffer, or undefined when decryption fails.
		static __ChaChaDecryptPacked = function(_packed_buffer, _key)
		{
			var _size = buffer_get_size(_packed_buffer);
			if (_size < 28)
			{
				__cyg_error("ChaCha20-Poly1305: invalid encrypted buffer (too small).");
				return undefined;
			}

			var _nonce_buf = buffer_create(12, buffer_fixed, 1);
			buffer_copy(_packed_buffer, 0, 12, _nonce_buf, 0);
			buffer_seek(_nonce_buf, buffer_seek_start, 0);

			var _tag_buf = buffer_create(16, buffer_fixed, 1);
			buffer_copy(_packed_buffer, 12, 16, _tag_buf, 0);
			buffer_seek(_tag_buf, buffer_seek_start, 0);

			var _cipher_size = _size - 28;
			var _cipher = buffer_create(_cipher_size, buffer_fixed, 1);
			buffer_copy(_packed_buffer, 28, _cipher_size, _cipher, 0);

			var _dec = chacha20_poly1305_decrypt(_cipher, _key, _nonce_buf, _tag_buf, undefined, 1);
			buffer_delete(_cipher);
			buffer_delete(_nonce_buf);
			buffer_delete(_tag_buf);

			return (_dec.success && _dec.tag_ok) ? _dec.plaintext_buffer : undefined;
		}

		/// @ignore
		/// @desc Prepares data buffer for export (encrypt and/or compress).
		/// @param {String} string JSON payload to store.
		/// @param {Bool} encrypt Whether to encrypt the payload.
		/// @param {Bool} compress Whether to compress the payload.
		/// @return {Id.Buffer|Undefined} Ready-to-write buffer, or undefined on failure.
		static __PrepareDataBuffer = function(_string, _encrypt, _compress)
		{
			var _temp_buffer = buffer_create(string_byte_length(_string) + 1, buffer_fixed, 1);
			buffer_write(_temp_buffer, buffer_string, _string);

			if (_encrypt)
			{
				var _effective_key = __GetEffectiveKey();
				var _encrypted_buffer = __ChaChaEncryptPacked(_temp_buffer, _effective_key);
				if (is_undefined(_encrypted_buffer) )
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

		/// @ignore
		/// @desc Extracts JSON string from the loaded buffer (decompress and/or decrypt).
		/// @param {Id.Buffer} data_buffer Buffer holding the stored payload.
		/// @param {Bool} encrypt Whether the payload is encrypted.
		/// @param {Bool} compress Whether the payload is compressed.
		/// @param {String|Array<Real>|Id.Buffer} [encryption_key=undefined] Key used to decrypt.
		/// @return {String} Extracted JSON, or an empty string when extraction fails.
		static __ExtractDataString = function(_data_buffer, _encrypt, _compress, _encryption_key=undefined)
		{
			var _working_buffer = _data_buffer;

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
				var _decrypted_buffer = __ChaChaDecryptPacked(_working_buffer, _encryption_key);
				if (is_undefined(_decrypted_buffer) )
				{
					buffer_delete(_working_buffer);
					return "";
				}

				buffer_delete(_working_buffer);
				_working_buffer = _decrypted_buffer;
			}

			buffer_seek(_working_buffer, buffer_seek_start, 0);
			var _final_string = buffer_read(_working_buffer, buffer_string);
			buffer_delete(_working_buffer);

			return _final_string;
		}

		/// @ignore
		/// @desc Ensures manager object exists in the game.
		static __RefreshManager = function()
		{
			if (!instance_exists(o_cyg_manager) )
			{
				var _id = instance_create_depth(0, 0, CYG_MANAGER_DEPTH, o_cyg_manager);
				__cyg_alert($"Creating o_cyg_manager instance ({_id}).");
			}
			else
			{
				__cyg_alert("Activating existing o_cyg_manager instance.");
				instance_activate_object(o_cyg_manager);
			}
		}

		/// @ignore
		/// @desc Builds the final buffer ready to be saved.
		/// @param {String} [key=undefined] Key to save a specific value from the data store.
		/// @param {Bool} encrypt Whether to encrypt the data.
		/// @param {Bool} compress Whether to compress the data.
		/// @return {Id.Buffer|Undefined} Buffer ready for writing, or undefined on failure.
		static __BuildExportBuffer = function(_key, _encrypt, _compress)
		{
			var _string = undefined;
			if (_key != undefined)
			{
				var _value_to_save = Get(_key);
				var _export_struct = { __cyg_version: CYG_VERSION, __file_version: __version, __data: _value_to_save };

				_string = json_stringify(_export_struct);
			}
			else
			{
				__data.__file_version = __version;
				_string = json_stringify(__data);
			}

			if (_encrypt && !__HasEncryptionKey() )
			{
				__cyg_alert("Encryption requested without a valid key. Use CYG_MASTER_KEY or SetEncryptKey().");
				_encrypt = false;
			}

			var _data_buffer =	__PrepareDataBuffer(_string, _encrypt, _compress);
			if (is_undefined(_data_buffer) ) return undefined;

			// Compute SHA-256 hash of the data buffer and prepend it to the final buffer.
			var _hash = sha256_buffer(_data_buffer, 0, buffer_get_size(_data_buffer) );
			var _final_buffer =	buffer_create(1, buffer_grow, 1);

			buffer_write(_final_buffer, buffer_string, _hash);
			buffer_copy(_data_buffer, 0, buffer_get_size(_data_buffer), _final_buffer, buffer_tell(_final_buffer) );
			buffer_delete(_data_buffer);

			return _final_buffer;
		}

		/// @ignore
		/// @desc Processes a loaded buffer and returns final data.
		/// @param {Id.Buffer} loaded_buffer Buffer read from disk.
		/// @param {String} path Path the buffer came from, used for diagnostics.
		/// @param {String|Undefined} key Key whose value was saved, undefined for the whole store.
		/// @param {Bool} encrypt Whether the payload is encrypted.
		/// @param {Bool} compress Whether the payload is compressed.
		/// @param {String|Array<Real>|Id.Buffer} [encryption_key=undefined] Key used to decrypt.
		/// @return {Struct} Result struct with `success` and `data` fields.
		static __ProcessImportBuffer = function(_loaded_buffer, _path, _key, _encrypt, _compress, _encryption_key)
		{
			buffer_seek(_loaded_buffer, buffer_seek_start, 0);
			var _saved_hash = buffer_read(_loaded_buffer, buffer_string);
			var _data_offset = buffer_tell(_loaded_buffer);
			var _data_size = buffer_get_size(_loaded_buffer) - _data_offset;

			if (_data_size <= 0)
			{
				__cyg_error($"File '{_path}' is empty or corrupted.");
				return { success: false, data: undefined };
			}

			var _calculated_hash = sha256_buffer(_loaded_buffer, _data_offset, _data_size);
			if (_saved_hash != _calculated_hash)
			{
				__cyg_error($"Checksum failed! File '{_path}' is corrupted or has been modified.");
				return { success: false, data: undefined };
			}

			var _data_buffer = buffer_create(_data_size, buffer_fixed, 1);
			buffer_copy(_loaded_buffer, _data_offset, _data_size, _data_buffer, 0);

			if (_encrypt && is_undefined(_encryption_key) )
			{
				__cyg_alert("Decryption requested without a valid key. Use CYG_MASTER_KEY or SetEncryptKey().");
				buffer_delete(_data_buffer);

				return { success: false, data: undefined };
			}

			var _string = __ExtractDataString(_data_buffer, _encrypt, _compress, _encryption_key);
			if (_string == "")
			{
				return { success: false, data: undefined };
			}

			var _parsed_data = json_parse(_string);

			if (!is_struct(_parsed_data)
				|| !struct_exists_from_hash(_parsed_data, __hash_file_version)
				|| !struct_exists_from_hash(_parsed_data, __hash_cyg_version) )
			{
				__cyg_alert($"Imported file '{_path}' does not contain a valid Cyg save.");
				return { success: false, data: undefined };
			}

			var _file_version = struct_get_from_hash(_parsed_data, __hash_file_version);
			var _data_to_fix = undefined;
			if (_key == undefined)
			{
				_data_to_fix = _parsed_data;
			}
			else
			{
				if (!struct_exists_from_hash(_parsed_data, __hash_data) )
				{
					__cyg_alert($"Imported file '{_path}' does not contain a keyed Cyg payload.");
					return { success: false, data: undefined };
				}

				_data_to_fix = struct_get_from_hash(_parsed_data, __hash_data);
			}
			var _final_data = _data_to_fix;
			var _fixer_func = __fixers[$ string(_file_version)];
			if (is_callable(_fixer_func) ) _final_data = _fixer_func(_data_to_fix);

			return { success: true, data: _final_data };
		}

		/// @ignore
		/// @desc Processes async events. Must be called from Async - Save/Load event.
		/// @param {Struct} async_load Async event data provided by GameMaker.
		static __ProcessAsyncEvent = function(_async_load)
		{
			var _id = _async_load[? "id"];
			if (!struct_exists(__async_requests, _id) ) return;

			var _request = __async_requests[$ _id];
			var _status = _async_load[? "status"];
			if (!_status)
			{
				__cyg_alert($"Async operation failed for id={_id}, type={_request.type}");
				__cyg_alert("Sandboxed targets reject unwritable paths and missing files.");

				// The callback must still fire so callers never wait forever.
				__ExecuteCallback(_request.callback, false, undefined);

				return self;
			}

			if (_request.type == "export")
			{
				__cyg_alert("ProcessAsyncEvent export");
				try
				{
					if (buffer_exists(_request.buffer) ) buffer_delete(_request.buffer);
					__ExecuteCallback(_request.callback, true, undefined);
				}
				catch (_error)
				{
					__cyg_error($"Exception in ProcessAsyncEvent (export): {_error}");
					__ExecuteCallback(_request.callback, false, undefined);
				}
			}
			else if (_request.type == "import")
			{
				__cyg_alert("ProcessAsyncEvent import");
				var _loaded_buffer = _request.buffer;

				try
				{
					var _final_data = undefined;
					var _size = buffer_get_size(_loaded_buffer);

					__cyg_alert($"Import buffer processing, size={_size}");

					var _result = __ProcessImportBuffer(
						_loaded_buffer,
						_request.path,
						_request.key,
						_request.encrypt,
						CYG_COMPRESS_ENABLED,
						_request.encryption_key
					);
					__cyg_alert($"Import result.success={_result.success}");

					// A keyless import replaces the whole store, a keyed one only its own slot.
					if (_result.success)
					{
						_final_data = _result.data;
						if (_request.key == undefined)
						{
							static_get(Cyg).__data = _final_data;
						}
						else
						{
							Set(_request.key, _final_data);
						}
					}

					__ExecuteCallback(_request.callback, _result.success, _final_data);
				}
				catch (_error)
				{
					__cyg_error($"Exception in ProcessAsyncEvent (import): {_error}");
					__ExecuteCallback(_request.callback, false, undefined);
				}

				if (buffer_exists(_loaded_buffer) ) buffer_delete(_loaded_buffer);
			}

			// Remove the request from the registry to free up resources.
			if (struct_exists(__async_requests, _id) ) struct_remove(__async_requests, _id);
		}

		#endregion

	#endregion

	#region PUBLIC

		#region METHODS

		/// @desc Sets the version of data that will be saved.
		/// @param {Real} version Version number to set.
		/// @return {Struct.Cyg} this instance
		static SetVersion = function(_version)
		{
			__version = _version;
			return self;
		}

		/// @desc Sets the encryption key used by Export and Import.
		/// @param {String|Array<Real>|Id.Buffer|Undefined} key Key bytes, undefined to use CYG_MASTER_KEY.
		/// @return {Struct.Cyg} this instance
		static SetEncryptKey = function(_key)
		{
			if (is_undefined(_key) )
			{
				__custom_key = undefined;
				return self;
			}

			__custom_key = _key;

			return self;
		}

		/// @desc Registers a fixer function for a specific save-file version.
		/// @param {Real|String} version_key File version that triggers this fixer.
		/// @param {Method} callback Fixer function. Must accept a struct and return a struct.
		/// @return {Struct.Cyg} this instance
		static AddFixer = function(_version_key, _callback)
		{
			if (!is_callable(_callback) )
			{
				var _callback_type = typeof(_callback);
				__cyg_error($"The fixer for version {_version_key} is not a function, it is {_callback_type}.");
				return self;
			}

			__fixers[$ string(_version_key)] = _callback;
			return self;
		}

		/// @desc Saves data to a file ASYNCHRONOUSLY.
		/// @param {String} path Path of the save file.
		/// @param {String} [key=undefined] Key of the value to save, undefined to save the whole store.
		/// @param {Bool} [encrypt=false] Whether to encrypt the payload.
		/// @param {Method} [callback=undefined] Callback receiving `success:Bool`.
		static Export = function(_path, _key=undefined, _encrypt=false, _callback=undefined)
		{
			static __default_callback = function(_success) { };
			_callback ??= __default_callback;

			// Log export start.
			__cyg_alert($".Export() started\nPath={_path}, Key={_key}, Encrypt={_encrypt}");
			__RefreshManager();

			var _async_path = __ResolvePath(_path);
			var _sync_path = __ResolveSyncPath(_path);
			if (is_undefined(_async_path) || is_undefined(_sync_path) )
			{
				__cyg_alert($"Invalid file path: '{_path}'.");
				__ExecuteCallback(_callback, false, undefined);

				exit;
			}

			// Create a backup if the file already exists and backups are enabled.
			if (CYG_BACKUPS_ENABLED && file_exists(_sync_path) )
			{
				var _timestamp = __GetTimestamp();
				var _backup_path = string(CYG_BACKUP_FILENAME_FORMAT, _sync_path, _timestamp);
				file_rename(_sync_path, _backup_path);

				__cyg_alert($"Backup created: {_backup_path}");
				__PruneBackups(_sync_path);
			}

			var _final_buffer = __BuildExportBuffer(_key, _encrypt, CYG_COMPRESS_ENABLED);
			if (is_undefined(_final_buffer) )
			{
				__cyg_alert("Failed to build export buffer. Export aborted.");
				__ExecuteCallback(_callback, false, undefined);

				exit;
			}

			// Start async save operation.
			var _size = buffer_get_size(_final_buffer);
			var _async_id = buffer_save_async(_final_buffer, _async_path, 0, _size);
			if (_async_id < 0)
			{
				__cyg_error($"Could not start async save for '{_async_path}'. The target may be read-only.");
				// Do not delete buffers here: failed async starts may still hold runtime references briefly.
				__ExecuteCallback(_callback, false, undefined);

				exit;
			}

			__cyg_alert($"Export async_id={_async_id}, buffer_size={_size}");

			__async_requests[$ _async_id] = {
				type:		"export",
				callback:	_callback,
				buffer:		_final_buffer,
				path:		_async_path
			};
		}

		/// @desc Loads data from a file ASYNCHRONOUSLY.
		/// @param {String} path Path of the save file.
		/// @param {String} [key=undefined] Key where the imported data is stored, undefined for the whole store.
		/// @param {Bool} [encrypt=false] Whether the payload is encrypted.
		/// @param {Method} [callback=undefined] Callback receiving `success:Bool` and `data:Any`.
		static Import = function(_path, _key=undefined, _encrypt=false, _callback=undefined)
		{
			static __default_callback = function(_success, _data) { };
			_callback ??= __default_callback;

			__cyg_alert($".Import() started\nPath={_path}, Key={_key}");
			__RefreshManager();

			var _async_path = __ResolvePath(_path);
			var _sync_path = __ResolveSyncPath(_path);
			if (is_undefined(_async_path) || is_undefined(_sync_path) )
			{
				__cyg_alert($"Invalid file path: '{_path}'.");
				__ExecuteCallback(_callback, false, undefined);

				exit;
			}

			var _file_exists = file_exists(_sync_path);
			__cyg_alert($"Import target file_exists={_file_exists}");

			if (!_file_exists)
			{
				__cyg_alert($"File '{_async_path}' does not exist.");
				__ExecuteCallback(_callback, false, undefined);

				exit;
			}

			var _encryption_key = undefined;
			if (_encrypt)
			{
				if (!__HasEncryptionKey() )
				{
					__cyg_alert("Decryption requested without a valid key. Use CYG_MASTER_KEY or SetEncryptKey().");
					__ExecuteCallback(_callback, false, undefined);
					exit;
				}

				_encryption_key = __GetEffectiveKey();
			}

			// Create a target buffer where async load writes data.
			var _target_buffer = buffer_create(1, buffer_grow, 1);
			var _async_id = buffer_load_async(_target_buffer, _async_path, 0, -1);
			if (_async_id < 0)
			{
				__cyg_error($"Could not start async load for '{_async_path}'.");
				// Do not delete buffers here: failed async starts may still hold runtime references briefly.
				__ExecuteCallback(_callback, false, undefined);

				exit;
			}

			// Log async load creation and store request details.
			__cyg_alert($"Import async_id={_async_id} created buffer");
			__async_requests[$ _async_id] = {
				type:		"import",
				callback:	_callback,
				key:		_key,
				encrypt:	_encrypt,
				encryption_key: _encryption_key,
				path:		_async_path,
				buffer:		_target_buffer
			};
		}

		/// @desc Restores a save file from its latest backup.
		/// @param {String} path Save-file path (example: "save/slot1.sav").
		/// @return {Bool} Returns true if backup restoration succeeds.
		static RestoreBackup = function(_path)
		{
			_path = __ResolveSyncPath(_path);
			if (is_undefined(_path) )
			{
				__cyg_alert($"Invalid file path: '{_path}'.");
				return false;
			}

			var _backup_path = __FindLatestBackupPath(_path);
			if (CYG_BACKUPS_ENABLED && !is_undefined(_backup_path) && file_exists(_backup_path) )
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
		/// @param {Any} value Value to store.
		/// @return {Struct.Cyg} this instance
		static Set = function(_key, _value)
		{
			__data[$ _key] = _value;

			return self;
		}

		/// @desc Gets a value from the data store.
		/// @param {String} key Key to retrieve.
		/// @param {Any} [default_value=undefined] Value returned when the key does not exist.
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
		/// @param {String} path Path of the file to delete.
		/// @return {Bool} Returns true if the save file was deleted.
		static Delete = function(_path)
		{
			_path = __ResolveSyncPath(_path);
			if (is_undefined(_path) )
			{
				__cyg_alert($"Invalid file path: '{_path}'.");
				return false;
			}

			var _backups = __GetBackupPaths(_path);
			for (var i = 0; i < array_length(_backups); i++)
			{
				if (file_exists(_backups[i]) ) file_delete(_backups[i]);
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
				__cyg_version:  CYG_VERSION,
				__file_version: -1,
			};
		}

		#endregion

	#endregion
}

/// @ignore
/// @desc Logs an alert message to the console if CYG_LOG_ALERTS is enabled.
/// @param {String} msg Message to log.
function __cyg_alert(_msg)
{
	if (CYG_LOG_ALERTS)
	{
		var _origin = ytrace_origin;
		_origin = string_replace_all(_origin, $"cyou_tobalsea_cyg_{CYG_VERSION}___", "tobalsea_cyg_");

		show_debug_message($"Cyg Alert:: {_origin}: {_msg}");
	}
}

/// @ignore
/// @desc Logs an error message if CYG_LOG_ERRORS is enabled, and crashes the game when CYG_FATAL_ERRORS is true.
/// @param {String} msg Error message to log.
function __cyg_error(_msg)
{
	if (CYG_LOG_ERRORS || CYG_FATAL_ERRORS)
	{
		var _origin = ytrace_origin;
		_origin = string_replace_all(_origin, $"cyou_tobalsea_cyg_{CYG_VERSION}___", "tobalsea_cyg_");
		show_debug_message($"Cyg Error:: {_origin}: {_msg}");
		
		// If strict mode is enabled crash the game with an error message to avoid silent failures.
		if (CYG_FATAL_ERRORS) show_error($"Cyg Error:: {_origin}: {_msg}", false);
	}
}

// Initializes the static variables of the Cyg system.
script_execute(Cyg);
