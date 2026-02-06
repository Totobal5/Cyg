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

// --- Suite de Pruebas 3: Operaciones Asíncronas de I/O ---
function __cyg_test_async_io(_runner)
{
    var suite_async = new TestSuite("Cyg - Pruebas de I/O Asíncrono");
    _runner.addTestSuite(suite_async);

    globalvar TEST_FILE_ASYNC;
	TEST_FILE_ASYNC = "cyg_test_async.dat";

    // --- Configuración ---
    suite_async.setUp(function() {
        // Estado inicializado en o_cyg_test_suite Create
    });

    suite_async.tearDown(function() {
        if (file_exists(TEST_FILE_ASYNC) ) file_delete(TEST_FILE_ASYNC);
        if (file_exists(TEST_FILE_ASYNC + ".bak") ) file_delete(TEST_FILE_ASYNC + ".bak");
        Cyg.Remove("game_settings");
    });

    // --- Caso de Prueba 3.1: Export (Async) ---
    var test_export_async = new TestCase("Test Export (Async)", function() {
        var _state = global.__cyg_async_test_state;
        show_debug_message("CYG TEST ASSERT: export_done=" + string(_state.export_done) + ", export_success=" + string(_state.export_success));

        assertTrue(_state.export_done, "El export async debería haber finalizado.");
        assertTrue(_state.export_success, "El export async debería ser exitoso.");
    });

    // --- Caso de Prueba 3.2: Import (Async) ---
     var test_import_async = new TestCase("Test Import (Async)", function() {
        var _state = global.__cyg_async_test_state;
        show_debug_message("CYG TEST ASSERT: import_done=" + string(_state.import_done) + ", import_success=" + string(_state.import_success));
        show_debug_message("CYG TEST ASSERT: import_data defined=" + string(!is_undefined(_state.import_data)));
        if (!is_undefined(_state.import_data)) {
            show_debug_message("CYG TEST ASSERT: import_data.difficulty=" + string(_state.import_data.difficulty));
        }

        assertTrue(_state.import_done, "El import async debería haber finalizado.");
        assertTrue(_state.import_success, "El import async debería ser exitoso.");
        assertIsNotUndefined(_state.import_data, "Los datos importados no deberían ser undefined.");
        assertEqual(_state.import_data.difficulty, "hard", "La dificultad importada no coincide.");
    });

    // Agregar tests a la suite
    suite_async.addTestCase(test_export_async);
    suite_async.addTestCase(test_import_async);
}
