/// @ignore
#macro CRISPY_NAME      "Crispy"
/// @ignore
#macro CRISPY_AUTHOR    "Brent Frymire"
/// @ignore
#macro CRISPY_REPO      "https://github.com/bfrymire/crispy"
/// @ignore [MAJOR.MINOR.PATH]
#macro CRISPY_VERSION   "2.2.4"
/// @ignore yyyy-mm-dd
#macro CRISPY_DATE      "2025-11-26"

/// @ignore Boolean flag that can be used to automatically run tests
#macro CRISPY_RUN           true
/// @ignore Enables outputting extra context on some silent functions
#macro CRISPY_DEBUG         false
/// @ignore Determines how verbose assertion outputs will be. Acceptable values are 0, 1, or 2
#macro CRISPY_VERBOSITY     2
/// @ignore Enables strict mode. This will make the game close immediately with an error if the framework encounters an unexpected value or type, which can be useful for debugging
#macro CRISPY_STRICT_MODE   false

/// @ignore Number of decimal places to round to when outputting time values
#macro CRISPY_TIME_PRECISION 6 

/// @ignore Output string when an assertion passes silently
#macro CRISPY_PASS_MSG_SILENT   "."
/// @ignore Output string when an assertion fails silently
#macro CRISPY_FAIL_MSG_SILENT   "F"

/// @ignore Output string when an assertion passes verbosely
#macro CRISPY_PASS_MSG_VERBOSE  "Ok"
/// @ignore Output string when an assertion fails verbosely
#macro CRISPY_FAIL_MSG_VERBOSE  "Fail"

/// @ignore Number of characters per line when outputting CrispyCase statuses
#macro CRISPY_STATUS_OUTPUT_LENGTH 150

/// @ignore Enables silencing passing test messages
#macro CRISPY_SILENCE_PASSING_TESTS_OUTPUT false

/// @ignore Enables dunder variables to be overwritten when using `__crispy_struct_unpack`
#macro CRISPY_STRUCT_UNPACK_ALLOW_DUNDER false


show_debug_message("Using " + CRISPY_NAME + " unit testing framework by " + CRISPY_AUTHOR + ". This is version " + CRISPY_VERSION + ", released on " + CRISPY_DATE + ".");

global.__crispy_global = self;