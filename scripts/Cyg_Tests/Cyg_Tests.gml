/// Test Suite for Cyg v3.0.2, using Crispy v2.2.4

/// @ignore
function __cyg_reset_state()
{
    Cyg.Cleanup();
    Cyg.SetEncryptKey("");
    Cyg.SetVersion(-1);
}

/// @ignore
function __cyg_test_file(_name)
{
    return working_directory + _name;
}

/// @ignore
function __cyg_delete_test_files(_path)
{
    if (file_exists(_path)) file_delete(_path);
    if (file_exists(_path + ".bak")) file_delete(_path + ".bak");

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

/// @ignore
function __cyg_find_latest_backup(_path)
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

/// @ignore
function __cyg_write_text_file(_path, _text)
{
    var _f = file_text_open_write(_path);
    file_text_write_string(_f, _text);
    file_text_close(_f);
}

/// @ignore
function __cyg_append_text_file(_path, _text)
{
    var _f = file_text_open_append(_path);
    file_text_write_string(_f, _text);
    file_text_close(_f);
}

/// @ignore
function __cyg_buffer_from_string(_text)
{
    var _buf = buffer_create(string_byte_length(_text) + 1, buffer_fixed, 1);
    buffer_write(_buf, buffer_string, _text);
    buffer_seek(_buf, buffer_seek_start, 0);
    return _buf;
}

/// @ignore
function __cyg_buffer_to_string(_buffer)
{
    var _old_pos = buffer_tell(_buffer);
    buffer_seek(_buffer, buffer_seek_start, 0);
    var _text = buffer_read(_buffer, buffer_string);
    buffer_seek(_buffer, buffer_seek_start, _old_pos);
    return _text;
}

/// @ignore
function __cyg_flip_first_byte(_buffer)
{
    if (!buffer_exists(_buffer) || buffer_get_size(_buffer) <= 0) return;

    var _old_pos = buffer_tell(_buffer);
    buffer_seek(_buffer, buffer_seek_start, 0);
    var _b = buffer_read(_buffer, buffer_u8);
    buffer_seek(_buffer, buffer_seek_start, 0);
    buffer_write(_buffer, buffer_u8, _b ^ 1);
    buffer_seek(_buffer, buffer_seek_start, _old_pos);
}

/// @ignore
function __cyg_encode_key_array(_text_key)
{
    var _arr = [];
    var _mask = 42;
    var _len = string_length(_text_key);

    for (var _i = 1; _i <= _len; ++_i)
    {
        array_push(_arr, string_byte_at(_text_key, _i) ^ _mask);
    }

    return _arr;
}

/// @ignore
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
function __cyg_test_chacha(_runner)
{
    var _suite_chacha = new CrispySuite("cyg_11_chacha_suite");
    _runner.AddTestSuite(_suite_chacha);
    _runner.Discover(_suite_chacha, "test_cyg_11_chacha_");
}

/// @ignore
function __cyg_test_path_validation(_runner)
{
    var _suite_paths = new CrispySuite("cyg_12_path_validation_suite");
    _runner.AddTestSuite(_suite_paths);
    _runner.Discover(_suite_paths, "test_cyg_12_path_validation_");
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

    Cyg.Add("player", _player);

    var _retrieved = Cyg.Get("player");

    AssertIsNotUndefined(_retrieved, "stored player data should be defined");
    AssertDeepEqual(_retrieved, _player, "Get should return the same struct that was stored");
}

/// @ignore
function test_cyg_01_core_get_default_and_overwrite()
{
    __cyg_reset_state();

    Cyg.Add("slot", 1);
    Cyg.Add("slot", 2);

    AssertEqual(Cyg.Get("slot"), 2, "Add should overwrite an existing key");
    AssertEqual(Cyg.Get("missing_key", "fallback"), "fallback", "Get should return the provided default for missing keys");
}

/// @ignore
function test_cyg_01_core_exists_remove_and_cleanup()
{
    __cyg_reset_state();

    Cyg.Add("temporary", { score: 5000 });
    Cyg.Add("persistent", true);

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

    Cyg.Add("coins", 25);

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
    Cyg.Add("temp_key", true);
    Cyg.Cleanup();

    AssertFalse(Cyg.Exists("temp_key"), "Cleanup should remove user data keys");
    AssertEqual(Cyg.Get("__file_version"), -1, "Cleanup should reset __file_version to -1");
    AssertIsNotUndefined(Cyg.Get("__cyg_version", undefined), "Cleanup should keep internal __cyg_version metadata");
}

/// @ignore
function test_cyg_02_file_deletefile_removes_save_and_backup()
{
    __cyg_reset_state();

    var _path = __cyg_test_file("cyg_delete_file.dat");
    __cyg_delete_test_files(_path);

    __cyg_write_text_file(_path, "primary");
    __cyg_write_text_file(_path + ".bak", "backup");

    var _deleted = Cyg.DeleteFile(_path);

    AssertTrue(_deleted, "DeleteFile should return true when primary file exists");
    AssertFalse(file_exists(_path), "DeleteFile should delete primary file");
    AssertFalse(file_exists(_path + ".bak"), "DeleteFile should delete backup file when backups are enabled");
}

/// @ignore
function test_cyg_02_file_deletefile_returns_false_when_missing()
{
    __cyg_reset_state();

    var _path = __cyg_test_file("cyg_delete_missing.dat");
    __cyg_delete_test_files(_path);

    var _deleted = Cyg.DeleteFile(_path);

    AssertFalse(_deleted, "DeleteFile should return false when primary file does not exist");
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
    Cyg.Add("player", { name: "FullSaveHero", hp: 77 });
    Cyg.Add("world", { chapter: 3 });

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
        AssertTrue(file_exists(_s.path), "Full-store export should create the target file");

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
            Cyg.SetEncryptKey("async_key");
            Cyg.Add("game_settings", { difficulty: "hard", volume: 0.75 });
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
        AssertTrue(file_exists(_s.path), "Encrypted export should create the target save file");
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

        if (is_struct(_s.import_data) && struct_exists(_s.import_data, "difficulty"))
        {
            AssertEqual(_s.import_data.difficulty, "hard", "Imported data should preserve field values");
        }
        else
        {
            AssertTrue(false, "Imported data should contain the 'difficulty' field");
        }

        AssertDeepEqual(Cyg.Get("game_settings"), _s.import_data, "Import with a key should store the imported data in Cyg");
        __cyg_delete_test_files(_s.path);
        __cyg_reset_state();
        return true;
    })
    .Timeout(180, "frames");
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
            Cyg.Add("array_key_payload", { value: 404 });
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
        if (is_struct(_s.import_data) && struct_exists(_s.import_data, "value"))
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
            Cyg.SetEncryptKey("correct_key");
            Cyg.Add("secure_data", { rank: 9 });
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
            Cyg.SetEncryptKey("wrong_key");
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
            Cyg.SetEncryptKey("non_empty_key");
            Cyg.Add("empty_key_payload", { id: 12 });
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
            Cyg.Add("integrity_payload", { hp: 10 });
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
        __cyg_append_text_file(_s.path, "_tampered");
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
            Cyg.Add("slot", { round: 1 });
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
        return true;
    })
    .WaitStep(function() {
        var _s = crispy_vars().cyg_resilience_backup;
        if (!_s.second_export_started)
        {
            Cyg.Add("slot", { round: 2 });
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

        if (is_struct(_s.import_data) && struct_exists(_s.import_data, "round"))
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
            Cyg.Add("legacy_player", { name: "Old Hero" });
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
                if (is_struct(_save) && !struct_exists(_save, "hp"))
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

        if (is_struct(_s.import_data))
        {
            if (struct_exists(_s.import_data, "name"))
            {
                AssertEqual(_s.import_data.name, "Old Hero", "Fixers should preserve existing fields");
            }
            else
            {
                AssertTrue(false, "Migrated data should contain the 'name' field");
            }

            if (struct_exists(_s.import_data, "hp"))
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
        if (is_struct(_stored) && struct_exists(_stored, "hp"))
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
function test_cyg_11_chacha_roundtrip_sync()
{
    var _plain_text = "ChaCha standalone roundtrip payload";
    var _plain_buffer = __cyg_buffer_from_string(_plain_text);
    var _key = "0123456789ABCDEF0123456789ABCDEF";
    var _nonce = "nonce1234567";

    var _encrypted = chacha_encrypt(_plain_buffer, _key, _nonce, 1);
    AssertIsNotUndefined(_encrypted, "chacha_encrypt should return a buffer for valid inputs");

    var _decrypted = chacha_decrypt(_encrypted, _key, _nonce, 1);
    AssertIsNotUndefined(_decrypted, "chacha_decrypt should return a buffer for valid inputs");

    var _decrypted_text = __cyg_buffer_to_string(_decrypted);
    AssertEqual(_decrypted_text, _plain_text, "ChaCha roundtrip should recover original plaintext");

    buffer_delete(_plain_buffer);
    buffer_delete(_encrypted);
    buffer_delete(_decrypted);
}

/// @ignore
function test_cyg_11_chacha_invalid_key_length_returns_undefined_sync()
{
    var _plain_buffer = __cyg_buffer_from_string("data");
    var _bad_key = "short_key";
    var _nonce = "nonce1234567";

    var _encrypted = chacha_encrypt(_plain_buffer, _bad_key, _nonce, 1);
    AssertIsUndefined(_encrypted, "chacha_encrypt should reject keys that are not 32 bytes");

    buffer_delete(_plain_buffer);
}

/// @ignore
function test_cyg_11_chacha_aead_roundtrip_sync()
{
    var _plain_buffer = __cyg_buffer_from_string("Authenticated payload");
    var _aad_buffer = __cyg_buffer_from_string("aad-metadata");
    var _key = "0123456789ABCDEF0123456789ABCDEF";
    var _nonce = "nonce1234567";

    var _enc = chacha20_poly1305_encrypt(_plain_buffer, _key, _nonce, _aad_buffer, 1);
    AssertTrue(_enc.success, "AEAD encrypt should succeed with valid parameters");
    AssertIsNotUndefined(_enc.ciphertext_buffer, "AEAD encrypt should provide ciphertext_buffer");
    AssertIsNotUndefined(_enc.tag_buffer, "AEAD encrypt should provide tag_buffer");

    var _dec = chacha20_poly1305_decrypt(_enc.ciphertext_buffer, _key, _nonce, _enc.tag_bytes, _aad_buffer, 1);
    AssertTrue(_dec.success, "AEAD decrypt should succeed with correct tag and AAD");
    AssertTrue(_dec.tag_ok, "AEAD decrypt should mark tag verification as true");
    AssertEqual(__cyg_buffer_to_string(_dec.plaintext_buffer), "Authenticated payload", "AEAD decrypt should recover original plaintext");

    buffer_delete(_plain_buffer);
    buffer_delete(_aad_buffer);
    buffer_delete(_enc.ciphertext_buffer);
    buffer_delete(_enc.tag_buffer);
    buffer_delete(_dec.plaintext_buffer);
}

/// @ignore
function test_cyg_11_chacha_aead_tampered_ciphertext_fails_sync()
{
    var _plain_buffer = __cyg_buffer_from_string("Payload to tamper");
    var _aad_buffer = __cyg_buffer_from_string("aad");
    var _key = "0123456789ABCDEF0123456789ABCDEF";
    var _nonce = "nonce1234567";

    var _enc = chacha20_poly1305_encrypt(_plain_buffer, _key, _nonce, _aad_buffer, 1);
    AssertTrue(_enc.success, "AEAD precondition encrypt should succeed");

    __cyg_flip_first_byte(_enc.ciphertext_buffer);

    var _dec = chacha20_poly1305_decrypt(_enc.ciphertext_buffer, _key, _nonce, _enc.tag_bytes, _aad_buffer, 1);
    AssertFalse(_dec.success, "AEAD decrypt should fail when ciphertext was modified");
    AssertFalse(_dec.tag_ok, "AEAD decrypt should report tag mismatch for tampered ciphertext");
    AssertIsUndefined(_dec.plaintext_buffer, "AEAD decrypt should not return plaintext on tag failure");

    buffer_delete(_plain_buffer);
    buffer_delete(_aad_buffer);
    buffer_delete(_enc.ciphertext_buffer);
    buffer_delete(_enc.tag_buffer);
}

/// @ignore
function test_cyg_11_chacha_aead_wrong_aad_fails_sync()
{
    var _plain_buffer = __cyg_buffer_from_string("Payload with aad");
    var _aad_ok = __cyg_buffer_from_string("aad-ok");
    var _aad_wrong = __cyg_buffer_from_string("aad-wrong");
    var _key = "0123456789ABCDEF0123456789ABCDEF";
    var _nonce = "nonce1234567";

    var _enc = chacha20_poly1305_encrypt(_plain_buffer, _key, _nonce, _aad_ok, 1);
    AssertTrue(_enc.success, "AEAD precondition encrypt should succeed");

    var _dec = chacha20_poly1305_decrypt(_enc.ciphertext_buffer, _key, _nonce, _enc.tag_bytes, _aad_wrong, 1);
    AssertFalse(_dec.success, "AEAD decrypt should fail when AAD is different");
    AssertFalse(_dec.tag_ok, "AEAD decrypt should report tag mismatch with wrong AAD");

    buffer_delete(_plain_buffer);
    buffer_delete(_aad_ok);
    buffer_delete(_aad_wrong);
    buffer_delete(_enc.ciphertext_buffer);
    buffer_delete(_enc.tag_buffer);
}

/// @ignore
function test_cyg_12_path_validation_export_rejects_empty_path_sync()
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
function test_cyg_12_path_validation_import_rejects_url_like_path_sync()
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
