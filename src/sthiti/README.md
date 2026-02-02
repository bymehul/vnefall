# Sthiti

Sthiti is a simple, fast, and no-nonsense save system for the Odin programming language. 

It's built to handle game saves and application states by writing them directly to binary files. No extra dependencies, no complex setup—just copy the folder and start saving.

## Features
- **Pure Odin**: No C or other dependencies.
- **Fast**: Uses a simple binary format for quick saving and loading.
- **Safe**: Includes checksums to make sure your data doesn't get corrupted.
- **Small**: The whole thing is just a few files that you can drop into any project.

## Installation
Copy the `sthiti/` folder into your project and import it:
```odin
import "sthiti"
```

## Usage
```odin
// 1. Create a state
state := sthiti.save_state_init()
state.variables["gold"] = 100

// 2. Save it to a file
sthiti.save_to_file("my_save.sthiti", state)
```

[📜 MIT License](LICENSE)
