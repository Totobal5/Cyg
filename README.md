# Cyg

Simple save system for GameMaker (GML).

## How to use

```gml
// Add data
Cyg.Add("player_name", "Toto");
Cyg.Add("level", 5);
Cyg.Add("inventory", ["sword", "potion"]);

// Save
Cyg.Export("save_file");

// Load
Cyg.Import("save_file");

// Read data
var name = Cyg.Get("player_name");
var level = Cyg.Get("level");
```
Data is saved to JSON files and loaded when you need it.

## Features

**Basic save and load**
- Uses JSON as the base format
- Simple API: `Add()`, `Export()`, `Import()`, `Get()`

**Security and optimization**
- Optional RC4 encryption
- File compression to reduce size

**Fixers (migrations)**
- System to migrate save files when you update your game
- Useful if you change the data structure between versions
- Define a fixer and Cyg applies it automatically on load

**Automatic backups**
- Creates `.bak` files before overwriting
- Async saving available

## Installation

1. Download the scripts from the `scripts/` folder
2. Import the `.yymps` file into your GameMaker project
3. Use `Cyg.Add()` and `Cyg.Export()` in your code

## License

[MIT](https://github.com/Totobal5/Cyg/blob/main/LICENSE)
