const std = @import("std");
const math = std.math;
const c = @cImport(@cInclude("SDL.h"));
const ci = @cImport(@cInclude("SDL_image.h"));
const GAME = error{ INIT, OUT };
const vect2D = struct {
    x: f32,
    y: f32,
};
const raycast_result=struct { 
    distance: f32,
    is_lateral_wall: bool,
    sprite_perc:f32
};
var screen: *c.SDL_Window = undefined;
var surface: *c.SDL_Surface = undefined;
var texture:*ci.SDL_Surface=undefined;
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
const fps=100.0;
fn draw_surface(surf : *c.SDL_Surface,h:c_int,w:c_int,x:c_int,y:c_int,color:c.Uint32) void{
    var tempX:usize=0;
    var tempY:usize=0;
    var _x=x;
    var _y=y;
    if (_x<0){
        _x=0;
    }
    if (_y<0){
        _y=0;
    }
    for (0..@intCast(h))|ih|{
        for (0..@intCast(w))|iw|{
            tempX=@as(usize, @intCast(_x))+iw;
            tempY=(@as(usize, @intCast(_y))+ih)*WIDTH;
            const pixels_ptr: [*]u32 = @alignCast( @ptrCast(surf.pixels.?));
            if (tempX + tempY >= WIDTH*HEIGHT){
                return ;
            }
            pixels_ptr[tempY+tempX]=color;
        }
    }
}
fn draw_texture(surf : *c.SDL_Surface,h:c_int,w:c_int,x:c_int,y:c_int,perc_wall:f32,perc_shadow:u8) !void{
    var tempX:usize=0;
    var tempY:usize=0;
    var tempX_texture:usize=0;
    var tempY_texture:usize=0;
    var _x=x;
    var _y=y;
    if (_x<0){
        _x=0;
    }
    if (_y<0){
        _y=0;
    }
    const pixels_ptr: [*]u32 = @alignCast( @ptrCast(surf.pixels.?));
    const pixels_text: [*]u8 = @alignCast( @ptrCast(texture.pixels.?));
    tempX_texture=@intFromFloat(perc_wall*@as(f32,@floatFromInt(texture.w)));

    var colors=(try std.heap.c_allocator.alloc(c.Uint8, 3));
    defer std.heap.c_allocator.free(colors);
    for (0..@intCast(h))|ih|{
        tempY_texture=@divFloor(ih*@as(usize,@intCast(texture.h)),@as(usize, @intCast(h)))*@as(usize,@intCast(texture.w));
        for (0..@intCast(w))|iw|{
            tempX=@as(usize, @intCast(_x))+iw;
            tempY=(ih+@as(usize,@intCast(_y)))*WIDTH;


            if (tempX + tempY >= WIDTH*HEIGHT){
                return ;
            }
            pixels_ptr[tempY+tempX]=pixels_text[tempY_texture+tempX_texture];
            c.SDL_GetRGB(pixels_ptr[tempY+tempX], surface.format, &colors[0], &colors[1], &colors[2]);
            for (0..,colors) |i,col|{
                if (perc_shadow>col){
                    colors[i]=0;
                    continue;
                }
                colors[i]-=perc_shadow;
            }
            pixels_ptr[tempX+tempY]=c.SDL_MapRGB(surface.format, colors[0], colors[1], colors[2]);
        }
    }
}
pub fn main() !void {
    if (c.SDL_Init(c.SDL_INIT_VIDEO) < 0) {
        return GAME.INIT;
    }
    if (ci.SDL_Init(ci.IMG_INIT_PNG) < 0) {
        return GAME.INIT;
    }
    defer c.SDL_Quit();
    screen = c.SDL_CreateWindow("Ray Cast", 10, 10, WIDTH, HEIGHT, c.SDL_WINDOW_OPENGL) orelse return GAME.INIT;
    surface = c.SDL_GetWindowSurface(screen);
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
    var now_thick: u32 = 0;
    var before_tick: u32 = 0;
    const angle_speed = 1.8;
    const move_speed = 0.05;
    var x:c_int=0;
    texture=ci.IMG_Load("./wall.png") orelse return GAME.INIT;
    var sin_char:f32=undefined;
    var cos_char:f32=undefined;
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
        now_thick = c.SDL_GetTicks();
        const delta = now_thick - before_tick;
        if ((delta < @as(u32, @divFloor(1000.0,fps)))) {
            c.SDL_Delay(@as(u32, @divFloor(1000.0,fps))-delta);
            continue;
        }
        before_tick = now_thick;
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
        sin_char=math.sin(angle_camera * (math.pi / 180.0));
        cos_char=math.cos(angle_camera * (math.pi / 180.0));
        if (keyboard[c.SDL_SCANCODE_DOWN] == 1) {
            pos.y -= sin_char * move_speed;
            pos.x -= cos_char * move_speed;
            if (map[@as(usize,@intFromFloat(pos.x))][@as(usize,@intFromFloat(pos.y))]){
                pos.y += sin_char * move_speed;
                pos.x += cos_char * move_speed;
            }
        }
        if (keyboard[c.SDL_SCANCODE_UP] == 1) {
            pos.y += sin_char * move_speed;
            pos.x += cos_char * move_speed;
            if (map[@as(usize,@intFromFloat(pos.x))][@as(usize,@intFromFloat(pos.y))]){
                pos.y -= sin_char * move_speed;
                pos.x -= cos_char * move_speed;
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
        while (x<WIDTH):(x+=1) {
            var r = get_dist_raycast(pos, angle_diff + angle + angle_p);
            r.distance *= math.pow(f32, math.sin((angle + angle_diff) * (math.pi / 180.0)), 0.7);
            try draw(@intCast(x), r);
            angle += incr_angle;
        }
        x=0;
        angle = 0;
        //apply surface
        _=c.SDL_UpdateWindowSurface(screen);
    }
}
fn draw_env() void {
    draw_surface(surface,@divFloor(HEIGHT, 2),WIDTH,0,0,c.SDL_MapRGB(surface.format,0, 191, 255));
    draw_surface(surface,@divFloor(HEIGHT, 2),WIDTH,0,@divFloor(HEIGHT, 2),c.SDL_MapRGB(surface.format,150, 150, 150));
}

fn draw(x: c_int, raycast:raycast_result) !void {
    var y_to_fill: c_int = undefined;
    if (math.round(raycast.distance) == 0) {
        y_to_fill = HEIGHT;
    } else {
        y_to_fill = @intFromFloat(@divFloor(HEIGHT, raycast.distance));
    }
    const y_empty = @divFloor(HEIGHT - y_to_fill, 2);
    try draw_texture(surface, y_to_fill, 1, x, y_empty,raycast.sprite_perc,@intFromFloat(raycast.distance * 10.0));

    var i_c: c.Uint8 = 0;
    var colors=(try std.heap.c_allocator.alloc(c.Uint8, 3));
    defer std.heap.c_allocator.free(colors);
    for (@intCast(y_empty+y_to_fill-10)..@intCast(y_empty+y_to_fill))|ih|{
        i_c+=10;
        const tempX=@as(usize, @intCast(x));
        const tempY=(ih)*WIDTH;
        const pixels_ptr: [*]u32 = @alignCast( @ptrCast(surface.pixels.?));
        c.SDL_GetRGB(pixels_ptr[tempY+tempX], surface.format, &colors[0], &colors[1], &colors[2]);
        for (0..,colors) |i,col|{
            if (i_c>col){
                colors[i]=0;
                continue;
            }
            colors[i]-=i_c;
        }
        pixels_ptr[tempX+tempY]=c.SDL_MapRGB(surface.format, colors[0], colors[1], colors[2]);
    }
}
fn get_dist_raycast(origin: vect2D, angle: f32) raycast_result {
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
    var is_lateral_wall = false;
    x += cos * 0.01;
    const x_right: usize = @intFromFloat(x);
    x -= cos * 0.01;
    x -= cos * 0.01;
    const x_left: usize = @intFromFloat(x);

    y += sin * 0.01;
    const y_forward: usize = @intFromFloat(y);
    y -= sin * 0.01;
    y -= sin * 0.01;
    const y_back: usize = @intFromFloat(y);

    var sprite_perc:f32=0;

    if (map[x_right][y_i] and !map[x_left][y_i]) {//right wall
        is_lateral_wall = true;
        sprite_perc=y-@as(f32,@floatFromInt(y_i));
    }
    if (!map[x_right][y_i] and map[x_left][y_i]) {//left wall
        is_lateral_wall = true;
        sprite_perc=y-@as(f32,@floatFromInt(y_i));
    }

    if (map[x_i][y_forward] and !map[x_i][y_back]) {//forward wall
        is_lateral_wall = true;
        sprite_perc=x-@as(f32,@floatFromInt(x_i));
    }
    if (!map[x_i][y_i] and map[x_i][y_i]) {//back wall
        is_lateral_wall = true;
        sprite_perc=x-@as(f32,@floatFromInt(x_i));
    }
    return raycast_result{
        .distance =dis,
        .is_lateral_wall =is_lateral_wall,
        .sprite_perc =sprite_perc
    };
}
