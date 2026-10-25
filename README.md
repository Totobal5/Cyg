# Cyg

A save system for GameMaker designed to make saving and loading painless.

If you want to stop fighting files, formats, and load errors, Cyg gives you a short clear API.

Note: Cyg has not yet been used by me in a production game.

## Why Use Cyg

- Save and load in just a few lines.
- Data is stored as JSON (easy to inspect and debug).
- Turn modern encryption on when you need it (ChaCha20-Poly1305).
- SHA-256 integrity checks protect against accidental or malicious file tampering.
- Automatic timestamped backups help protect player progress.
- Built-in versioning and migration support keep old saves compatible.

## Quick Start

```gml
// 1) Store values
Cyg.Set("player_name", "Toto");
Cyg.Set("level", 5);
Cyg.Set("inventory", ["sword", "potion"]);

// 2) Save to disk
Cyg.Export("save_file");

// 3) Load later
Cyg.Import("save_file");

// 4) Read values
var name = Cyg.Get("player_name");
var level = Cyg.Get("level");
```

## Paths And The File System Sandbox

Pass a file name (`"save_file"`) and Cyg resolves it for you. GameMaker stores files written by
`buffer_save_async()` inside a `default/` folder of `game_save_id`, and — as the manual states —
no other file function adds that folder on its own. Cyg therefore hands the async calls the name
as given and the synchronous helpers behind backups, pruning and `Cyg.Delete()` the same file with
`default/` spelled out, so every operation addresses one file with the file system sandbox enabled
or disabled.

An absolute path is passed through untouched: GameMaker skips the `default/` folder for it when the
sandbox is disabled, and Cyg accounts for that too.

## Simple Encryption Setup

Set the key once at start-up — `Export()` and `Import()` use it whenever you pass `true`:

```gml
Cyg.SetEncryptKey("0123456789abcdef0123456789abcdef");   // 32 bytes

Cyg.Export("save_file", undefined, true);
Cyg.Import("save_file", undefined, true);
```

`CYG_MASTER_KEY` inside the prefab is only its built-in default: a macro defined in your own
project does not reach the prefab, so use `Cyg.SetEncryptKey()` (or customise the prefab) instead.

That is it. Cyg handles the rest.

## What You Get

- Async save/load operations.
- Optional authenticated encryption (ChaCha20-Poly1305).
- Optional compression.
- SHA-256 file integrity checks.
- Automatic backups with timestamp history.
- Versioned fixers for save migrations.

## Installation

1. Download the `scripts/` folder.
2. Import the `.yymps` package into your GameMaker project.
3. Start using `Cyg.Set()`, `Cyg.Export()`, `Cyg.Import()`, and `Cyg.Get()`.

## License

[MIT](https://github.com/Totobal5/Cyg/blob/main/LICENSE)
