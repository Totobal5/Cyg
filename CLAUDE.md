# Cyg - GameMaker project

Cyg is a save/load library (scripts/Cyg). This repo is its dev project, bundled with
the **Crispy** test framework (scripts/crispy_*) and the test suite (scripts/Cyg_Tests).

## Editing GameMaker project files

Do not make changes to `.yy` or `.yyp` files yourself.
It's very hard to correctly edit these manually!
You MUST use commands exposed by the `gamemaker-resource-tool` MCP server
(configured in `.mcp.json`; launched via `npx @gamemaker/gm-cli@latest resourcetool mcp`).

`.gml` files (including object event files like `objects/o_cyg_test_suite/Create_0.gml`)
are plain text and can be edited with normal tools. `.gitattributes` forces LF endings.

## Verifying changes

```
npx @gamemaker/gm-cli compile --errors-only   # syntax/compile check
npx @gamemaker/gm-cli run                     # run tests; see "Running tests" below
```

## Running tests

Tests are not run separately — they run inside the game. Room1 spawns `o_cyg_test_suite`,
whose Create event builds a `CrispyRunner` and registers the groups in
`scripts/Cyg_Tests/Cyg_Tests.gml` (`__cyg_test_core`, `__cyg_test_async_io`,
`__cyg_test_storage_resilience`, `__cyg_test_path_validation`); its Step event advances
async cases. Results print via `show_debug_message`.

- Do NOT use `--errors-only` for `run`: it suppresses the console output that Crispy
  reports test results through, so you'd never see the pass/fail summary.
- Failing tests only abort the game if `CRISPY_STRICT_MODE` is true (default is false in
  `scripts/crispy_Config/crispy_Config.gml`), so a red summary in console output is the signal.

## Project layout

- `scripts/Cyg/Cyg.gml` — the library. Public API is `Cyg.Set/Get/Export/Import` plus a
  `Cyg` namespace; config via `CYG_*` macros. Consumer docs in `README.md`.
- `scripts/crispy_*` — vendored Crispy testing framework (do not treat as app code).
- `scripts/Cyg_Tests/Cyg_Tests.gml` — the test suite that exercises Cyg.

# GameMaker Language (GML) Guidance

Make changes to `.gml` files using your built-in tools, if you so wish.

## GML Naming conventions

- Use `snake_case` for all variables and functions
- Prefix local variables with `_` (e.g., `var _temp_value`, `var _effect`)
- Prefix resource names based on their type, e.g. obj_player, spr_player, etc.
- In this repo, public Cyg API uses `PascalCase` method names (e.g. `Cyg.Set`)
  while helpers/internal macros use `snake_case`.

## GML reserved names

Your own names must avoid clashing with these:

- `score`, `lives`, `health`
- Position: `x`, `y`
- Sprite: `sprite_index`, `image_index`, `image_speed`, `image_xscale`, `image_yscale`, `image_angle`, `image_alpha`, `image_blend`
- Physics: `speed`, `direction`, `friction`, `gravity`, `gravity_direction`
- Collision: `bbox_left`, `bbox_right`, `bbox_top`, `bbox_bottom`
- Instance: `id`, `object_index`, `layer`, `depth`, `visible`, `persistent`

## Modern idiomatic GML

GML has support for **structs** (dynamic objects similar to JavaScript).

```gml
var _mystruct =
{
    a : 20,
    b : "Hello World"
};

// There is support for constructor functions and methods tied to the struct too
function Vector2(_x, _y) constructor
{
    x = _x;
    y = _y;

    static Add = function(_vec2)
    {
        x += _vec2.x;
        y += _vec2.y;
    }
}

v2 = new Vector2(10, 10);
```

GML *script* files now requires one or more function definitions

```gml
// in move script
function move(spd, dir)
{
    speed = spd;
    direction = dir;
}

```

This repo's code uses these modern features (structs, `function` constructors with
`static` members, template strings) — keep that style when editing.

## Library Functions

- Prefer `instance_create_layer()` over deprecated `instance_create()`

## Misc

- `AGENTS.md` duplicates this file; keep both in sync when editing.