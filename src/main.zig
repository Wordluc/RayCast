const std = @import("std");
const math = std.math;
const c = @cImport(@cInclude("SDL.h"));
const GAME = error{ INIT, OUT };
const vect2D = struct {
    x: f32,
    y: f32,
};
var screen: *c.SDL_Window = undefined;
var render: *c.SDL_Renderer = undefined;
var map: [8][8]bool = [8][8]bool{
    [8]bool{ true, true, true, true, true, true, true, true },
    [8]bool{ true, false, false, false, false, false, true, true },
    [8]bool{ true, false, false, false, false, false, true, true },
    [8]bool{ true, false, false, false, true, true, true, true },
    [8]bool{ true, false, false, false, false, false, false, true },
    [8]bool{ true, false, true, false, true, true, false, true },
    [8]bool{ true, false, false, false, false, false, false, true },
    [8]bool{ true, true, true, true, true, true, true, true },
};
const WIDTH = 1000;
const HEIGHT = 600;
const size_part_wall = 3;
pub fn main() !void {
    if (c.SDL_Init(c.SDL_INIT_VIDEO) < 0) {
        return GAME.INIT;
    }
    defer c.SDL_Quit();
    screen = c.SDL_CreateWindow("Ray Cast", 10, 10, WIDTH, HEIGHT, c.SDL_WINDOW_OPENGL) orelse return GAME.INIT;
    render = c.SDL_CreateRenderer(screen, 0, 0) orelse return GAME.INIT;
    var event: c.SDL_Event = undefined;
    var quit: bool = false;
    var angle: f32 = 0;
    var pos = vect2D{
        .x = 2,
        .y = 3,
    };
    var angle_p: f32 = 0;
    var keyboard: [*c]const c.Uint8 = undefined;
    keyboard = c.SDL_GetKeyboardState(null);
    const fov = 90.0;
    const incr_angle = fov / @as(f32, @floatCast(WIDTH));
    var act_cos = false;
    const angle_diff = (180 - fov) / 2;
    var tick_after: u32 = 0;
    var tick_before: u32 = 0;
    const angle_speed = 1.8;
    const move_speed = 0.05;
    var x:c_int=0;
    while (!quit) {
        while (c.SDL_PollEvent(&event) != 0) {
            switch (event.type) {
                c.SDL_QUIT => {
                    quit = true;
                    break;
                },
                else => {},
            }
        }
        if (keyboard[c.SDL_SCANCODE_LEFT] == 1) {
            angle_p -= angle_speed;
            if (angle_p <= 0) {
                angle_p = 360 + angle_p;
            }
        }
        if (keyboard[c.SDL_SCANCODE_RIGHT] == 1) {
            angle_p += angle_speed;
            if (angle_p >= 360) {
                angle_p = 360 - angle_p;
            }
        }
        const angle_camera = angle_p + angle_diff + fov / 2;
        if (keyboard[c.SDL_SCANCODE_DOWN] == 1) {
            pos.y -= math.sin(angle_camera * (math.pi / 180.0)) * move_speed;
            pos.x -= math.cos(angle_camera * (math.pi / 180.0)) * move_speed;
            if (map[@as(usize,@intFromFloat(pos.x))][@as(usize,@intFromFloat(pos.y))]){
                pos.y += math.sin(angle_camera * (math.pi / 180.0)) * move_speed;
                pos.x += math.cos(angle_camera * (math.pi / 180.0)) * move_speed;
            }
        }
        if (keyboard[c.SDL_SCANCODE_UP] == 1) {
            pos.y += math.sin(angle_camera * (math.pi / 180.0)) * move_speed;
            pos.x += math.cos(angle_camera * (math.pi / 180.0)) * move_speed;
            if (map[@as(usize,@intFromFloat(pos.x))][@as(usize,@intFromFloat(pos.y))]){
                pos.y -= math.sin(angle_camera * (math.pi / 180.0)) * move_speed;
                pos.x -= math.cos(angle_camera * (math.pi / 180.0)) * move_speed;
            }
        }
        if (pos.x <= 1) {
            pos.x = 1;
        }
        if (pos.y <= 1) {
            pos.y = 1;
        }
        if (pos.x >= map.len) {
            pos.x = map.len - 2;
        }
        if (pos.y >= map.len) {
            pos.y = map.len - 2;
        }
        if (keyboard[c.SDL_SCANCODE_F] == 1) {
            act_cos = !act_cos;
        }
        draw_env();
        while (x<WIDTH):(x+=size_part_wall) {
            var r = get_dist_raycast(pos, angle_diff + angle + angle_p);
            r[0] *= math.pow(f32, math.sin((angle + angle_diff) * (math.pi / 180.0)), 0.7);
            draw_vertical_line(@intCast(x), r[0], r[1]);
            angle += incr_angle*size_part_wall;
        }
        x=0;
        angle = 0;
        c.SDL_RenderPresent(render);
        tick_after = c.SDL_GetTicks();
        const delta = tick_after - tick_before;
        tick_before = tick_after;
        if ((delta < @as(u32, @divFloor(1000.0, 60.0)))) {
            c.SDL_Delay(@as(c.Uint32, @divFloor(1000.0, 60.0))-delta);
        }
    }
}
fn draw_env() void {
    const floor: c.SDL_Rect = c.SDL_Rect{ .y = @divFloor(HEIGHT, 2), .x = 0, .h = @divFloor(HEIGHT, 2), .w = WIDTH };
    _ = c.SDL_SetRenderDrawColor(render, 150, 150, 150, 150);
    _ = c.SDL_RenderFillRect(render, &floor);

    const sky: c.SDL_Rect = c.SDL_Rect{ .x = 0, .y = 0, .h = @divFloor(HEIGHT, 2), .w = WIDTH };
    _ = c.SDL_SetRenderDrawColor(render, 0, 191, 255, 0);
    _ = c.SDL_RenderFillRect(render, &sky);
}

fn draw_vertical_line(x: c_int, dist: f32, is_edge: bool) void {
    var c_fix: u8 = @intFromFloat(dist * 3.0);
    if (is_edge) {
        c_fix += 5;
    }
    var y_to_fill: c_int = undefined;
    if (math.round(dist) == 0) {
        y_to_fill = HEIGHT;
    } else {
        y_to_fill = @intFromFloat(@divFloor(HEIGHT, dist));
    }
    const y_empty = @divFloor(HEIGHT - y_to_fill, 2);

    var wall_part: c.SDL_Rect = c.SDL_Rect{ .y = y_empty, .x = x, .h = y_to_fill, .w = size_part_wall };
    _ = c.SDL_SetRenderDrawColor(render, 100 - c_fix, 100 - c_fix, 100 - c_fix, 0);
    _ = c.SDL_RenderFillRect(render, &wall_part);

    var i_c: c_int = undefined;
    var color: u8 = 100 - c_fix;
    for (0..10) |i| {
        color -= 2;
        i_c = @intCast(i);
        _ = c.SDL_SetRenderDrawColor(render, color, color, color, 0);
        wall_part = c.SDL_Rect{ .y = y_to_fill + y_empty + i_c, .x = x, .h = 1, .w = size_part_wall };
        _ = c.SDL_RenderFillRect(render, &wall_part);
    }
}
fn get_dist_raycast(origin: vect2D, angle: f32) struct { f32, bool } {
    var x: f32 = origin.x;
    var y: f32 = origin.y;
    var x_i: usize = @intFromFloat(x);
    var y_i: usize = @intFromFloat(y);
    const cos = math.cos(angle * (math.pi / 180.0));
    const sin = math.sin(angle * (math.pi / 180.0));
    var dis: f32 = 0;
    while (!map[x_i][y_i]) {
        x += cos * 0.01;
        y += sin * 0.01;
        x_i = @intFromFloat(x);
        y_i = @intFromFloat(y);
        dis += 0.01;
    }
    var is_edge = false;
    x += cos * 0.01;
    const x_right: usize = @intFromFloat(x);
    x -= cos * 0.01;
    x -= cos * 0.01;
    const x_left: usize = @intFromFloat(x);
    if (map[x_right][y_i] and !map[x_left][y_i]) {
        is_edge = true;
    }
    if (!map[x_right][y_i] and map[x_left][y_i]) {
        is_edge = true;
    }
    //dis-=(1-math.sqrt(math.pow(f32, cot, 2) + 1));
    return .{ dis, is_edge };
}
