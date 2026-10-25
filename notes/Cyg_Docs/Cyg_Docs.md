# Cyg

`Cyg` is a GameMaker save/load library in pure GML. It keeps your game state in memory under string keys, serializes it to JSON, and writes or reads it with the asynchronous buffer functions, calling you back when the operation finishes.

The library only stores and loads what you give it. It does not inspect your gameplay data, does not manage your scene or inventory, and does not create directories. Encryption and hashing come from the `aed` prefab, and every path decision comes from the `fixpath` prefab.

```gml
Cyg.Set("player_name", "Toto");
Cyg.Set("level", 5);

Cyg.Export("save_file");
// later
Cyg.Import("save_file");

var _name = Cyg.Get("player_name");
```

## Storing data

`Cyg.Set(key, value)` stores any JSON-serializable value — a struct, array, number, string, or boolean. Nothing touches the disk until you call `Cyg.Export()`.

```gml
Cyg.Set("player", { name: "Toto", hp: 100, inventory: ["sword", "potion"] });
Cyg.Set("level", 5);

Cyg.Get("level");                  // 5
Cyg.Get("missing", "fallback");    // "fallback"
Cyg.Exists("player");              // true
Cyg.Remove("level");               // 5
Cyg.Cleanup();                     // clears every key
```

Two keys are reserved metadata and are written into every save: `__cyg_version` (the library version that wrote the file) and `__file_version` (the number you pass to `Cyg.SetVersion()`). `Cyg.Get()` returns them like any other key, which is handy in tests.

## Saving and loading

`Cyg.Export()` and `Cyg.Import()` are asynchronous. Both take a callback that runs from the Async Save/Load event, so the game keeps running in the meantime. Cyg creates `o_cyg_manager` on the first call and that object forwards the event to `Cyg.__ProcessAsyncEvent()`; do not delete it from the project.

```gml
Cyg.Export("save_file", undefined, false, function(_success) {
    if (!_success) show_debug_message("Save failed.");
});

Cyg.Import("save_file", undefined, false, function(_success, _data) {
    if (_success) show_debug_message("Loaded.");
});
```

The second argument is the key to save or load:

- `undefined` saves the whole store, and a keyless import replaces the whole store (metadata included).
- A key saves only that value, and a keyed import restores only that key.

Calls are tracked by async id, so several saves can be in flight, but two writes to the same file should not overlap.

## Encryption

Encryption is authenticated with ChaCha20-Poly1305 and is off by default. Pass `true` as the third argument to `Export()` and `Import()`:

```gml
Cyg.Export("save_file", undefined, true);
Cyg.Import("save_file", undefined, true);
```

The key is either the `CYG_MASTER_KEY` macro (32 ASCII bytes in an array) or whatever you pass to `Cyg.SetEncryptKey()`, which accepts a 32-byte string, array, or buffer:

```gml
Cyg.SetEncryptKey("0123456789abcdef0123456789abcdef");
Cyg.SetEncryptKey(undefined);   // back to CYG_MASTER_KEY
```

Two behaviours are worth knowing:

- If you ask for an encrypted export without a valid key, Cyg logs an alert and writes the save **unencrypted** instead of failing.
- A keyed import with the wrong key fails the authentication tag check, reports `false`, and leaves the store untouched.

## Integrity checks

Every save begins with a SHA-256 of the payload. On import, `Cyg.Import()` recomputes it and refuses the file when it does not match, so a truncated, edited, or corrupted save never reaches your fixers.

Conceptually the bytes of a save file are:

```text
"<64 hex characters of sha256>"\0     payload (JSON, optionally encrypted/compressed)
```

Set `CYG_COMPRESS_ENABLED` to `true` to compress the payload before it is written; Cyg records nothing else in the file, so the same setting has to be used when reading.

## Backups

Before overwriting an existing save, `Cyg.Export()` renames it to a backup whose name comes from `CYG_BACKUP_FILENAME_FORMAT` (`{0}` is the file, `{1}` the timestamp, default `"{0}_{1}.bak"`), using a `YYYYMMDD_HHMMSS` stamp.

`CYG_BACKUP_MAX_COUNT` (default `1`) keeps only the newest backups; older ones are pruned right after the new one is created. Set it to `0` to keep none.

```gml
Cyg.RestoreBackup("save_file");   // renames the newest backup over the save, true on success
Cyg.Delete("save_file");          // deletes the save and every backup of it, true when the save was removed
```

Both are synchronous, unlike `Export()` and `Import()`.

## Save migration

`Cyg.SetVersion()` records the version written by the next export, and `Cyg.AddFixer()` registers a callback that upgrades an older payload on import:

```gml
// Version 1 stored `hp` as a string.
Cyg.AddFixer(1, function(_payload) {
    _payload.hp = real(_payload.hp);
    return _payload;
});

Cyg.SetVersion(2);
```

The fixer runs only for files whose `__file_version` matches, and must return the payload it was given. A keyless import hands it the whole store; a keyed import hands it just that value. A fixer that throws is caught and reported, and the import fails instead of half-loading.

## Paths and the file system sandbox

Pass a logical name such as `"save_file"`; Cyg asks `fixpath` where that file actually lives.

The two families of GameMaker functions disagree about relative names, and the manual documents why: `buffer_save_async()` writes a relative name inside a `default/` folder of the save area, and **no other file function adds that folder**. Cyg therefore resolves two paths for every call:

| Cyg helper | Used for | Resolves with |
| --- | --- | --- |
| `__ResolvePath()` | `buffer_save_async`, `buffer_load_async` | `fp_resolve_path()` |
| `__ResolveSyncPath()` | `file_exists`, `file_rename`, `file_find_first`, `file_delete` | `fp_sync_path()` |

Absolute paths are accepted too. With the sandbox disabled they are used as given; with the sandbox enabled every absolute path is rejected by the runtime, so an absolute path inside the save area is turned into its relative form first. The suite runs in both modes (`test_cyg_12_path_modes_*` pins the contract).

## API

### `Cyg.Set(key, value)`

Stores or overwrites a value. Returns `self`, so calls can be chained.

### `Cyg.Get(key, default_value)`

Returns the stored value, or `default_value` (`undefined` by default) when the key is missing.

### `Cyg.Exists(key)`

Returns whether the key is present.

### `Cyg.Remove(key)`

Removes the key and returns its previous value, or `undefined` when it did not exist.

### `Cyg.Cleanup()`

Resets the store to its initial state, keeping only the metadata keys. It does not touch the disk.

### `Cyg.SetVersion(version)`

Sets the `__file_version` written by the next export. Returns `self`.

### `Cyg.AddFixer(version_key, callback)`

Registers the fixer that migrates a payload saved as `version_key`. Returns `self`.

### `Cyg.SetEncryptKey(key)`

Sets the key used by `Export()` and `Import()`: 32 bytes as a string, array, or buffer. Pass `undefined` to fall back to `CYG_MASTER_KEY`. Returns `self`.

### `Cyg.Export(path, [key], [encrypt], [callback])`

Saves the store (or a single key) asynchronously. `callback` receives `success:Bool`. Creates the backup of the previous file before writing.

### `Cyg.Import(path, [key], [encrypt], [callback])`

Loads a save asynchronously. `callback` receives `success:Bool` and the imported `data`, which is also stored in the game (`Set(key, data)` or a full store replacement). A missing file, a checksum mismatch, an invalid payload, or a failed decryption reports `false` and leaves the store unchanged.

### `Cyg.RestoreBackup(path)`

Renames the newest backup over the save and returns `true`, or returns `false` when there is no backup.

### `Cyg.Delete(path)`

Deletes the save and all of its backups. Returns `true` when the save file existed.

## Configuration

| Macro | Default | Effect |
| --- | --- | --- |
| `CYG_MASTER_KEY` | 32 ASCII bytes | Default encryption key. |
| `CYG_BACKUPS_ENABLED` | `true` | Create a backup before overwriting a save. |
| `CYG_BACKUP_FILENAME_FORMAT` | `"{0}_{1}.bak"` | Backup name pattern. |
| `CYG_BACKUP_MAX_COUNT` | `1` | Backups kept per save, oldest pruned first. |
| `CYG_COMPRESS_ENABLED` | `false` | Compress the payload before writing. |
| `CYG_LOG_ALERTS` | `true` | Print diagnostics with `show_debug_message()`. |
| `CYG_LOG_ERRORS` | `true` | Print errors with `show_debug_message()`. |
| `CYG_FATAL_ERRORS` | `false` | Turn logged errors into a `show_error()` abort. |

Macros are compile-time, so they cannot be changed while the game runs; use `SetVersion()` and `SetEncryptKey()` for the settings that have to vary.

## Scope and limitations

- The library is asynchronous by design: `Export()` and `Import()` never complete inside the calling frame, and their callbacks run from the Async Save/Load event.
- It requires `o_cyg_manager` in the project. Cyg spawns it on the first call, so keep the object when trimming the package.
- Values must survive `json_stringify()` and `json_parse()`: no methods, no instance references, and no `undefined` values inside structs.
- Without a key, the whole store is serialized on every export, including the metadata keys.
- Encryption is skipped, with an alert, when no valid key is available; the save is then readable without a key.
- The integrity hash detects corruption and tampering; it is not a signature, and it does not hide the payload.
- Backups are renames of the previous save, so they are only as good as the file that was there.
- `Delete()` and `RestoreBackup()` are synchronous, unlike the save and load calls.
- Absolute paths outside the save area need the file system sandbox disabled; sandboxed targets reject every absolute path.
- Cyg does not create directories or retry a failed write; a failed export reports `false` through the callback.
- Two saves to the same file should not overlap, even though requests are tracked by async id.
- The library depends on the `aed`, `fixpath`, and `ytrace` prefabs.

## License

[MIT License](../Cyg_Licence/Cyg_Licence.md)
