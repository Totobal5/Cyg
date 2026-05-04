# Cyg

A save system for GameMaker designed to make saving and loading painless.

If you want to stop fighting files, formats, and load errors, Cyg gives you a short, clear API that is ready for production.

Current release: v4.0.0

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
Cyg.Add("player_name", "Toto");
Cyg.Add("level", 5);
Cyg.Add("inventory", ["sword", "potion"]);

// 2) Save to disk
Cyg.Export("save_file");

// 3) Load later
Cyg.Import("save_file");

// 4) Read values
var name = Cyg.Get("player_name");
var level = Cyg.Get("level");
```

## Simple Encryption Setup

Define one master key as an ASCII byte array:

```gml
#macro CYG_MASTER_KEY [43, 20, 10, 43, 48, ...]
```

Then enable encryption with the same flow you already use:

```gml
Cyg.Export("save_file", undefined, true);
Cyg.Import("save_file", undefined, true);
```

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
3. Start using `Cyg.Add()`, `Cyg.Export()`, `Cyg.Import()`, and `Cyg.Get()`.

## License

[MIT](https://github.com/Totobal5/Cyg/blob/main/LICENSE)
