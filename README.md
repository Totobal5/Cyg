# Cyg

Sistema de guardado simple para GameMaker (GML).

## Cómo se usa

```gml
// Agregar datos
Cyg.Add("player_name", "Toto");
Cyg.Add("level", 5);
Cyg.Add("inventory", ["sword", "potion"]);

// Guardar
Cyg.Export("save_file");

// Cargar
Cyg.Import("save_file");

// Leer datos
var name = Cyg.Get("player_name");
var level = Cyg.Get("level");
```
Los datos se guardan en archivos JSON y se cargan cuando los necesitas.

## Features

**Guardado y carga básicos**
- Usa JSON como formato base
- API simple: `Add()`, `Export()`, `Import()`, `Get()`

**Seguridad y optimización**
- Encriptación RC4 opcional
- Compresión de archivos para reducir tamaño

**Fixers (migraciones)**
- Sistema para migrar partidas guardadas cuando actualizas tu juego
- Útil si cambias la estructura de datos entre versiones
- Define un fixer y Cyg lo aplica automáticamente al cargar

**Respaldo automático**
- Crea archivos `.bak` antes de sobrescribir
- Guardado asíncrono disponible

## Instalación

1. Descarga los scripts de la carpeta `scripts/`
2. Importa el archivo `.yymps` en tu proyecto de GameMaker
3. Usa `Cyg.Add()` y `Cyg.Export()` en tu código

## Licencia

[MIT](https://github.com/Totobal5/Cyg/blob/main/LICENSE)
