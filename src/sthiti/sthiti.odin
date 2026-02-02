package sthiti

import "core:os"
import "core:fmt"
import "core:mem"

STHITI_MAGIC   :: "STHITI"
STHITI_VERSION :: 4  // Bumped for character list support

// Variable can be int or string
Variable :: union {
	i32,
	string,
}

// State for a single character on screen
Character_Save_State :: struct {
	name:        string,
	sprite_path: string,
	pos_name:    string,
	z:           i32,
}

// The full state of a game at a specific moment
Save_State :: struct {
	version:     u32,
	timestamp:   u64,
	
	// Script location
	script_path: string,        // e.g. "assets/scripts/ch1.vnef"
	script_ip:   i32,           // Current command index
	
	// Game variables (int or string)
	variables:   map[string]Variable,
	
	// Visual/Audio environment (To resume exactly as it was)
	bg_path:     string,        // Current background image
	music_path:  string,        // Current playing music
	
	// Textbox state
	speaker:      string,
	textbox_text: string,        
	textbox_vis:  bool,

	// Active characters
	characters:   [dynamic]Character_Save_State,
}

// Prepare a fresh save struct
save_state_init :: proc() -> Save_State {
	return Save_State{
		version   = STHITI_VERSION,
		variables = make(map[string]Variable),
	}
}

// Clean up memory used by a save struct
save_state_destroy :: proc(s: ^Save_State) {
	delete(s.script_path)
	delete(s.bg_path)
	delete(s.music_path)
	delete(s.speaker)
	delete(s.textbox_text)
	for k, v in s.variables {
		delete(k)
		if str, ok := v.(string); ok do delete(str)
	}
	delete(s.variables)

	for c in s.characters {
		delete(c.name)
		delete(c.sprite_path)
		delete(c.pos_name)
	}
	delete(s.characters)
}

// --- FILE I/O ---

save_to_file :: proc(path: string, s: Save_State) -> bool {
	data := serialize_save_state(s)
	defer delete(data)
	
	ok := os.write_entire_file(path, data)
	if !ok {
		fmt.eprintln("[sthiti] Failed to write save file:", path)
	}
	return ok
}

load_from_file :: proc(path: string) -> (s: Save_State, ok: bool) {
	data, read_ok := os.read_entire_file(path)
	if !read_ok {
		fmt.eprintln("[sthiti] Failed to read save file:", path)
		return
	}
	defer delete(data)
	
	return deserialize_save_state(data)
}
