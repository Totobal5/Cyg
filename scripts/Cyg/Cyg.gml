#macro __CYG_VERSION 1.2

/// @desc Sistema de guardado sencillo
function cyg()
{
	/* 
		Donde se guardan los datos data: {filename: {DATOS} }
	*/
	static data  = {};      
	static index =  0;           // Indice de guardado
	static encryptKey   =    ""; // LLave de cifrado
	static forceEncrypt = false; // Forzar cifrado en todas las versiones
	static filename   = "";      // Nombre del archivo
	static version    = -1;      // Version del archivo
	static versionFixers = {};
	
	/// @desc Crea un archivo con los datos
	/// @param {string} filenameToUse 
	/// @param {bool}   encrypt       Use encrypt Default to false
	static export = function(_filenameToUse, _encrypt=false)
	{
		// Pasar a json los datos
		var _string;
		// Guardar la version que se esta utilizando
		data[$ "__CygVersion"] = version;
		
		// usar todos los datos
		if (_filenameToUse == undefined) {
			_string = json_stringify(data, false);
		} else {
			// Seleccionar una categoria (filename)
			if (variable_struct_exists(data, _filenameToUse) ) {
				// Guardar version
				data[$ _filenameToUse][$ "__CygVersion"] = version;
				_string = json_stringify(data[$ _filenameToUse]);
			}
		}
		
		var _buffer;
		if (_encrypt) {
			// Si no existe llave de cifrado exportar sin usar esta función
			if (encryptKey == "") export(_filenameToUse, false);
			
			_buffer = buffer_create((string_length(_string) * 2) + 2, buffer_grow, 1);
			var i=0; repeat(string_length(_string) ) {
				var original_value = string_byte_at(_string, i);
				var key_value   = string_byte_at(encryptKey, i);
				var final_value = original_value + key_value ;
				buffer_write(_buffer, buffer_s16, final_value);
				i++;
			}
		} else {
			_buffer = buffer_create(string_byte_length(_string) + 1, buffer_fixed, 1);
			buffer_write(_buffer, buffer_string, _string);
		}
		
		// Guardar a disco duro
		buffer_save(_buffer , _filenameToUse);
		buffer_delete(_buffer);
	}
	
	/// @desc Carga un archivo del disco duro y lo transforma a JSON.
	/// @param {string} filenameInDisk
	/// @param {string} filenameToSet 
	/// @param {bool}   encrypt       Use encrypt Default to false
	static import = function(_filenameInDisk, _filenameToSet, _encrypt=false)
	{
		static def = function(_version, _struct) {}
		// Si no existe devolver false 
		if (!file_exists(_filenameInDisk) ) return false;
		
		var _buffer = buffer_load(_filenameInDisk), _string="";
		if (_encrypt) {
			var i=0; repeat(buffer_get_size(_buffer) / 2) {
				var _char_binary = buffer_read(_buffer, buffer_s16);
				var _key_value   = string_byte_at(encryptKey, i);
				
				var _char = _char_binary - _key_value;
				_string += ansi_char(_char);
				
				i++;
			}
		}
		else {
			_string = buffer_read(_buffer, buffer_string);
		}
		
		// Eliminar buffer
		buffer_delete(_buffer);
		
		// -- Cargar datos
		if (_filenameToSet == undefined) {
			// Carga todos los datos
			data = json_parse(_string);
		} else {
			// Añadir categoria a todos los datos (filename)
			var _str = json_parse(_string);
			var _fun = versionFixers[$ _filenameToSet] ?? def;
			// Intentar arreglar algun problema con la version
			_fun(_str[$ "__CygVersion"], _str);
			
			data[$ _filenameToSet] = _str;
		}
		
		return true;
	}

	/// @desc Agrega un filename a los datos
	/// @param {string} filename
	/// @param {string} [key]
	/// @param {any}    [value]
	/// @param [...]
	static add = function(_filename, _key, _value)
	{	
		if (_filename != undefined) {
			var _file = {};
			data[$ _filename] = _file;
			
			// Agregar datos
			var i=1, _k, _v; repeat((argument_count - 1) div 2) {
				_k = argument[i]; 
				_v = argument[i + 1];
				_file[$ _k] = _v;
				
				i = i + 2;
			}
		} 
		else {
			
			
			
		}
		return self;
	}
	
	/// @param {string,undefined} filename
	/// @param {string}           key
	/// @param {any}              value
	static set = function(_filename, _key, _value) 
	{
		// Guardar directamente
		if (_filename == undefined) {
			data[$ _key] = _value;
		} else {
			if (variable_struct_exists(data, _filename) ) {
				data[$ _filename][$ _key] = _value;
			}
		}
		return self;
	}
	
	/// @param {string} filename
	/// @param {String} key
	/// @param {Any} [defaultTo]
	static get = function(_filename, _key, _default)
	{
		var _value = undefined;
		if (_filename == undefined) {
			_value = data[$ _key];
		} else {
			if (variable_struct_exists(data, _filename) ) {
				_value = data[$ _filename][$ _key];
			}
		}
		
		return _value ?? _default;
	}
	
	/// @param {String} filename
	/// @return {Bool}
	static existsFilename = function(_key)
	{
		return (variable_struct_get(data, _key) );
	}

	/// @param {String} key
	/// @return {Bool}
	static exists = function(_filename, _key) 
	{
		return (variable_struct_get(data[$ _filename], _key) );
	}
	
	/// @param {String} filename
	/// @param {function} fixMethod function(_version, _struct) {}
	static setVersionFixer = function(_filename, _fun) {
		versionFixers[$ _filename] = _fun;
		return self;
	}

	/// @param {String} key
	static removeData = function(_key)
	{
		var _r = data[$ _key];
		variable_struct_remove(data, _key);
		return _r;
	}
	
	/// @param {string} filename
	static removeFile = function(_filename) 
	{
		if (file_exists(_filename) ) {
			file_delete(_filename);
		}	
	}
}

// Iniciar variables estaticas
cyg();