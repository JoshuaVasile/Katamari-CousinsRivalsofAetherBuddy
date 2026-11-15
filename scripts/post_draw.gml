// post_draw.gml - draws waiting cousins, the rolling Katamari, attached cousins, sparkles.

if (!variable_instance_exists(id, "kat_ready")) exit;

var kat_radius = 25 * katamari_scale;
var ball_y = vis_y + bounce_y - kat_radius;

// Cousins waiting on the stage (always keep their clean, fixed small size)
for (var s = 0; s < max_stage_cousins; s++) {
    if (stage_c_active[s]) {
        var cx = stage_c_x[s];
        var cy = stage_c_y[s];
        draw_sprite_ext(sprite_get("shadow"), 0, cx, cy, 0.5, 0.35, 0, c_white, 0.5);
        var step4 = floor(stage_c_timer[s] / 12) mod 4;
        var anim_f = 2;
        if (step4 == 1) anim_f = 0;
        else if (step4 == 3) anim_f = 1;
        draw_sprite_ext(sprite_get("cousins"), stage_c_type[s] * 3 + anim_f, cx, cy, 1, 1, 0, c_white, 1);
    }
}

// Gradually increase translucency once very large so players stay clearly visible
var ball_alpha = clamp(1 - (katamari_scale - 2.0) * 0.075, 0.42, 1);

// Ground shadow: shrinks as the ball hops upward and softens during platform arcs
var sh_y = vis_y;
var sh_air_alpha = 1;
if (plat_hopping) {
    var u = clamp(hop_t / hop_dur, 0, 1);
    sh_y = lerp(hop_sy, hop_ey, u);
    var air_h = max(0, sh_y - vis_y);
    sh_air_alpha = clamp(1 - air_h / 120, 0.25, 1);
}
var hop_f = clamp(1 + (bounce_y - max(0, sh_y - vis_y)) / 150, 0.35, 1);
draw_sprite_ext(sprite_get("shadow"), 0, vis_x, sh_y, katamari_scale * 1.45 * hop_f, katamari_scale * 0.55 * hop_f, 0, c_white, 0.55 * ball_alpha * sh_air_alpha);

// The Katamari itself: squash/stretch in screen space, true rolling rotation
draw_sprite_ext(sprite_get("ball"), 0, vis_x, ball_y, katamari_scale * squash_x, katamari_scale * squash_y, ball_rot, c_white, ball_alpha);

// Rolled-up cousins stuck to the surface, rotating around the ball center
for (var j = 0; j < max_attached; j++) {
    if (att_active[j]) {
        var ang = att_angle[j] + ball_rot;
        var dist = kat_radius * att_dist[j];
        var px = vis_x + lengthdir_x(dist, ang);
        var py = ball_y + lengthdir_y(dist, ang);
        draw_sprite_ext(sprite_get("cousins"), att_type[j] * 3 + 2, px, py, 0.62, 0.62, ang - 90, c_white, ball_alpha);
    }
}

// Pickup sparkles (6-frame pixel starburst)
for (var k = 0; k < max_sparkles; k++) {
    if (sparkle_active[k]) {
        var sp_frame = floor(sparkle_timer[k] / 3);
        if (sp_frame >= 0 && sp_frame < 6) {
            draw_sprite_ext(sprite_get("sparkle"), sp_frame, sparkle_x[k], sparkle_y[k], 1, 1, 0, c_white, 1);
        }
    }
}
