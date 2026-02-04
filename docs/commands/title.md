# Command: `title`

Changes the title of the game window at runtime.

## Usage
```vnef
title "<text>"
```

## Parameters
- `"<text>"`: The new window title text. Quotes are optional but recommended for multiple words.

## Example
```vnef
title "Chapter 1: The Beginning"
say Alice "Where am I?"
```

## Notes
- This overrules the `window_title` set in `demo/config.vnef`.
- Useful for indicating story progress or location.
