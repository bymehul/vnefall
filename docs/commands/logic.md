# Command: `set` / `if` / `else`

Logic and conditional branching using variables.

## Usage
```vnef
set <var> = <value>
if (<expression>) {
    # commands
} else {
    # commands
}
```

## Parameters
- `<var>`: Variable name.
- `<value>`: An integer, string `"text"`, `true` (1), `false` (0), or another variable name.
- `<expression>`: A comparison using `==`, `!=`, `>`, `<`, `>=`, `<=`.

## Logic Blocks
Blocks are wrapped in curly braces `{}`. **Indentation is MANDATORY** for readability.

```vnef
set money = 100
set name = "Alice"

# Arithmetic
set money = money + 50
set money = money * 2

# Logic Block
if (money >= 200) {
    say Alice "Rich!"
} else {
    say Alice "Poor..."
}
```

## Supported Operations
- **Assignment**: `set x = y`, `set x = 10`, `set s = "string"`
- **Arithmetic**: `+`, `-`, `*`, `/` (Integers only)
- **Comparison**: `==`, `!=`, `>`, `<`, `>=`, `<=`. 
    - **Strings**: Supports `==` and `!=` (e.g., `if (name == "Alice")`).
    - **Type-Safety**: Comparing an integer to a string (e.g. `if (gold == "Alice")`) will safely return `false` instead of crashing.

## Notes
- **Mandatory Indentation**: Always indent the commands inside `if` or `else` blocks.
- Variables are global to the current script file.
- `}` must be on its own line (or followed by `else`).
