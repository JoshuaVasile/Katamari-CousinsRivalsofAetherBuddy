// update.gml - runs every frame for the Katamari buddy.

// ---------- One-time setup (self-contained so init.gml is never needed) ----------
if (!variable_instance_exists(id, "kat_ready")) {
    kat_ready = true;
    base_scale = 0.36;           // small starting ball (~18px across)
    katamari_scale = base_scale;
    target_scale = base_scale;
    cousins_collected = 0;
    pickup_sfx_idx = 0;          // rotates game33 -> game34 -> game35 on cousin pickup

    ball_rot = 0;                // degrees, true rolling angle
    ball_dir = 1;                // custom facing direction (1 = right, -1 = left)
    prev_x = x;
    prev_y = y;
    vis_x = x;                   // smoothed visual position (prevents ledge/platform snaps)
    vis_y = y;
    prev_vis_x = x;

    bounce_y = 0;
    bounce_vsp = 0;
    is_bouncing = false;
    squash_x = 1;
    squash_y = 1;

    prev_owner_free = false;
    prev_owner_vsp = 0;
    prev_owner_y = y;
    floor_diff_timer = 0;
    was_taunt = false;
    spin_boost = 0;

    plat_hopping = false;
    hop_t = 0;
    hop_dur = 18;
    hop_sx = x;
    hop_sy = y;
    hop_ex = x;
    hop_ey = y;
    hop_peak = y;

    match_frame = 0;
    spawn_seq = 1;
    next_spawn_timer = 900;      // first cousin ~15s into match

    max_stage_cousins = 16;
    for (var i = 0; i < max_stage_cousins; i++) {
        stage_c_active[i] = false;
        stage_c_x[i] = 0;
        stage_c_y[i] = 0;
        stage_c_type[i] = 0;
        stage_c_timer[i] = 0;
    }

    max_attached = 36;
    att_count = 0;
    for (var j = 0; j < max_attached; j++) {
        att_active[j] = false;
        att_type[j] = 0;
        att_angle[j] = 0;
        att_dist[j] = 0.8;
    }

    max_sparkles = 8;
    for (var k = 0; k < max_sparkles; k++) {
        sparkle_active[k] = false;
        sparkle_x[k] = 0;
        sparkle_y[k] = 0;
        sparkle_timer[k] = 0;
    }
}

// Keep built-in blank buddy sprite invisible; post_draw.gml draws everything
image_alpha = 0;

// ---------- Size / radius ----------
katamari_scale = lerp(katamari_scale, target_scale, 0.12);
var kat_radius = 25 * katamari_scale;

// Keep built-in follow logic tight near ledges as the ball grows
pet_w = 10 + clamp(kat_radius * 0.25, 0, 18);
run_speed = 4.2;
max_run_dist = clamp(32 + kat_radius * 0.35, 32, 64);

// ---------- Read owning player safely via `owner` ----------
var has_owner = false;
var o_x = x;
var o_y = y;
var o_free = false;
var o_vsp = 0;
var o_dir = ball_dir;

if (variable_instance_exists(id, "owner")) {
    if (instance_exists(owner)) {
        has_owner = true;
        o_x = owner.x;
        o_y = owner.y;
        if (variable_instance_exists(owner, "free")) o_free = owner.free;
        if (variable_instance_exists(owner, "vsp")) o_vsp = owner.vsp;
        if (variable_instance_exists(owner, "spr_dir")) o_dir = owner.spr_dir;
    }
}

var blk = asset_get("par_block");
var jt = asset_get("par_jumpthrough");

// ---------- Smooth platform/ledge transitions + warp elimination ----------
var eng_dx = x - prev_x;
var eng_dy = y - prev_y;
prev_x = x;
prev_y = y;

var engine_warped = (abs(eng_dx) > 36) || (abs(eng_dy) > 20);
if (engine_warped) {
    var warp_dist = point_distance(vis_x, vis_y, x, y);
    if (warp_dist >= 340) {
        // Long distance respawn / teleport: snap cleanly
        plat_hopping = false;
        vis_x = x;
        vis_y = y;
        prev_vis_x = vis_x;
    } else if (!plat_hopping) {
        // Convert any engine platform teleport into a smooth parabolic Katamari hop
        plat_hopping = true;
        hop_t = 0;
        hop_dur = clamp(round(warp_dist / 8), 12, 22);
        hop_sx = vis_x;
        hop_sy = vis_y;
        hop_ex = x;
        hop_ey = y;
        hop_peak = min(hop_sy, hop_ey) - clamp(24 + abs(hop_ey - hop_sy) * 0.35, 22, 64);
        is_bouncing = false;
        bounce_y = 0;
        bounce_vsp = 0;
    }
}

// If the player settles on another platform or ledge level, hop cleanly onto it
if (has_owner && !plat_hopping) {
    if (!o_free && abs(o_y - y) > 24 && abs(o_y - prev_owner_y) < 2) {
        floor_diff_timer += 1;
        if (floor_diff_timer >= 10) {
            floor_diff_timer = 0;
            var follow_off = 28 + min(kat_radius, 36);
            var dest_x = o_x - follow_off * o_dir;
            var dest_y = o_y;
            var has_floor = (position_meeting(dest_x, dest_y + 2, blk) || position_meeting(dest_x, dest_y + 2, jt)) && !position_meeting(dest_x, dest_y - 8, blk);
            if (!has_floor) {
                dest_x = o_x;
            }
            var step_up = 0;
            while (step_up < 8 && (position_meeting(dest_x, dest_y - 1, blk) || position_meeting(dest_x, dest_y - 1, jt))) {
                dest_y -= 1;
                step_up += 1;
            }
            var hop_dist = point_distance(vis_x, vis_y, dest_x, dest_y);
            if (hop_dist < 340) {
                x = dest_x;
                y = dest_y;
                prev_x = x;
                prev_y = y;
                plat_hopping = true;
                hop_t = 0;
                hop_dur = clamp(round(hop_dist / 8), 14, 24);
                hop_sx = vis_x;
                hop_sy = vis_y;
                hop_ex = dest_x;
                hop_ey = dest_y;
                hop_peak = min(hop_sy, hop_ey) - clamp(26 + abs(hop_ey - hop_sy) * 0.35, 24, 68);
                is_bouncing = false;
                bounce_y = 0;
                bounce_vsp = 0;
            }
        }
    } else {
        floor_diff_timer = 0;
    }
}

if (plat_hopping) {
    hop_t += 1;
    // Track minor horizontal repositioning by pet_obj along the target floor
    if (abs(y - hop_ey) < 20 && abs(x - hop_ex) < 80) {
        hop_ex = x;
        hop_ey = y;
    }
    var u = clamp(hop_t / hop_dur, 0, 1);
    var inv = 1 - u;
    vis_x = lerp(hop_sx, hop_ex, u);
    vis_y = inv * inv * hop_sy + 2 * inv * u * hop_peak + u * u * hop_ey;
    if (u < 0.5) {
        squash_x = lerp(squash_x, 0.90, 0.25);
        squash_y = lerp(squash_y, 1.12, 0.25);
    } else {
        squash_x = lerp(squash_x, 1.04, 0.2);
        squash_y = lerp(squash_y, 0.96, 0.2);
    }
    if (hop_t >= hop_dur) {
        plat_hopping = false;
        vis_x = hop_ex;
        vis_y = hop_ey;
        squash_x = 1.16;
        squash_y = 0.84;
    }
} else {
    if (point_distance(vis_x, vis_y, x, y) > 200) {
        vis_x = x;
        vis_y = y;
    } else {
        vis_x = lerp(vis_x, x, 0.72);
        vis_y = lerp(vis_y, y, 0.38);
    }
}

// ---------- Player jump -> bounce up and down ----------
var jump_impulse = false;
var player_rising = false;
if (has_owner) {
    if (o_free && o_vsp < -1.0) player_rising = true;
    if ((o_vsp < -2.0 && prev_owner_vsp >= -1.0) || (o_free && !prev_owner_free && o_vsp < -0.5)) {
        jump_impulse = true;
    }
    prev_owner_free = o_free;
    prev_owner_vsp = o_vsp;
    prev_owner_y = o_y;
}

var hop_mult = clamp(sqrt(katamari_scale / base_scale) * 0.72, 0.85, 2.2);

if (jump_impulse && !plat_hopping) {
    if (!is_bouncing || bounce_vsp > -1.0) {
        bounce_vsp = -5.4 * hop_mult;
        is_bouncing = true;
    }
}

// Taunt: play Etc04 once per taunt, plus celebratory hop and fast spin
if (state == "taunt" && !was_taunt) {
    sound_play(sound_get("etc04"));
    spin_boost = 24;
    if (!plat_hopping && !is_bouncing) {
        bounce_vsp = -6.2 * hop_mult;
        is_bouncing = true;
    }
}
was_taunt = (state == "taunt");
if (spin_boost > 0) spin_boost -= 1;

if (is_bouncing && !plat_hopping) {
    bounce_y += bounce_vsp;
    bounce_vsp += 0.38 * hop_mult;
    if (bounce_vsp < 0) {
        squash_y = lerp(squash_y, 1.14, 0.25);
        squash_x = lerp(squash_x, 0.90, 0.25);
    } else {
        squash_y = lerp(squash_y, 0.95, 0.2);
        squash_x = lerp(squash_x, 1.05, 0.2);
    }
    if (bounce_y >= 0) {
        bounce_y = 0;
        bounce_vsp = 0;
        is_bouncing = false;
        squash_y = 0.84;
        squash_x = 1.16;
        // Stay bouncy while the player is still rising in mid-air
        if (player_rising) {
            bounce_vsp = -3.6 * hop_mult;
            is_bouncing = true;
        }
    }
} else if (!plat_hopping) {
    squash_x = lerp(squash_x, 1, 0.2);
    squash_y = lerp(squash_y, 1, 0.2);
}

// ---------- True rolling rotation from visual distance travelled ----------
var vis_dx = vis_x - prev_vis_x;
prev_vis_x = vis_x;
if (abs(vis_dx) > 150) vis_dx = 0;

ball_rot -= (vis_dx / max(kat_radius, 5)) * 57.2958;
if (vis_dx > 0.08) ball_dir = 1;
else if (vis_dx < -0.08) ball_dir = -1;

if (spin_boost > 0) ball_rot -= spin_boost * 0.65 * ball_dir;
if (is_bouncing && abs(vis_dx) < 0.08) ball_rot -= 3.5 * ball_dir;
if (!is_bouncing && !plat_hopping && abs(vis_dx) < 0.05) {
    ball_rot += sin(match_frame * 0.07) * 0.16;
}
while (ball_rot >= 360) ball_rot -= 360;
while (ball_rot < 0) ball_rot += 360;

// ---------- Match timer & Cousin spawning ----------
match_frame += 1;

if (match_frame >= next_spawn_timer) {
    var stg_x = get_stage_data(SD_X_POS);
    var stg_y = get_stage_data(SD_Y_POS);
    var stg_w = get_stage_data(SD_WIDTH);

    var min_sx = stg_x + 24;
    var max_sx = stg_x + stg_w - 24;
    if (stg_w <= 60 || max_sx <= min_sx) {
        min_sx = o_x - 320;
        max_sx = o_x + 320;
        stg_y = o_y;
    }
    var span_x = max(2, round(max_sx - min_sx));

    var found = false;
    var sx = 0;
    var sy = 0;
    var tries = 0;

    while (!found && tries < 18) {
        var r_idx = (match_frame + spawn_seq * 31 + tries * 17) mod 200;
        var cand_x = min_sx + random_func_2(r_idx, span_x, true);

        // Alternate scanning from high above platforms vs just above main floor
        var scan_top = min(stg_y, o_y) - 240;
        var steps = 200;
        if ((tries mod 2) == 1 && !position_meeting(cand_x, stg_y - 28, blk)) {
            scan_top = stg_y - 28;
            steps = 45;
        }

        for (var d = 0; d < steps; d++) {
            var py = scan_top + d * 3;
            if (position_meeting(cand_x, py, blk) || position_meeting(cand_x, py, jt)) {
                var stable_footing = (position_meeting(cand_x - 6, py + 4, blk) || position_meeting(cand_x - 6, py + 4, jt)) && (position_meeting(cand_x + 6, py + 4, blk) || position_meeting(cand_x + 6, py + 4, jt));
                if (stable_footing && !position_meeting(cand_x, py - 12, blk)) {
                    // Refine surface top 1px at a time so cousin stands flush on ground
                    var refine = 0;
                    while (refine < 3 && (position_meeting(cand_x, py - 1, blk) || position_meeting(cand_x, py - 1, jt))) {
                        py -= 1;
                        refine += 1;
                    }
                    // Keep outside Katamari early on; allow spawning at huge ball sizes too
                    var min_kat_clear = 20;
                    if (tries < 14) {
                        min_kat_clear = min(kat_radius + 28, 120);
                    }
                    var clear_of_kat = point_distance(cand_x, py - 8, vis_x, vis_y + bounce_y - kat_radius) >= min_kat_clear;
                    var clear_of_own = (!has_owner) || (point_distance(cand_x, py, o_x, o_y) >= 44);
                    if (clear_of_kat && clear_of_own) {
                        found = true;
                        sx = cand_x;
                        sy = py;
                    }
                }
                d = 9999;
            }
        }
        tries += 1;
    }

    spawn_seq += 1;
    if (found) {
        var slot = -1;
        for (var s = 0; s < max_stage_cousins; s++) {
            if (slot == -1 && !stage_c_active[s]) slot = s;
        }
        if (slot != -1) {
            var c_idx = (match_frame + spawn_seq * 43) mod 200;
            stage_c_active[slot] = true;
            stage_c_x[slot] = sx;
            stage_c_y[slot] = sy;
            stage_c_type[slot] = clamp(random_func_2(c_idx, 46, true), 0, 45);
            stage_c_timer[slot] = random_func_2((c_idx + 7) mod 200, 24, true);
        }
        var d_idx = (match_frame + spawn_seq * 19) mod 200;
        next_spawn_timer = match_frame + 1200 + random_func_2(d_idx, 601, true); // 20-30s
    } else {
        // Retry quickly if no valid platform/floor candidate matched this cycle
        next_spawn_timer = match_frame + 90;
    }
}

// ---------- Collision: Katamari rolls up Cousins & grows ----------
var kat_cx = vis_x;
var kat_cy = vis_y + bounce_y - kat_radius;

for (var c = 0; c < max_stage_cousins; c++) {
    if (stage_c_active[c]) {
        stage_c_timer[c] += 1;
        var c_cx = stage_c_x[c];
        var c_cy = stage_c_y[c] - 9;
        if (point_distance(kat_cx, kat_cy, c_cx, c_cy) < kat_radius + 13) {
            stage_c_active[c] = false;
            cousins_collected += 1;

            // +3% per cousin up to 60, then steady linear climb so ~1000 covers the stage
            if (cousins_collected <= 60) {
                target_scale = target_scale * 1.03;
            } else {
                target_scale = target_scale + 0.028;
            }

            if (pickup_sfx_idx == 0) {
                sound_play(sound_get("game33"));
            } else if (pickup_sfx_idx == 1) {
                sound_play(sound_get("game34"));
            } else {
                sound_play(sound_get("game35"));
            }
            pickup_sfx_idx = (pickup_sfx_idx + 1) mod 3;

            for (var sp = 0; sp < max_sparkles; sp++) {
                if (!sparkle_active[sp]) {
                    sparkle_active[sp] = true;
                    sparkle_x[sp] = c_cx;
                    sparkle_y[sp] = c_cy;
                    sparkle_timer[sp] = 0;
                    sp = 9999;
                }
            }

            var a_slot = 0;
            if (att_count < max_attached) {
                a_slot = att_count;
                att_count += 1;
            } else {
                var a_idx = (match_frame + cousins_collected * 11) mod 200;
                a_slot = random_func_2(a_idx, max_attached, true);
            }
            var d_rnd = (match_frame + cousins_collected * 29) mod 200;
            att_active[a_slot] = true;
            att_type[a_slot] = stage_c_type[c];
            att_angle[a_slot] = point_direction(kat_cx, kat_cy, c_cx, c_cy) - ball_rot;
            att_dist[a_slot] = 0.72 + random_func_2(d_rnd, 20, false) / 100;
        }
    }
}

// ---------- Sparkle animations ----------
for (var sk = 0; sk < max_sparkles; sk++) {
    if (sparkle_active[sk]) {
        sparkle_timer[sk] += 1;
        if (sparkle_timer[sk] >= 18) sparkle_active[sk] = false;
    }
}
