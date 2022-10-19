/// @ignore
function CygManager(_defaultName) constructor
{
	static data  = {};
	static index =  0;		// indice de guardado
	static encryptKey = "";	// LLave de cifrado
	
	/// @ignore
	filename = _defaultName;
	
	/// @desc Guarda los archivos a un buffer
	static save = function(_filename=filename)
	{
		var _string = json_stringify(data);	// Pasar a json los datos
		var _buffer = buffer_create(string_byte_length(_string) + 1, buffer_fixed, 1);
		buffer_write(_buffer, buffer_string, _string);
		buffer_save(_buffer, _filename);
		buffer_delete(_buffer);
	}
	
	/// @desc Carga los archivos desde un buffer. Si el archivo existe True
	static load = function(_filename=filename)
	{
		// Si no existe devolver false
		if (!file_exists(_filename) ) return false;
		var _buffer = buffer_load(_filename);
		var _string = buffer_read(_buffer, buffer_string);

		buffer_delete(_buffer);
		// Cargar datos
		data = json_parse(_string);
		
		return true;
	}
	
	/// @desc Guarda la informacion y la encrypta
	static saveEncrypt = function(_filename=filename) 
	{
		var _string = json_stringify(data);	// Pasar a json los datos
		var _buffer = buffer_create((string_length(_string) * 2) + 2, buffer_grow, 1);
	
		for(var i = 1; i <= string_length(_string); i = i+1)
		{
			var original_value = string_byte_at(_string, i);
			var key_value = string_byte_at(encryptKey, i);
			var final_value = original_value + key_value ;
			buffer_write(_buffer, buffer_s16, final_value);
		
		}
	
		buffer_save(_buffer, _filename);
		buffer_delete(_buffer);
	}
	
	/// @desc Carga la informacion y la desencrypta
	static loadDecrypt = function(_filename=filename)
	{
		//this function reads string from file with name _filename and returns it
		var _buffer = buffer_load(_filename);
		var _string = "";
	
		for(var i=1; i < (buffer_get_size(_buffer) / 2); i = i+1)
		{
			var _char_binary = buffer_read(_buffer, buffer_s16);
			var _key_value   = string_byte_at(encryptKey, i);
		
			var _char = _char_binary - _key_value;
			_string += ansi_char(_char);
		}
	
		buffer_delete(_buffer);
		
		// Cargar datos
		data = json_decode(_string);
	}
	
	/// @desc Agrega informacion Key, Value
	static add = function() 
	{
		var i=0; repeat(argument_count div 2) {
			var _key = argument[i];
			var _val = argument[i + 1];
			
			data[$ _key] = _val;
			i = i + 2;
		}
		
		return self;
	}
	
	/// @param {String} key
	/// @param {String} value
	static set = function(_key, _value) 
	{
		data[$ _key] = _value;
		return self;
	}
	
	/// @desc Devuelve informacion
	/// @param {String} key
	/// @param {Any} [default]
	static get = function(_key, _default)
	{
		return data[$ _key] ?? _default;
	}
	
	/// @param {String} key
	/// @return {Bool}
	static exists = function(_key)
	{
		return (variable_struct_get(data, _key) );	
	}
	
	/// @param {String} key
	static remove = function(_key)
	{
		var _r = data[$ _key];
		variable_struct_remove(data, _key);
		return _r;
	}
}

/// @param {String} fileName default name for the file
/// @return {Struct.CygManager}
function cyg(_defaultName="")
{
	static t = (new CygManager(_defaultName) );
	return t;
}

#region GML-Like
function cyg_exists(_key)
{
	static t = cyg();
	return (t.exists(_key) );
}

function cyg_get(_key, _default) 
{
	static t = cyg();
	return (t.get(_key, _default) );
}

function cyg_remove(_key)
{
	static t = cyg();
	return (t.remove(_key) );
}

#endregion