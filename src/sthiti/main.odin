package sthiti

import "core:fmt"
import "core:time"
import "core:mem"
import "core:strings"

main :: proc() {
	// 1. Create a "Full State" like in a real game
	state := save_state_init()
	defer save_state_destroy(&state)
	
	state.timestamp   = u64(time.now()._nsec)
	state.script_path = strings.clone("assets/scripts/demo_ch2.vnef")
	state.script_ip   = 42
	state.bg_path     = strings.clone("assets/images/bedroom_night.png")
	state.music_path  = strings.clone("assets/music/hope.mp3")
	state.speaker     = strings.clone("Alice")
	state.textbox_vis = true
	
	// Variables (The heart of the story)
	state.variables["player_gold"] = 1500
	state.variables["day_count"]   = 5
	state.variables["trust_alice"] = 10
	
	fmt.println("--- Sthiti: Save/Load Test ---")
	
	// 2. Save to file
	save_path := "test.sthiti"
	if !save_to_file(save_path, state) {
		fmt.println("FAILED: Could not save file.")
		return
	}
	fmt.println("SAVED: State written to", save_path)
	
	// 3. Load from file
	loaded_state, ok := load_from_file(save_path)
	if !ok {
		fmt.println("FAILED: Could not load file.")
		return
	}
	defer save_state_destroy(&loaded_state)
	fmt.println("LOADED: State read from", save_path)
	
	// 4. Verification
	fmt.println("\n--- Verification ---")
	fmt.printf("Script:  %s (IP: %d)\n", loaded_state.script_path, loaded_state.script_ip)
	fmt.printf("Speaker: %s (Visible: %v)\n", loaded_state.speaker, loaded_state.textbox_vis)
	fmt.printf("Gold:    %d\n", loaded_state.variables["player_gold"])
	
	if loaded_state.script_ip == 42 && loaded_state.variables["player_gold"] == 1500 {
		fmt.println("\nSUCCESS: Data is correct.")
	} else {
		fmt.println("\nFAILED: Data mismatch.")
	}
}
