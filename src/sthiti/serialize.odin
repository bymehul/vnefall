package sthiti

import "core:os"
import "core:bytes"
import "core:encoding/endian"
import "core:strings"

// Variable type tags
VAR_TYPE_INT    :: 0
VAR_TYPE_STRING :: 1

// Serializes the Save_State into a byte buffer
serialize_save_state :: proc(s: Save_State) -> []u8 {
	buf: [dynamic]u8
	
	// 1. Header
	for b in STHITI_MAGIC do append(&buf, u8(b))
	append_u32(&buf, s.version)
	append_u64(&buf, s.timestamp)
	
	// 2. Paths (Length-prefixed strings)
	append_string(&buf, s.script_path)
	append_i32(&buf, s.script_ip)
	append_string(&buf, s.bg_path)
	append_string(&buf, s.music_path)
	append_string(&buf, s.speaker)
	append_string(&buf, s.textbox_text)
	append_bool(&buf, s.textbox_vis)
	
	// 3. Variables (with type tags)
	append_u32(&buf, u32(len(s.variables)))
	for k, v in s.variables {
		append_string(&buf, k)
		switch val in v {
		case i32:
			append(&buf, VAR_TYPE_INT)
			append_i32(&buf, val)
		case string:
			append(&buf, VAR_TYPE_STRING)
		}
	}
	
	// 4. Characters (v4)
	if s.version >= 4 {
		append_u32(&buf, u32(len(s.characters)))
		for c in s.characters {
			append_string(&buf, c.name)
			append_string(&buf, c.sprite_path)
			append_string(&buf, c.pos_name)
			append_i32(&buf, c.z)
		}
	}
	
	return buf[:]
}

// Helpers for binary writing
append_u32 :: proc(b: ^[dynamic]u8, val: u32) {
	data: [4]u8
	endian.put_u32(data[:], .Little, val)
	for d in data do append(b, d)
}

append_u64 :: proc(b: ^[dynamic]u8, val: u64) {
	data: [8]u8
	endian.put_u64(data[:], .Little, val)
	for d in data do append(b, d)
}

append_i32 :: proc(b: ^[dynamic]u8, val: i32) {
	data: [4]u8
	endian.put_i32(data[:], .Little, val)
	for d in data do append(b, d)
}

append_bool :: proc(b: ^[dynamic]u8, val: bool) {
	append(b, val ? 1 : 0)
}

append_string :: proc(b: ^[dynamic]u8, s: string) {
	append_u32(b, u32(len(s)))
	for char in s do append(b, u8(char))
}

// --- DESERIALIZATION ---

deserialize_save_state :: proc(data: []u8) -> (s: Save_State, ok: bool) {
	// 1. Check Magic
	ptr := 0
	magic_len := len(STHITI_MAGIC)
	if len(data) < magic_len do return
	
	magic := string(data[ptr : ptr + magic_len])
	if magic != STHITI_MAGIC do return
	ptr += magic_len
	
	s.version = read_u32(data, &ptr)
	s.timestamp = read_u64(data, &ptr)
	
	// 2. Paths
	s.script_path = read_string(data, &ptr)
	s.script_ip = read_i32(data, &ptr)
	s.bg_path = read_string(data, &ptr)
	s.music_path = read_string(data, &ptr)
	s.speaker = read_string(data, &ptr)
	s.textbox_text = read_string(data, &ptr)
	s.textbox_vis = read_bool(data, &ptr)
	
	// 3. Variables
	s.variables = make(map[string]Variable)
	var_count := read_u32(data, &ptr)
	for _ in 0..<var_count {
		k := read_string(data, &ptr)
		type_tag := data[ptr]
		ptr += 1
		
		switch type_tag {
		case VAR_TYPE_INT:
			v := read_i32(data, &ptr)
			s.variables[k] = v
		case VAR_TYPE_STRING:
			v := read_string(data, &ptr)
			s.variables[k] = v
		}
	}
	
	// 4. Characters (v4)
	if s.version >= 4 {
		char_count := read_u32(data, &ptr)
		s.characters = make([dynamic]Character_Save_State)
		for _ in 0..<char_count {
			c: Character_Save_State
			c.name = read_string(data, &ptr)
			c.sprite_path = read_string(data, &ptr)
			c.pos_name = read_string(data, &ptr)
			c.z = read_i32(data, &ptr)
			append(&s.characters, c)
		}
	}
	
	return s, true
}

// Helpers for binary reading
read_u32 :: proc(b: []u8, ptr: ^int) -> u32 {
	val, _ := endian.get_u32(b[ptr^ : ptr^ + 4], .Little)
	ptr^ += 4
	return val
}

read_u64 :: proc(b: []u8, ptr: ^int) -> u64 {
	val, _ := endian.get_u64(b[ptr^ : ptr^ + 8], .Little)
	ptr^ += 8
	return val
}

read_i32 :: proc(b: []u8, ptr: ^int) -> i32 {
	val, _ := endian.get_i32(b[ptr^ : ptr^ + 4], .Little)
	ptr^ += 4
	return val
}

read_bool :: proc(b: []u8, ptr: ^int) -> bool {
	val := b[ptr^] != 0
	ptr^ += 1
	return val
}

read_string :: proc(b: []u8, ptr: ^int) -> string {
	length := int(read_u32(b, ptr))
	if length == 0 do return ""
	
	str := string(b[ptr^ : ptr^ + length])
	ptr^ += length
	return strings.clone(str)
}
