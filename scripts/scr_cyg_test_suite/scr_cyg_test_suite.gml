// --- Suite de Pruebas 1: Funcionalidad Central ---
function __cyg_test_core(_runner)
{
	var suite_core = new TestSuite("Cyg - Pruebas de Componentes Base");
	_runner.addTestSuite(suite_core);

	// --- Configuración ---
	suite_core.setUp(function() {
	    // Limpiar datos antes de cada prueba
	    Cyg.Remove("test_data");
        Cyg.Remove("another_data");
	});

	// --- Caso de Prueba 1.1: Add y Get ---
	var test_add_get = new TestCase("Test Add y Get", function() {
	    // Arrange
	    var test_struct = { name: "Player1", hp: 100 };
	    Cyg.Add("test_data", test_struct);

	    // Act
	    var retrieved_data = Cyg.Get("test_data");

	    // Assert
	    assertIsNotUndefined(retrieved_data, "Los datos obtenidos no deberían ser nulos.");
	    assertEqual(retrieved_data.name, "Player1", "El nombre en los datos obtenidos no coincide.");
	});
	suite_core.addTestCase(test_add_get);

	// --- Caso de Prueba 1.2: Exists y Remove ---
	var test_exists_remove = new TestCase("Test Exists y Remove", function() {
	    // Arrange
	    Cyg.Add("test_data", { score: 5000 });

	    // Act & Assert
	    assertTrue(Cyg.Exists("test_data"), "La clave 'test_data' debería existir.");
	    Cyg.Remove("test_data");
	    assertFalse(Cyg.Exists("test_data"), "La clave 'test_data' no debería existir después de ser eliminada.");
	});
	suite_core.addTestCase(test_exists_remove);
}

// --- Suite de Pruebas 2: Operaciones Síncronas de I/O ---
function __cyg_test_sync_io(_runner)
{
    var suite_sync = new TestSuite("Cyg - Pruebas de I/O Síncrono");
    _runner.addTestSuite(suite_sync);

    globalvar TEST_FILE;
	TEST_FILE = "cyg_test_save.dat"
	
    // --- Configuración ---
    suite_sync.setUp(function() {
        Cyg.SetEncryptKey([110, 97, 88, 122, 107, 96, 77, 124, 83, 83, 30, 31, 125, 79, 25, 78, 29, 90, 126, 24, 66, 19, 124, 92, 93, 73, 89, 97, 78, 105, 108, 24] );
        Cyg.Add("player", { name: "Hero", level: 10 });
    });

    suite_sync.tearDown(function() {
        if (file_exists(TEST_FILE)) file_delete(TEST_FILE);
        if (file_exists(TEST_FILE + ".bak")) file_delete(TEST_FILE + ".bak");
        Cyg.Remove("player");
    });
	
    // --- Caso de Prueba 2.1: Export/Import simple ---
    var test_simple_export_import = new TestCase("Test Export/Import Simple", function() {
        // Act
        Cyg.Export(TEST_FILE, "player");
        Cyg.Remove("player"); // Limpiar para asegurar que se carga desde el archivo
        var success = Cyg.Import(TEST_FILE, "player");

        // Assert
        assertTrue(success, "La importación debería ser exitosa.");
        assertIsNotUndefined(Cyg.Get("player"), "Los datos del jugador no deberían ser nulos después de importar.");
        assertEqual(Cyg.Get("player").level, 10, "El nivel del jugador no coincide después de importar.");
    });
    suite_sync.addTestCase(test_simple_export_import);

    // --- Caso de Prueba 2.2: Export/Import con Cifrado y Compresión ---
    var test_encrypted_export_import = new TestCase("Test Export/Import con Cifrado y Compresión", function() {
        // Act
        Cyg.Export(TEST_FILE, "player", true);
        Cyg.Remove("player");
        var success = Cyg.Import(TEST_FILE, "player", true);

        // Assert
        assertTrue(success, "La importación cifrada/comprimida debería ser exitosa.");
        assertEqual(Cyg.Get("player").name, "Hero", "El nombre no coincide después de importar un archivo cifrado.");
    });
    suite_sync.addTestCase(test_encrypted_export_import);

    // --- Caso de Prueba 2.3: Fallo de Checksum ---
    var test_checksum_fail = new TestCase("Test Fallo de Checksum por Archivo Corrupto", function() {
        // Arrange
        Cyg.Export(TEST_FILE, "player");
        var file = file_text_open_append(TEST_FILE);
        file_text_write_string(file, "corrupt_data"); // Modificar el archivo
        file_text_close(file);

        // Act
        var success = Cyg.Import(TEST_FILE, "player");

        // Assert
        assertFalse(success, "La importación debería fallar debido a un checksum incorrecto.");
    });
    suite_sync.addTestCase(test_checksum_fail);

    // --- Caso de Prueba 2.4: Restauración de Backup ---
    var test_backup_restore = new TestCase("Test Restauración de Backup", function() {
        // Arrange
        Cyg.Export(TEST_FILE, "player"); // Crea "cyg_test_save.dat"
        Cyg.Get("player").level = 11;
        Cyg.Export(TEST_FILE, "player"); // Mueve el save anterior a ".bak" y crea uno nuevo
        
        // Act
        var restored = Cyg.RestoreBackup(TEST_FILE);
        var imported = Cyg.Import(TEST_FILE, "player");
        
        // Assert
        assertTrue(restored, "La restauración del backup debería ser exitosa.");
        assertTrue(imported, "La importación del backup restaurado debería ser exitosa.");
        assertEqual(Cyg.Get("player").level, 10, "El nivel debería ser el del backup original (10).");
    });
    suite_sync.addTestCase(test_backup_restore);
}

// --- Suite de Pruebas 3: Operaciones Asíncronas de I/O ---
function __cyg_test_async_io(_runner)
{
    var suite_async = new TestSuite("Cyg - Pruebas de I/O Asíncrono");
    _runner.addTestSuite(suite_async);

    globalvar TEST_FILE_ASYNC;
	TEST_FILE_ASYNC = "cyg_test_async.dat";

    // --- Configuración ---
    suite_async.setUp(function() {
        Cyg.SetEncryptKey("async_key");
        Cyg.Add("game_settings", { difficulty: "hard" });
        self.async_result = { finished: false, success: false, data: undefined };
    });

    suite_async.tearDown(function() {
        if (file_exists(TEST_FILE_ASYNC) ) file_delete(TEST_FILE_ASYNC);
        Cyg.Remove("game_settings");
    });

    // --- Caso de Prueba 3.1: ExportAsync ---
    var test_export_async = new TestCase("Test ExportAsync", function() {
        // Arrange
        var _this = self;
        var callback = function(status) {
            _this.async_result.finished = true;
            _this.async_result.success = status;
        };

        // Act
        Cyg.ExportAsync(TEST_FILE_ASYNC, "game_settings", true, true, callback);

        // Assert: Esperar a que la operación termine (simulado)
        // En un framework real, esto podría usar `async_wait` o similar.
        // Aquí, simplemente asumimos que el evento se procesará.
        // La validación real ocurre en el callback.
        // Para una prueba real, necesitarías un objeto que espere el callback.
    });
    // NOTA: Las pruebas asíncronas reales en GML son complejas de automatizar sin un
    // framework de pruebas que soporte corutinas o una máquina de estados de prueba.
    // Esta suite demuestra la estructura, pero la validación final depende del callback.

    // --- Caso de Prueba 3.2: ImportAsync ---
     var test_import_async = new TestCase("Test ImportAsync", function() {
        // Arrange
        Cyg.Export(TEST_FILE_ASYNC, "game_settings"); // Guardar síncronamente para la prueba
        Cyg.Remove("game_settings");

        globalvar _this;
		_this = self;
		
        var callback = function(status, result_data) {
            _this.async_result.finished = true;
            _this.async_result.success = status;
            _this.async_result.data = result_data;
        };

        // Act
        Cyg.ImportAsync(TEST_FILE_ASYNC, "game_settings", false, true, callback);

        // Assert (similar a ExportAsync, la validación final está en el callback)
    });
}

/// @desc Suite de pruebas para verificar la carga de archivos de sesiones anteriores.
/// @param {Runner} _runner La instancia del corredor de pruebas.
function __cyg_test_persistent_file(_runner)
{
	var suite_persistent = new TestSuite("Cyg - Pruebas de Archivo Persistente");
	_runner.addTestSuite(suite_persistent);

	globalvar TEST_FILE_PERSISTENT;
	TEST_FILE_PERSISTENT = "cyg_persistent_test.dat";

	// --- Configuración: Se ejecuta ANTES de la prueba ---
	suite_persistent.setUp(function() {
	    // Arrange: Simular una sesión anterior guardando un archivo.
	    Cyg.SetEncryptKey("persistent_key");
	    Cyg.Add("session_data", { session_id: 12345, progress: 50 });
	    Cyg.Export(TEST_FILE_PERSISTENT, "session_data", true);
        
        // Limpiar los datos en memoria para simular un reinicio del juego.
		Cyg.Cleanup();
	});

	// --- Limpieza: Se ejecuta DESPUÉS de la prueba ---
	suite_persistent.tearDown(function() {
	    // Limpiar el archivo de prueba para no afectar otras suites.
	    if (file_exists(TEST_FILE_PERSISTENT) ) { file_delete(TEST_FILE_PERSISTENT); }
        if (file_exists(TEST_FILE_PERSISTENT + ".bak") ) { file_delete(TEST_FILE_PERSISTENT + ".bak"); }
	    
		Cyg.Remove("session_data");
        Cyg.Remove("loaded_data");
	});

	// --- Caso de Prueba: Cargar el archivo de la sesión anterior ---
	var test_load_persistent = new TestCase("Test Carga de Archivo de Sesión Anterior", function() {
	    // Act: Intentar cargar el archivo persistente en una nueva clave.
	    var success = Cyg.Import(TEST_FILE_PERSISTENT, "loaded_data", true);

	    // Assert
	    assertTrue(success, "La importación del archivo persistente debería ser exitosa.");
	    
	    var loaded_data = Cyg.Get("loaded_data");
	    assertIsNotUndefined(loaded_data, "Los datos cargados no deberían ser undefined.");
	    assertEqual(loaded_data.session_id, 12345, "El ID de sesión de los datos cargados no coincide.");
	    assertEqual(loaded_data.progress, 50, "El progreso en los datos cargados no coincide.");
	});
	suite_persistent.addTestCase(test_load_persistent);
}
