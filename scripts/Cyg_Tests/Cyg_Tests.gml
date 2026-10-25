/// @desc Test suite for Cyg, exercised through the Crispy framework.

/// @ignore
function __cyg_reset_state()
{
	Cyg.Cleanup();
	Cyg.SetEncryptKey("");
	Cyg.SetVersion(-1);
}

/// @ignore
/// @desc Builds the save-file path used by a test.
/// @param {String} name File name to use.
/// @return {String} Path handed to Cyg.Export and Cyg.Import.
function __cyg_test_file(_name)
{
	return Cyg.__ResolvePath(_name);
}

/// @ignore
/// @desc Checks a save file the way the synchronous file functions see it.
/// @param {String} path Path handed to Cyg.Export, Cyg.Import or Cyg.Delete.
/// @return {Bool} Whether the file exists on disk.
function __cyg_test_file_exists(_path)
{
	return file_exists(Cyg.__ResolveSyncPath(_path) );
}

/// @ignore
/// @desc Deletes a test save file together with every backup it owns.
/// @param {String} path Save-file path to clean up.
function __cyg_delete_test_files(_path)
{
	var _sync_path = Cyg.__ResolveSyncPath(_path);
	if (is_undefined(_sync_path) ) return;

	var _backups = Cyg.__GetBackupPaths(_sync_path);
	for (var i = 0; i < array_length(_backups); i++)
	{
		if (file_exists(_backups[i]) ) file_delete(_backups[i]);
	}

	if (file_exists(_sync_path) ) file_delete(_sync_path);
}

/// @ignore
/// @desc Returns the newest backup path of a test save file.
/// @param {String} path Save-file path to inspect.
/// @return {String|Undefined} Newest backup path, or undefined when none exists.
function __cyg_find_latest_backup(_path)
{
	return Cyg.__FindLatestBackupPath(Cyg.__ResolveSyncPath(_path) );
}

/// @ignore
/// @desc Writes a text file, used to seed hand-made save files.
/// @param {String} path File to write.
/// @param {String} text Contents to write.
function __cyg_write_text_file(_path, _text)
{
	var _f = file_text_open_write(_path);
	file_text_write_string(_f, _text);
	file_text_close(_f);
}

/// @ignore
/// @desc Appends text to a file, used to corrupt a save file on purpose.
/// @param {String} path File to append to.
/// @param {String} text Contents to append.
function __cyg_append_text_file(_path, _text)
{
	var _f = file_text_open_append(_path);
	file_text_write_string(_f, _text);
	file_text_close(_f);
}

/// @ignore
/// @desc Expands a text key into the 32-byte array Cyg expects.
/// @param {String} text_key Source text, repeated until 32 bytes are filled.
/// @return {Array<Real>} 32 bytes of key material.
function __cyg_encode_key_array(_text_key)
{
	var _arr = array_create(32, 0);
	var _len = string_byte_length(_text_key);

	for (var i = 0; i < 32; i++)
	{
		_arr[i] = string_byte_at(_text_key, (i mod _len) + 1);
	}

	return _arr;
}

/// @ignore
/// @desc Registers the core and file-operation test suites.
/// @param {Struct.CrispyRunner} runner Runner receiving the suites.
function __cyg_test_core(_runner)
{
	var _suite_core = new CrispySuite("cyg_01_core_basics_suite");
	_runner.AddTestSuite(_suite_core);
	_runner.Discover(_suite_core, "test_cyg_01_core_");

	var _suite_files = new CrispySuite("cyg_02_file_ops_suite");
	_runner.AddTestSuite(_suite_files);
	_runner.Discover(_suite_files, "test_cyg_02_file_");
}

/// @ignore
/// @desc Registers the asynchronous save/load test suites.
/// @param {Struct.CrispyRunner} runner Runner receiving the suites.
function __cyg_test_async_io(_runner)
{
	var _suite_full_store = new CrispySuite("cyg_03_async_full_store_suite");
	_runner.AddTestSuite(_suite_full_store);
	_runner.Discover(_suite_full_store, "test_cyg_03_async_full_store_");

	var _suite_encrypted = new CrispySuite("cyg_04_async_encrypted_roundtrip_suite");
	_runner.AddTestSuite(_suite_encrypted);
	_runner.Discover(_suite_encrypted, "test_cyg_04_async_encrypted_roundtrip_");

	var _suite_array_key = new CrispySuite("cyg_05_async_array_key_suite");
	_runner.AddTestSuite(_suite_array_key);
	_runner.Discover(_suite_array_key, "test_cyg_05_async_array_key_");

	var _suite_wrong_key = new CrispySuite("cyg_06_async_wrong_key_suite");
	_runner.AddTestSuite(_suite_wrong_key);
	_runner.Discover(_suite_wrong_key, "test_cyg_06_async_wrong_key_");

	var _suite_empty_key = new CrispySuite("cyg_07_async_empty_key_suite");
	_runner.AddTestSuite(_suite_empty_key);
	_runner.Discover(_suite_empty_key, "test_cyg_07_async_empty_key_");

	var _suite_integrity = new CrispySuite("cyg_08_async_integrity_suite");
	_runner.AddTestSuite(_suite_integrity);
	_runner.Discover(_suite_integrity, "test_cyg_08_async_integrity_");
}

/// @ignore
/// @desc Registers the backup, restore and version-fixer test suites.
/// @param {Struct.CrispyRunner} runner Runner receiving the suites.
function __cyg_test_storage_resilience(_runner)
{
	var _suite_backup_restore = new CrispySuite("cyg_09_resilience_backup_restore_suite");
	_runner.AddTestSuite(_suite_backup_restore);
	_runner.Discover(_suite_backup_restore, "test_cyg_09_resilience_backup_restore_");

	var _suite_version_fixer = new CrispySuite("cyg_10_resilience_version_fixer_suite");
	_runner.AddTestSuite(_suite_version_fixer);
	_runner.Discover(_suite_version_fixer, "test_cyg_10_resilience_version_fixer_");
}

/// @ignore
/// @desc Registers the path-validation test suite.
/// @param {Struct.CrispyRunner} runner Runner receiving the suite.
function __cyg_test_path_validation(_runner)
{
	var _suite_paths = new CrispySuite("cyg_11_path_validation_suite");
	_runner.AddTestSuite(_suite_paths);
	_runner.Discover(_suite_paths, "test_cyg_11_path_validation_");
}

/// @ignore
/// @desc Registers the path-resolution test suite, which pins the contract for the current
/// sandbox mode of the build.
/// @param {Struct.CrispyRunner} runner Runner receiving the suite.
function __cyg_test_path_modes(_runner)
{
	var _suite_modes = new CrispySuite("cyg_12_path_modes_suite");
	_runner.AddTestSuite(_suite_modes);
	_runner.Discover(_suite_modes, "test_cyg_12_path_modes_");
}

/// @ignore
function test_cyg_12_path_modes_async_path_keeps_the_name()
{
	AssertEqual(Cyg.__ResolvePath("slot.dat"), "slot.dat", "The async file functions get the name as given");
	AssertIsUndefined(Cyg.__ResolvePath(""), "An empty path is rejected for the async file functions");
}

/// @ignore
function test_cyg_12_path_modes_sync_path_adds_the_default_folder()
{
	// buffer_save_async() stores a relative name under game_save_id/default, and no other file
	// function adds that folder on its own.
	var _expected = (GM_is_sandboxed)
		? "default/slot.dat"
		: Cyg.__ResolvePath(game_save_id) + "default/slot.dat";

	// fixpath joins game_save_id as reported by the runner, so compare with one separator style.
	AssertEqual(
		string_replace_all(Cyg.__ResolveSyncPath("slot.dat"), "\\", "/"),
		_expected,
		"The synchronous file functions get the default folder"
	);
	AssertIsUndefined(Cyg.__ResolveSyncPath(""), "An empty path is rejected for the synchronous file functions");
}

/// @ignore
function test_cyg_12_path_modes_absolute_path_skips_the_default_folder()
{
	var _absolute = "C:/Saves/slot.dat";
	AssertEqual(Cyg.__ResolveSyncPath(_absolute), _absolute, "An absolute path never gets the default folder");
}

/// @ignore
function test_cyg_01_core_add_and_get_struct()
{
	__cyg_reset_state();

	var _player = {
		name: "Player1",
		hp: 100,
		inventory: ["sword", "potion"],
	};

	Cyg.Set("player", _player);

	var _retrieved = Cyg.Get("player");

	AssertIsNotUndefined(_retrieved, "stored player data should be defined");
	AssertDeepEqual(_retrieved, _player, "Get should return the same struct that was stored");
}

/// @ignore
function test_cyg_01_core_get_default_and_overwrite()
{
	__cyg_reset_state();

	Cyg.Set("slot", 1);
	Cyg.Set("slot", 2);

	AssertEqual(Cyg.Get("slot"), 2, "Set should overwrite an existing key");
	AssertEqual(
		Cyg.Get("missing_key", "fallback"),
		"fallback",
		"Get should return the provided default for missing keys"
	);
}

/// @ignore
function test_cyg_01_core_exists_remove_and_cleanup()
{
	__cyg_reset_state();

	Cyg.Set("temporary", { score: 5000 });
	Cyg.Set("persistent", true);

	AssertTrue(Cyg.Exists("temporary"), "Exists should report a stored key");
	Cyg.Remove("temporary");
	AssertFalse(Cyg.Exists("temporary"), "Remove should delete an existing key");

	Cyg.Cleanup();
	AssertFalse(Cyg.Exists("persistent"), "Cleanup should clear previously stored keys");
	AssertEqual(Cyg.Get("persistent", "missing"), "missing", "Cleanup should restore missing-key behavior");
}

/// @ignore
function test_cyg_01_core_remove_returns_expected_values()
{
	__cyg_reset_state();

	Cyg.Set("coins", 25);

	var _removed_existing = Cyg.Remove("coins");
	var _removed_missing = Cyg.Remove("coins");

	AssertEqual(_removed_existing, 25, "Remove should return the previous value when key exists");
	AssertIsUndefined(_removed_missing, "Remove should return undefined for missing key");
}

/// @ignore
function test_cyg_01_core_cleanup_resets_metadata()
{
	__cyg_reset_state();

	Cyg.SetVersion(9);
	Cyg.Set("temp_key", true);
	Cyg.Cleanup();

	AssertFalse(Cyg.Exists("temp_key"), "Cleanup should remove user data keys");
	AssertEqual(Cyg.Get("__file_version"), -1, "Cleanup should reset __file_version to -1");
	AssertIsNotUndefined(Cyg.Get("__cyg_version", undefined), "Cleanup should keep internal __cyg_version metadata");
}

/// @ignore
function test_cyg_02_file_delete_removes_save_and_backup()
{
	__cyg_reset_state();

	var _path = __cyg_test_file("cyg_delete_file.dat");
	__cyg_delete_test_files(_path);

	// The synchronous helpers see the file through Cyg.__ResolveSyncPath(), not the path handed
	// to the async buffer functions.
	var _sync_path = Cyg.__ResolveSyncPath(_path);
	__cyg_write_text_file(_sync_path, "primary");
	var _backup_path = string(CYG_BACKUP_FILENAME_FORMAT, _sync_path, "test");
	__cyg_write_text_file(_backup_path, "backup");

	var _deleted = Cyg.Delete(_path);

	AssertTrue(_deleted, "Delete should return true when primary file exists");
	AssertFalse(file_exists(_sync_path), "Delete should delete primary file");
	AssertFalse(file_exists(_backup_path), "Delete should delete backup file when backups are enabled");
}

/// @ignore
function test_cyg_02_file_delete_returns_false_when_missing()
{
	__cyg_reset_state();

	var _path = __cyg_test_file("cyg_delete_missing.dat");
	__cyg_delete_test_files(_path);

	var _deleted = Cyg.Delete(_path);

	AssertFalse(_deleted, "Delete should return false when primary file does not exist");
}

/// @ignore
function test_cyg_02_file_restorebackup_returns_false_without_backup()
{
	__cyg_reset_state();

	var _path = __cyg_test_file("cyg_restore_missing.dat");
	__cyg_delete_test_files(_path);

	var _restored = Cyg.RestoreBackup(_path);

	AssertFalse(_restored, "RestoreBackup should return false when backup file is missing");
}

/// @ignore
function test_cyg_03_async_full_store_roundtrip_async()
{
	__cyg_reset_state();

	var _v = crispy_vars();
	_v.cyg_async_full_store = {
		path: __cyg_test_file("cyg_full_store_roundtrip.dat"),
		export_started: false,
		export_done: false,
		export_success: false,
		import_started: false,
		import_done: false,
		import_success: false,
	};
	__cyg_delete_test_files(_v.cyg_async_full_store.path);

	Cyg.SetVersion(7);
	Cyg.Set("player", { name: "FullSaveHero", hp: 77 });
	Cyg.Set("world", { chapter: 3 });

	WaitStep(function() {
		var _s = crispy_vars().cyg_async_full_store;
		if (!_s.export_started)
		{
			Cyg.Export(_s.path, undefined, false, function(_success) {
				var _st = crispy_vars().cyg_async_full_store;
				_st.export_done = true;
				_st.export_success = _success;
			});
			_s.export_started = true;
			return false;
		}

		return _s.export_done;
	})
	.WaitEndStep(function() {
		var _s = crispy_vars().cyg_async_full_store;
		AssertTrue(_s.export_success, "Full-store export should succeed");
		AssertTrue(__cyg_test_file_exists(_s.path), "Full-store export should create the target file");

		Cyg.Cleanup();
		AssertFalse(Cyg.Exists("player"), "Cleanup should clear player before full-store import");
		return true;
	})
	.WaitStep(function() {
		var _s = crispy_vars().cyg_async_full_store;
		if (!_s.import_started)
		{
			Cyg.Import(_s.path, undefined, false, function(_success, _data) {
				var _st = crispy_vars().cyg_async_full_store;
				_st.import_done = true;
				_st.import_success = _success;
			});
			_s.import_started = true;
			return false;
		}

		return _s.import_done;
	})
	.WaitEndStep(function() {
		var _s = crispy_vars().cyg_async_full_store;
		AssertTrue(_s.import_success, "Full-store import should succeed");
		AssertEqual(Cyg.Get("player").name, "FullSaveHero", "Import without key should restore player data");
		AssertEqual(Cyg.Get("world").chapter, 3, "Import without key should restore world data");
		AssertEqual(Cyg.Get("__file_version"), 7, "Import without key should restore __file_version metadata");

		__cyg_delete_test_files(_s.path);
		__cyg_reset_state();
		return true;
	})
	.Timeout(180, "frames");
}

/// @ignore
function test_cyg_04_async_encrypted_roundtrip_async()
{
	__cyg_reset_state();
	__cyg_assert_sync_encryption_roundtrip();

	var _v = crispy_vars();
	_v.cyg_async_export_import = {
		path: __cyg_test_file("cyg_async_encrypted.dat"),
		export_started: false,
		export_done: false,
		export_success: false,
		import_started: false,
		import_done: false,
		import_success: false,
		import_data: undefined,
	};
	__cyg_delete_test_files(_v.cyg_async_export_import.path);

	WaitStep(function() {
		var _s = crispy_vars().cyg_async_export_import;
		if (!_s.export_started)
		{
			Cyg.SetEncryptKey(__cyg_encode_key_array("async_key") );
			Cyg.Set("game_settings", { difficulty: "hard", volume: 0.75 });
			Cyg.Export(_s.path, "game_settings", true, function(_success) {
				var _st = crispy_vars().cyg_async_export_import;
				_st.export_done = true;
				_st.export_success = _success;
			});
			_s.export_started = true;
			return false;
		}

		return _s.export_done;
	})
	.WaitEndStep(function() {
		var _s = crispy_vars().cyg_async_export_import;
		AssertTrue(_s.export_success, "Export callback should report success");
		AssertTrue(__cyg_test_file_exists(_s.path), "Encrypted export should create the target save file");
		return true;
	})
	.WaitStep(function() {
		var _s = crispy_vars().cyg_async_export_import;
		if (!_s.import_started)
		{
			Cyg.Remove("game_settings");
			Cyg.Import(_s.path, "game_settings", true, function(_success, _data) {
				var _st = crispy_vars().cyg_async_export_import;
				_st.import_done = true;
				_st.import_success = _success;
				_st.import_data = _data;
			});
			_s.import_started = true;
			return false;
		}

		return _s.import_done;
	})
	.WaitEndStep(function() {
		var _s = crispy_vars().cyg_async_export_import;
		AssertTrue(_s.import_success, "Import callback should report success");
		AssertIsNotUndefined(_s.import_data, "Import callback should provide data");

		if (is_struct(_s.import_data) && struct_exists(_s.import_data, "difficulty") )
		{
			AssertEqual(_s.import_data.difficulty, "hard", "Imported data should preserve field values");
		}
		else
		{
			AssertTrue(false, "Imported data should contain the 'difficulty' field");
		}

		AssertDeepEqual(
			Cyg.Get("game_settings"),
			_s.import_data,
			"Import with a key should store the imported data in Cyg"
		);
		__cyg_delete_test_files(_s.path);
		__cyg_reset_state();
		return true;
	})
	.Timeout(180, "frames");
}

/// @ignore
/// @desc Asserts the synchronous encryption round trip before the async case runs.
function __cyg_assert_sync_encryption_roundtrip()
{
	var _plain = buffer_create(5, buffer_fixed, 1);
	buffer_write(_plain, buffer_string, "test");
	buffer_seek(_plain, buffer_seek_start, 0);

	var _key = __cyg_encode_key_array("async_key");
	var _packed = Cyg.__ChaChaEncryptPacked(_plain, _key);
	var _decrypted = Cyg.__ChaChaDecryptPacked(_packed, _key);

	AssertIsNotUndefined(_decrypted, "Synchronous Cyg encryption round trip should succeed");

	if (buffer_exists(_decrypted) ) buffer_delete(_decrypted);
	if (buffer_exists(_packed) ) buffer_delete(_packed);
	buffer_delete(_plain);

	Cyg.SetEncryptKey(_key);
	Cyg.Set("__cyg_sync_roundtrip", { value: 1 });
	var _export_buffer = Cyg.__BuildExportBuffer("__cyg_sync_roundtrip", true, false);
	var _result = Cyg.__ProcessImportBuffer(_export_buffer, "sync", "__cyg_sync_roundtrip", true, false, _key);
	AssertTrue(_result.success, "Synchronous Cyg export/import buffer processing should succeed");
	if (buffer_exists(_export_buffer) ) buffer_delete(_export_buffer);
	Cyg.Remove("__cyg_sync_roundtrip");
}

/// @ignore
function test_cyg_05_async_array_key_roundtrip_async()
{
	__cyg_reset_state();

	var _v = crispy_vars();
	_v.cyg_async_array_key = {
		path: __cyg_test_file("cyg_async_array_key.dat"),
		export_started: false,
		export_done: false,
		export_success: false,
		import_started: false,
		import_done: false,
		import_success: false,
		import_data: undefined,
		encoded_key: __cyg_encode_key_array("array_key_test"),
	};
	__cyg_delete_test_files(_v.cyg_async_array_key.path);

	WaitStep(function() {
		var _s = crispy_vars().cyg_async_array_key;
		if (!_s.export_started)
		{
			Cyg.SetEncryptKey(_s.encoded_key);
			Cyg.Set("array_key_payload", { value: 404 });
			Cyg.Export(_s.path, "array_key_payload", true, function(_success) {
				var _st = crispy_vars().cyg_async_array_key;
				_st.export_done = true;
				_st.export_success = _success;
			});
			_s.export_started = true;
			return false;
		}

		return _s.export_done;
	})
	.WaitEndStep(function() {
		var _s = crispy_vars().cyg_async_array_key;
		AssertTrue(_s.export_success, "Encrypted export with array key should succeed");
		return true;
	})
	.WaitStep(function() {
		var _s = crispy_vars().cyg_async_array_key;
		if (!_s.import_started)
		{
			Cyg.Remove("array_key_payload");
			Cyg.SetEncryptKey(_s.encoded_key);
			Cyg.Import(_s.path, "array_key_payload", true, function(_success, _data) {
				var _st = crispy_vars().cyg_async_array_key;
				_st.import_done = true;
				_st.import_success = _success;
				_st.import_data = _data;
			});
			_s.import_started = true;
			return false;
		}

		return _s.import_done;
	})
	.WaitEndStep(function() {
		var _s = crispy_vars().cyg_async_array_key;
		AssertTrue(_s.import_success, "Encrypted import with array key should succeed");
		if (is_struct(_s.import_data) && struct_exists(_s.import_data, "value") )
		{
			AssertEqual(_s.import_data.value, 404, "Decoded array key should restore original payload");
		}
		else
		{
			AssertTrue(false, "Array-key import payload should contain 'value'");
		}

		__cyg_delete_test_files(_s.path);
		__cyg_reset_state();
		return true;
	})
	.Timeout(180, "frames");
}

/// @ignore
function test_cyg_06_async_wrong_key_fails_async()
{
	__cyg_reset_state();

	var _v = crispy_vars();
	_v.cyg_async_wrong_key = {
		path: __cyg_test_file("cyg_async_wrong_key.dat"),
		export_started: false,
		export_done: false,
		export_success: false,
		import_started: false,
		import_done: false,
		import_success: true,
		import_data: "sentinel",
	};
	__cyg_delete_test_files(_v.cyg_async_wrong_key.path);

	WaitStep(function() {
		var _s = crispy_vars().cyg_async_wrong_key;
		if (!_s.export_started)
		{
			Cyg.SetEncryptKey(__cyg_encode_key_array("correct_key") );
			Cyg.Set("secure_data", { rank: 9 });
			Cyg.Export(_s.path, "secure_data", true, function(_success) {
				var _st = crispy_vars().cyg_async_wrong_key;
				_st.export_done = true;
				_st.export_success = _success;
			});
			_s.export_started = true;
			return false;
		}

		return _s.export_done;
	})
	.WaitEndStep(function() {
		var _s = crispy_vars().cyg_async_wrong_key;
		AssertTrue(_s.export_success, "Precondition export should succeed before wrong-key import");
		return true;
	})
	.WaitStep(function() {
		var _s = crispy_vars().cyg_async_wrong_key;
		if (!_s.import_started)
		{
			Cyg.SetEncryptKey(__cyg_encode_key_array("wrong_key") );
			Cyg.Import(_s.path, "secure_data", true, function(_success, _data) {
				var _st = crispy_vars().cyg_async_wrong_key;
				_st.import_done = true;
				_st.import_success = _success;
				_st.import_data = _data;
			});
			_s.import_started = true;
			return false;
		}

		return _s.import_done;
	})
	.WaitEndStep(function() {
		var _s = crispy_vars().cyg_async_wrong_key;
		AssertFalse(_s.import_success, "Import should fail when decrypting with a wrong key");
		AssertIsUndefined(_s.import_data, "Wrong-key import should return undefined data");

		__cyg_delete_test_files(_s.path);
		__cyg_reset_state();
		return true;
	})
	.Timeout(180, "frames");
}

/// @ignore
function test_cyg_07_async_empty_key_fails_async()
{
	__cyg_reset_state();

	var _v = crispy_vars();
	_v.cyg_async_empty_key = {
		path: __cyg_test_file("cyg_async_empty_key.dat"),
		export_started: false,
		export_done: false,
		export_success: false,
		import_started: false,
		import_done: false,
		import_success: true,
		import_data: "sentinel",
	};
	__cyg_delete_test_files(_v.cyg_async_empty_key.path);

	WaitStep(function() {
		var _s = crispy_vars().cyg_async_empty_key;
		if (!_s.export_started)
		{
			Cyg.SetEncryptKey(__cyg_encode_key_array("non_empty_key") );
			Cyg.Set("empty_key_payload", { id: 12 });
			Cyg.Export(_s.path, "empty_key_payload", true, function(_success) {
				var _st = crispy_vars().cyg_async_empty_key;
				_st.export_done = true;
				_st.export_success = _success;
			});
			_s.export_started = true;
			return false;
		}

		return _s.export_done;
	})
	.WaitEndStep(function() {
		var _s = crispy_vars().cyg_async_empty_key;
		AssertTrue(_s.export_success, "Precondition export should succeed before empty-key import");
		return true;
	})
	.WaitStep(function() {
		var _s = crispy_vars().cyg_async_empty_key;
		if (!_s.import_started)
		{
			Cyg.SetEncryptKey("");
			Cyg.Import(_s.path, "empty_key_payload", true, function(_success, _data) {
				var _st = crispy_vars().cyg_async_empty_key;
				_st.import_done = true;
				_st.import_success = _success;
				_st.import_data = _data;
			});
			_s.import_started = true;
			return false;
		}

		return _s.import_done;
	})
	.WaitEndStep(function() {
		var _s = crispy_vars().cyg_async_empty_key;
		AssertFalse(_s.import_success, "Import should fail when decrypting with an empty key");
		AssertIsUndefined(_s.import_data, "Empty-key import should return undefined data");

		__cyg_delete_test_files(_s.path);
		__cyg_reset_state();
		return true;
	})
	.Timeout(180, "frames");
}

/// @ignore
function test_cyg_08_async_integrity_checksum_failure_async()
{
	__cyg_reset_state();

	var _v = crispy_vars();
	_v.cyg_async_integrity = {
		path: __cyg_test_file("cyg_integrity_checksum.dat"),
		export_started: false,
		export_done: false,
		export_success: false,
		import_started: false,
		import_done: false,
		import_success: true,
		import_data: "sentinel",
	};
	__cyg_delete_test_files(_v.cyg_async_integrity.path);

	WaitStep(function() {
		var _s = crispy_vars().cyg_async_integrity;
		if (!_s.export_started)
		{
			Cyg.Set("integrity_payload", { hp: 10 });
			Cyg.Export(_s.path, "integrity_payload", false, function(_success) {
				var _st = crispy_vars().cyg_async_integrity;
				_st.export_done = true;
				_st.export_success = _success;
			});
			_s.export_started = true;
			return false;
		}

		return _s.export_done;
	})
	.WaitEndStep(function() {
		var _s = crispy_vars().cyg_async_integrity;
		AssertTrue(_s.export_success, "Precondition export should succeed before integrity tampering");
		__cyg_append_text_file(Cyg.__ResolveSyncPath(_s.path), "_tampered");
		return true;
	})
	.WaitStep(function() {
		var _s = crispy_vars().cyg_async_integrity;
		if (!_s.import_started)
		{
			Cyg.Remove("integrity_payload");
			Cyg.Import(_s.path, "integrity_payload", false, function(_success, _data) {
				var _st = crispy_vars().cyg_async_integrity;
				_st.import_done = true;
				_st.import_success = _success;
				_st.import_data = _data;
			});
			_s.import_started = true;
			return false;
		}

		return _s.import_done;
	})
	.WaitEndStep(function() {
		var _s = crispy_vars().cyg_async_integrity;
		AssertFalse(_s.import_success, "Import should fail when checksum validation fails");
		AssertIsUndefined(_s.import_data, "Checksum-failed import should return undefined data");
		AssertFalse(Cyg.Exists("integrity_payload"), "Checksum-failed import should not write data into Cyg");

		__cyg_delete_test_files(_s.path);
		__cyg_reset_state();
		return true;
	})
	.Timeout(180, "frames");
}

/// @ignore
function test_cyg_09_resilience_backup_restore_async()
{
	__cyg_reset_state();
	var _v = crispy_vars();
	_v.cyg_resilience_backup = {
		path: __cyg_test_file("cyg_backup_restore.dat"),
		first_export_started: false,
		first_export_done: false,
		first_export_success: false,
		second_export_started: false,
		second_export_done: false,
		second_export_success: false,
		import_started: false,
		import_done: false,
		import_success: false,
		import_data: undefined,
	};
	__cyg_delete_test_files(_v.cyg_resilience_backup.path);

	WaitStep(function() {
		var _s = crispy_vars().cyg_resilience_backup;
		if (!_s.first_export_started)
		{
			Cyg.Set("slot", { round: 1 });
			Cyg.Export(_s.path, "slot", false, function(_success) {
				var _st = crispy_vars().cyg_resilience_backup;
				_st.first_export_done = true;
				_st.first_export_success = _success;
			});
			_s.first_export_started = true;
			return false;
		}

		return _s.first_export_done;
	})
	.WaitEndStep(function() {
		var _s = crispy_vars().cyg_resilience_backup;
		AssertTrue(_s.first_export_success, "First export should succeed before backup creation is tested");

		// Seed older backups so the pruning limit can be observed on the next save.
		var _sync_path = Cyg.__ResolveSyncPath(_s.path);
		__cyg_write_text_file(string(CYG_BACKUP_FILENAME_FORMAT, _sync_path, "20000101_000000"), "old-a");
		__cyg_write_text_file(string(CYG_BACKUP_FILENAME_FORMAT, _sync_path, "20000102_000000"), "old-b");
		return true;
	})
	.WaitStep(function() {
		var _s = crispy_vars().cyg_resilience_backup;
		if (!_s.second_export_started)
		{
			Cyg.Set("slot", { round: 2 });
			Cyg.Export(_s.path, "slot", false, function(_success) {
				var _st = crispy_vars().cyg_resilience_backup;
				_st.second_export_done = true;
				_st.second_export_success = _success;
			});
			_s.second_export_started = true;
			return false;
		}

		return _s.second_export_done;
	})
	.WaitEndStep(function() {
		var _s = crispy_vars().cyg_resilience_backup;
		AssertTrue(_s.second_export_success, "Second export should succeed when overwriting a save file");

		var _backups = Cyg.__GetBackupPaths(Cyg.__ResolveSyncPath(_s.path));
		AssertEqual(
			array_length(_backups),
			CYG_BACKUP_MAX_COUNT,
			"Pruning should keep at most CYG_BACKUP_MAX_COUNT backups"
		);

		var _latest_backup = __cyg_find_latest_backup(_s.path);
		AssertIsNotUndefined(_latest_backup, "Overwriting a save should create a backup file");
		AssertTrue(file_exists(_latest_backup), "Latest backup path should exist on disk");

		AssertTrue(Cyg.RestoreBackup(_s.path), "RestoreBackup should restore the previous save from backup");
		AssertFalse(file_exists(_latest_backup), "Selected backup file should be consumed during restoration");
		return true;
	})
	.WaitStep(function() {
		var _s = crispy_vars().cyg_resilience_backup;
		if (!_s.import_started)
		{
			Cyg.Remove("slot");
			Cyg.Import(_s.path, "slot", false, function(_success, _data) {
				var _st = crispy_vars().cyg_resilience_backup;
				_st.import_done = true;
				_st.import_success = _success;
				_st.import_data = _data;
			});
			_s.import_started = true;
			return false;
		}

		return _s.import_done;
	})
	.WaitEndStep(function() {
		var _s = crispy_vars().cyg_resilience_backup;
		AssertTrue(_s.import_success, "Restored save should be importable");

		if (is_struct(_s.import_data) && struct_exists(_s.import_data, "round") )
		{
			AssertEqual(_s.import_data.round, 1, "RestoreBackup should recover the previous file contents");
		}
		else
		{
			AssertTrue(false, "Restored data should contain the 'round' field");
		}

		__cyg_delete_test_files(_s.path);
		__cyg_reset_state();
		return true;
	})
	.Timeout(240, "frames");
}

/// @ignore
function test_cyg_10_resilience_version_fixer_async()
{
	__cyg_reset_state();
	var _v = crispy_vars();
	_v.cyg_resilience_fixer = {
		path: __cyg_test_file("cyg_version_fixer.dat"),
		export_started: false,
		export_done: false,
		export_success: false,
		import_started: false,
		import_done: false,
		import_success: false,
		import_data: undefined,
	};
	__cyg_delete_test_files(_v.cyg_resilience_fixer.path);

	WaitStep(function() {
		var _s = crispy_vars().cyg_resilience_fixer;
		if (!_s.export_started)
		{
			Cyg.SetVersion(1);
			Cyg.Set("legacy_player", { name: "Old Hero" });
			Cyg.Export(_s.path, "legacy_player", false, function(_success) {
				var _st = crispy_vars().cyg_resilience_fixer;
				_st.export_done = true;
				_st.export_success = _success;
			});
			_s.export_started = true;
			return false;
		}

		return _s.export_done;
	})
	.WaitEndStep(function() {
		var _s = crispy_vars().cyg_resilience_fixer;
		AssertTrue(_s.export_success, "Legacy export should succeed before migration is tested");
		return true;
	})
	.WaitStep(function() {
		var _s = crispy_vars().cyg_resilience_fixer;
		if (!_s.import_started)
		{
			Cyg.Cleanup();
			Cyg.SetVersion(2);
			Cyg.AddFixer(1, function(_save) {
				if (is_struct(_save) && !struct_exists(_save, "hp") )
				{
					_save.hp = 100;
				}
				return _save;
			});
			Cyg.Import(_s.path, "legacy_player", false, function(_success, _data) {
				var _st = crispy_vars().cyg_resilience_fixer;
				_st.import_done = true;
				_st.import_success = _success;
				_st.import_data = _data;
			});
			_s.import_started = true;
			return false;
		}

		return _s.import_done;
	})
	.WaitEndStep(function() {
		var _s = crispy_vars().cyg_resilience_fixer;
		AssertTrue(_s.import_success, "Import should succeed for legacy save data");

		if (is_struct(_s.import_data) )
		{
			if (struct_exists(_s.import_data, "name") )
			{
				AssertEqual(_s.import_data.name, "Old Hero", "Fixers should preserve existing fields");
			}
			else
			{
				AssertTrue(false, "Migrated data should contain the 'name' field");
			}

			if (struct_exists(_s.import_data, "hp") )
			{
				AssertEqual(_s.import_data.hp, 100, "Fixers should migrate older save data to the new schema");
			}
			else
			{
				AssertTrue(false, "Migrated data should contain the 'hp' field");
			}
		}
		else
		{
			AssertTrue(false, "Import callback should return a struct for migrated data");
		}

		var _stored = Cyg.Get("legacy_player", undefined);
		if (is_struct(_stored) && struct_exists(_stored, "hp") )
		{
			AssertEqual(_stored.hp, 100, "Migrated data should be stored back into Cyg under the requested key");
		}
		else
		{
			AssertTrue(false, "Stored migrated data should contain the 'hp' field");
		}

		__cyg_delete_test_files(_s.path);
		__cyg_reset_state();
		return true;
	})
	.Timeout(180, "frames");
}

/// @ignore
function test_cyg_11_path_validation_export_rejects_empty_path_sync()
{
	__cyg_reset_state();

	var _v = crispy_vars();
	_v.cyg_path_validation_export = {
		called: false,
		success: true,
	};

	Cyg.Export("", undefined, false, function(_ok) {
		var _st = crispy_vars().cyg_path_validation_export;
		_st.called = true;
		_st.success = _ok;
	});

	AssertTrue(_v.cyg_path_validation_export.called, "Export should invoke callback when path validation fails");
	AssertFalse(_v.cyg_path_validation_export.success, "Export should report false on invalid path");
}

/// @ignore
function test_cyg_11_path_validation_import_rejects_url_like_path_sync()
{
	__cyg_reset_state();

	var _v = crispy_vars();
	_v.cyg_path_validation_import = {
		called: false,
		success: true,
		data: "sentinel",
	};

	Cyg.Import("https://example.com/save.dat", "payload", false, function(_ok, _out) {
		var _st = crispy_vars().cyg_path_validation_import;
		_st.called = true;
		_st.success = _ok;
		_st.data = _out;
	});

	AssertTrue(_v.cyg_path_validation_import.called, "Import should invoke callback when path validation fails");
	AssertFalse(_v.cyg_path_validation_import.success, "Import should report false on invalid path");
	AssertIsUndefined(_v.cyg_path_validation_import.data, "Import should return undefined data on invalid path");
}
