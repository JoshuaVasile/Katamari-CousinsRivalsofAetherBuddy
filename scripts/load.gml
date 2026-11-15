// load.gml - runs once when the Katamari buddy is loaded.

// The built-in state sprites are blank 2x2 placeholders. Everything visible is drawn
// manually in post_draw.gml so scaling / rolling can't be overridden by the engine.
sprite_change_offset("idle",  0, 0);
sprite_change_offset("wait",  0, 0);
sprite_change_offset("run",   0, 0);
sprite_change_offset("turn",  0, 0);
sprite_change_offset("ledge", 0, 0);
sprite_change_offset("taunt", 0, 0);

// Custom art
sprite_change_offset("ball",    27, 27);  // 54x54, centered so rotation pivots on the ball center
sprite_change_offset("cousins", 16, 31);  // 32x32 frames, feet at bottom center
sprite_change_offset("shadow",  16, 6);
sprite_change_offset("sparkle", 16, 16);

// Buddy behavior
type = 0;
can_switch_type = false;
pet_w = 10;
run_speed = 4;
max_run_dist = 36;
