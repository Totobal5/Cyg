#macro __CYG_VERSION			"1.0"	// Versión de la librería actualizada
#macro __CYG_USE_BACKUPS		true	// Si crea un backup (.bak) de los archivos creados
#macro __CYG_USE_COMPRESS		false	// Si comprime los buffers antes de guardar.

/// @desc Sistema de guardado y carga de datos simple y robusto.
/// Permite gestionar datos de juego, guardarlos en formato JSON,
/// cifrarlos opcionalmente y manejar diferentes versiones de archivos
/// de guardado a través de funciones "fixer".
function Cyg()
{
	/// @ignore Almacén principal de datos en memoria.
    static data = 
	{
        __CygVersion: __CYG_VERSION,
        __FileVersion: -1,
    };
	
    /// @ignore LLave de cifrado para las funciones de Export/Import.
    static encryptKey = "";
    /// @ignore Versión actual de los datos a guardar.
    static version = -1;
	/// @ignore Struct que almacena las funciones de migración (fixers) por versión.
    static fixers = {};

    /// @desc Cifrado de flujo RC4. Es simétrico, por lo que se usa tanto para cifrar como para descifrar.
    /// @param {Buffer} buffer_data El buffer con los datos a procesar.
    /// @param {String} key La clave de cifrado.
	/// @ignore 
    /// @return {Buffer} Un nuevo buffer con los datos procesados.
    static __Cyg_RC4 = function(_buffer_data, _key)
    {
        // KSA (Key-Scheduling Algorithm): Inicialización del estado del cifrador.
        var S = array_create(256);
        for (var i = 0; i < 256; i++) { S[i] = i; }

        var j = 0;
        var key_len = string_length(_key);
        for (var i = 0; i < 256; i++)
        {
            j = (j + S[i] + string_byte_at(_key, (i % key_len) + 1)) & 255;
            var temp = S[i];
            S[i] = S[j];
            S[j] = temp;
        }

        // PRGA (Pseudo-Random Generation Algorithm): Generación del keystream y operación XOR.
        var i = 0, j = 0;
        var data_len = buffer_get_size(_buffer_data);
        var result_buffer = buffer_create(data_len, buffer_fixed, 1);
    
        buffer_seek(_buffer_data, buffer_seek_start, 0);

        for (var k = 0; k < data_len; k++)
        {
            i = (i + 1) & 255;
            j = (j + S[i]) & 255;

            var temp = S[i];
            S[i] = S[j];
            S[j] = temp;

            var keystream_byte = S[(S[i] + S[j]) & 255];
            var data_byte = buffer_read(_buffer_data, buffer_u8);
        
            buffer_write(result_buffer, buffer_u8, data_byte ^ keystream_byte);
        }
    
        return result_buffer;
    }

    /// @desc Prepara el buffer de datos para exportar (cifra y/o comprime).
	/// @ignore
    static __Cyg_Prepare_Data_Buffer = function(_string, _encrypt, _compress)
    {
        var _temp_buffer = buffer_create(string_byte_length(_string) + 1, buffer_fixed, 1);
        buffer_write(_temp_buffer, buffer_string, _string);

        if (_encrypt)
		{
			var _encrypted_buffer = __Cyg_RC4(_temp_buffer, encryptKey);
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

    /// @desc Extrae el string JSON del buffer cargado (descomprime y/o descifra).
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
				show_debug_message("CYG WARNING: La descompresión falló. Tratando los datos como no comprimidos.");
				buffer_delete(_decompressed_buffer);
		    }
		}
        
		if (_encrypt)
		{
		    var _decrypted_buffer = __Cyg_RC4(_working_buffer, encryptKey);
		    buffer_delete(_working_buffer);
		    var _working_buffer = _decrypted_buffer;
		}
        
		buffer_seek(_working_buffer, buffer_seek_start, 0);
		var _final_string = buffer_read(_working_buffer, buffer_string);
		buffer_delete(_working_buffer);
        
		return _final_string;
    }

    /// @ignore Se asegura de que el objeto gestor exista en el juego.
    static __Cyg_Init_Manager = function()
    {
		if (instance_exists(o_cyg_manager) ) exit;
		
		show_debug_message("CYG INFO: Creando instancia de o_cyg_manager.");
		instance_create_layer(0, 0, "__CygInstances", o_cyg_manager);
    }

	/// @ignore Construye el buffer final listo para ser guardado.
	static __Cyg_Build_Export_Buffer = function(_key, _encrypt, _compress)
	{
	    var _string;
	    if (_key != undefined)
		{
	        var _value_to_save = Get(_key);
			var _export_struct = { __CygVersion: __CYG_VERSION, __FileVersion: version, __data: _value_to_save };
			
			_string = json_stringify(_export_struct);
	    } 
		else 
		{
	        data.__FileVersion = version;
	        _string = json_stringify(data);
	    }
        
	    if (_encrypt && encryptKey == "")
		{
			show_debug_message("CYG WARNING: Se intentó cifrar sin 'encryptKey'.");	
	        _encrypt = false;
	    }

	    var _data_buffer =	__Cyg_Prepare_Data_Buffer(_string, _encrypt, _compress);
	    var _hash =			buffer_md5(_data_buffer, 0, buffer_get_size(_data_buffer) );
	    var _final_buffer =	buffer_create(1, buffer_grow, 1);
        
	    buffer_write(_final_buffer, buffer_string, _hash);
	    buffer_copy(_data_buffer, 0, buffer_get_size(_data_buffer), _final_buffer, buffer_tell(_final_buffer));
	    buffer_delete(_data_buffer);
        
	    return _final_buffer;
	}
    
    /// @ignore Procesa un buffer cargado y devuelve los datos finales.
    static __Cyg_Process_Import_Buffer = function(_loaded_buffer, _path, _encrypt, _compress)
    {
		static DFix = function(_struct) { return _struct; }
		
        var _saved_hash = buffer_read(_loaded_buffer, buffer_string);
		var _data_offset = buffer_tell(_loaded_buffer);
		var _data_size = buffer_get_size(_loaded_buffer) - _data_offset;
        
        if (_data_size <= 0) 
		{
			show_debug_message($"CYG ERROR: Archivo '{_path}' está vacío o corrupto.");
			return { success: false, data: undefined };
        }
        
		var _calculated_hash = buffer_md5(_loaded_buffer, _data_offset, _data_size);
		if (_saved_hash != _calculated_hash) 
		{
			show_debug_message($"CYG ERROR: ¡Checksum fallido! El archivo '{_path}' está corrupto o modificado.");
			return { success: false, data: undefined };
		}
        
		var _data_buffer = buffer_create(_data_size, buffer_fixed, 1);
		buffer_copy(_loaded_buffer, _data_offset, _data_size, _data_buffer, 0);
		
		if (_encrypt && encryptKey == "") 
		{
			show_debug_message("CYG WARNING: Se intentó descifrar sin una 'encryptKey'.");
            buffer_delete(_data_buffer);
			return { success: false, data: undefined };
		}
        
		var _string = __Cyg_Extract_Data_String(_data_buffer, _encrypt, _compress);
        buffer_delete(_data_buffer);
		var _parsed_data = json_parse(_string);
		
		if (!is_struct(_parsed_data) && !is_array(_parsed_data) ) 
		{
			show_debug_message($"CYG WARNING: El archivo importado '{_path}' no contiene un JSON válido.");
			return { success: false, data: undefined };
		}
		
        var _file_version =	_parsed_data[$ "__FileVersion"] ?? -1;
        var _fixer_func =	fixers[$ string(_file_version)] ?? DFix;
        var _data_to_fix =	struct_exists(_parsed_data, "__data") ? _parsed_data.__data : _parsed_data;
        var _final_data =	_fixer_func(_data_to_fix);
        
		return { success: true, data: _final_data };
    }
	
    /// @desc Define la versión de los datos que se van a guardar.
    /// @param {Real} version El número de versión a establecer.
    /// @return {self} Permite encadenar métodos.
    static SetVersion = function(_version)
    {
        version = _version;
        return self;
    }
    
    /// @desc Define la llave de cifrado que se usará para Exportar e Importar.
    /// @param {String} key La llave de cifrado.
    /// @return {self} Permite encadenar métodos.
    static SetEncryptKey = function(_key)
    {
        encryptKey = _key;
        return self;
    }
    
	/// @desc Registra una función "fixer" para una versión específica del archivo de guardado.
	/// @param {Real|String} version_key La versión del archivo que activará este fixer.
	/// @param {Method} callback La función a ejecutar. Debe aceptar un struct como argumento y devolver un struct.
	/// @return {self} Permite encadenar métodos.
	static AddFixer = function(_version_key, _callback)
	{
		if (!is_method(_callback) )
        {
            show_debug_message($"CYG ERROR: El 'fixer' proporcionado para la versión {string(_version_key)} no es una función.");
			return self;
        }
		
		fixers[$ string(_version_key)] = _callback;
		return self;
	}
	
    /// @desc Guarda datos en un archivo, con opción de cifrado.
    /// @param {String} path La ruta completa donde se guardará el archivo (ej: "save/slot1.sav").
    /// @param {String} [key] Clave del struct a guardar. Si es 'undefined', se guarda toda la data.
    /// @param {Bool}   [encrypt] Si es 'true', se cifrarán los datos. Default: false.
    static Export = function(_path, _key=undefined, _encrypt=false)
    {
        if (__CYG_USE_BACKUPS && file_exists(_path) ) 
		{
            var _backup_path = _path + ".bak";
            if (file_exists(_backup_path)) { file_delete(_backup_path); }
			file_rename(_path, _backup_path);
        }
        
        var _final_buffer = __Cyg_Build_Export_Buffer(_key, _encrypt, __CYG_USE_COMPRESS);
        buffer_save(_final_buffer, _path);
        buffer_delete(_final_buffer);
    }
    
    /// @desc Carga datos desde un archivo, aplicando fixers si es necesario.
    /// @param {String} path La ruta completa del archivo a cargar (ej: "save/slot1.sav").
    /// @param {String} [key] Clave donde se guardarán los datos. Si es 'undefined', reemplaza toda la data.
    /// @param {Bool}   [encrypt] Si es 'true', se intentarán descifrar los datos. Default: false.
    /// @return {Bool} Devuelve 'true' si la carga fue exitosa, 'false' en caso contrario.
    static Import = function(_path, _key=undefined, _encrypt=false)
    {
		if (!file_exists(_path) ) return false;
		
        var _loaded_buffer = buffer_load(_path);
        var _result = __Cyg_Process_Import_Buffer(_loaded_buffer, _path, _encrypt, __CYG_USE_COMPRESS);
        buffer_delete(_loaded_buffer);
        
        if (_result.success) 
		{
            if (_key == undefined) { data = _result.data; } 
            else { Add(_key, _result.data); }
        }
        
        return _result.success;
    }

    /// @desc Guarda datos en un archivo de forma ASÍNCRONA.
    /// @param {String} path La ruta completa del archivo.
    /// @param {String} [key] Clave de los datos a guardar.
    /// @param {Bool}   [encrypt] Activa el cifrado.
    /// @param {Method} callback Función a llamar al finalizar. Recibe un argumento: (success:Bool).
    static ExportAsync = function(_path, _key=undefined, _encrypt=false, _callback=undefined)
    {
        __Cyg_Init_Manager();
        if (__CYG_USE_BACKUPS && file_exists(_path) ) 
		{
            var _backup_path = _path + ".bak";
            if (file_exists(_backup_path) ) { file_delete(_backup_path); }
            file_rename(_path, _backup_path);
        }

        var _final_buffer =	__Cyg_Build_Export_Buffer(_key, _encrypt, __CYG_USE_COMPRESS);
        var _size =			buffer_get_size(_final_buffer);
        var _async_id =		buffer_save_async(_final_buffer, _path, 0, _size);
        
        async_requests[? _async_id] = {
            type:		"export",
            callback:	_callback,
            buffer:		_final_buffer
        };
    }

    /// @desc Carga datos desde un archivo de forma ASÍNCRONA.
    /// @param {String} path La ruta completa del archivo.
    /// @param {String} [key] Clave donde se guardarán los datos.
    /// @param {Bool}   [encrypt] Activa el descifrado.
    /// @param {Method} callback Función a llamar al finalizar. Recibe dos argumentos: (success:Bool, data:Any).
    static ImportAsync = function(_path, _key=undefined, _encrypt=false, _callback=undefined)
    {
		__Cyg_Init_Manager();
        
		if (!file_exists(_path) ) 
		{
            if (is_method(_callback) ) _callback(false, undefined);
            exit;
        }
		
        // Se crea un buffer para que la función asíncrona cargue los datos en él.
        var _target_buffer = buffer_create(1, buffer_grow, 1);
        var _async_id = buffer_load_async(_target_buffer, _path, 0, -1);
        
        async_requests[? _async_id] = {
            type:		"import",
            callback:	_callback,
            key:		_key,
            encrypt:	_encrypt,
            path:		_path,
            buffer:     _target_buffer	// Se guarda la referencia al buffer de destino.
        };
    }

    /// @desc Procesa los eventos asíncronos. Debe ser llamado desde el evento Async - Save/Load.
    /// @param {DS_Map} async_load El mapa ds_map proporcionado por GameMaker.
    static ProcessAsyncEvent = function(_async_load)
    {
        var _id = _async_load[? "id"];
        if (!ds_map_exists(async_requests, _id) ) return;
        
        var _request = async_requests[? _id];
        var _status = _async_load[? "status"];
        var _callback = _request.callback;
        
        if (_request.type == "export") 
		{
            buffer_delete(_request.buffer);
            if (is_callable(_callback)) _callback(_status);
        } 
		else if (_request.type == "import")
		{
            var _loaded_buffer = _request.buffer;
            var _final_data = undefined;
            
            if (!_status) 
			{
                if (is_callable(_callback) ) _callback(false, _final_data);
            } 
			else
			{
                var _result = __Cyg_Process_Import_Buffer(_loaded_buffer, _request.path, _request.encrypt, __CYG_USE_COMPRESS);
                if (_result.success) 
				{
                    _final_data = _result.data;
                    if (_request.key == undefined) { data = _final_data; }
                    else { Add(_request.key, _final_data); }
                }
				
                if (is_callable(_callback)) _callback(_result.success, _final_data);
            }
			
            buffer_delete(_loaded_buffer);
        }
		
        ds_map_delete(async_requests, _id);
    }

    /// @desc Restaura un archivo de guardado desde su respaldo (.bak).
    /// @param {string} path La ruta del archivo de guardado original (ej: "save/slot1.sav").
    /// @return {Bool} Devuelve 'true' si el respaldo fue restaurado con éxito.
    static RestoreBackup = function(_path)
    {
		var _backup_path = _path + ".bak";
		if (__CYG_USE_BACKUPS && file_exists(_backup_path) ) 
		{
			if (file_exists(_path) ) file_delete(_path);
			file_rename(_backup_path, _path);
			
			return true;
		}
		
		show_debug_message($"CYG INFO: No se encontró un archivo de respaldo para '{_path}'.");
		
		return false;
    }
	
    /// @desc Añade o sobreescribe un valor en el almacén de datos.
    /// @param {String} key   La clave para asociar con el valor.
    /// @param {Struct} value El struct a serializar.
    /// @return {self} Permite encadenar métodos.
    static Add = function(_key, _value)
    {
        data[$ _key] = _value;
		
        return self;
    }
    
    /// @desc Obtiene un valor del almacén de datos.
    /// @param  {String} key             La clave del valor a obtener.
    /// @param  {Any*}   [default_value] Valor a devolver si la clave no existe.
    /// @return {Any} El valor encontrado o el valor por defecto.
    static Get = function(_key, _default=undefined)
    {
        if (struct_exists(data, _key) )
        {
            return data[$ _key];
        }
		
        return _default;
    }
    
    /// @desc Comprueba si una clave existe en el almacén de datos.
    /// @param {String} key La clave a comprobar.
    /// @return {Bool} Devuelve 'true' si la clave existe.
    static Exists = function(_key)
    {
        return struct_exists(data, _key);
    }
    
    /// @desc Elimina una clave y su valor asociado del almacén de datos.
    /// @param {String} key La clave a eliminar.
    /// @return {Any} Devuelve el valor que fue eliminado, o 'undefined' si no existía.
    static Remove = function(_key)
    {
        if (struct_exists(data, _key) )
        {
            return struct_remove(data, _key);
        }
		
        return undefined;
    }
    
    /// @desc Elimina un archivo del disco.
    /// @param {string} path La ruta completa del archivo a eliminar.
    /// @return {Bool} Devuelve 'true' si el archivo fue eliminado.
    static DeleteFile = function(_path)
    {
		if (__CYG_USE_BACKUPS)
		{
			var _backup_path = _path + ".bak";
			if (file_exists(_backup_path) ) file_delete(_backup_path);
		}

        if (file_exists(_path) ) 
		{
			file_delete(_path); 
			
			return true;
		}

		return false;
    }
	
	static Cleanup = function()
	{
	    static_get(Cyg).data = 
		{
	        __CygVersion: __CYG_VERSION,
	        __FileVersion: -1,
	    };
	}
}

// Inicializa las variables estáticas del sistema Cyg.
script_execute(Cyg);