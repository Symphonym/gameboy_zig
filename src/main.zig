const std = @import("std");
// const sf = @import("sfml.zig");
const sdl = @import("wrappers/sdl2.zig");
const zgui = @import("zgui");

const Window = @import("gui/Window.zig");
const Color = @import("gui/Color.zig");
const GameboyGUI = @import("gui/GameboyGUI.zig");

// const MemoryBank = @import("MemoryBank.zig");
// const Cpu = @import("Cpu.zig");
// const Ppu = @import("Ppu.zig");
const Gameboy = @import("gameboy/Gameboy.zig");
const Cartridge = @import("gameboy/Cartridge.zig");
// const constants = @import("constants.zig");

pub fn main() !void {

    var window = try Window.init("Gameboy", 500, 500, .{});
    defer window.deinit();
    window.desired_fps = 60;

    const image = sdl.SDL_LoadBMP("testBMP.bmp") orelse unreachable;
    defer sdl.SDL_FreeSurface(image);

    var gameboy_gui = GameboyGUI.init(window.renderer);


    const clear_color = Color.initRGBA8(48, 64, 44, 255);

    // var gameboy = Gameboy.init();
    // gameboy.initHardware();
    // defer gameboy.deinit();
    // var cartridge = try Cartridge.loadFromFile("roms/test_roms/rapid_toggle.gb");//"src/test_roms/mem_timing.gb"); //"roms/Tetris (JUE) (V1.1) [!].gb");
    // // var cartridge = try Cartridge.loadFromFile("src/test_roms/tim00.gb");//"src/test_roms/mem_timing.gb"); //"roms/Tetris (JUE) (V1.1) [!].gb");
    // defer cartridge.deinit();

    // gameboy.insertCartridge(&cartridge);

    // const gameboy_texture = sdl.SDL_CreateTexture(
    //     window.renderer,
    //     sdl.SDL_PIXELFORMAT_RGBA32,
    //     sdl.SDL_TEXTUREACCESS_STREAMING,
    //     @intCast(c_int, gameboy.getFramebuffer().getWidth()),
    //     @intCast(c_int, gameboy.getFramebuffer().getHeight())) orelse unreachable;
    // defer sdl.SDL_DestroyTexture(gameboy_texture);

    outer: while (true) {
        var event: sdl.SDL_Event = undefined;
        while (window.pollEvent(&event)) {
            switch (event.type) {
                sdl.SDL_QUIT => {
                    break :outer;
                },
                else => {},
            }
        }

        window.clear(clear_color);

        // _ = zgui.begin("WOOOOO", .{ .flags = .{ .no_scrollbar = true }});
        // zgui.image(gameboy_texture, . { .w = zgui.getWindowSize()[0], .h = zgui.getWindowSize()[1]});
        // zgui.end();

        // if (zgui.button("Setup Scene", .{})) {
        //     // Button pressed.
        // }

        try gameboy_gui.tick();

        // gameboy.ppu.?.woop = 0;
        // try gameboy.tick();
        //std.debug.print("HEYO {}\n", .{gameboy.ppu.?.woop});

        // gameboy.draw();

        // const texture_rect = sdl.SDL_Rect {
        //     .x = 0.0,
        //     .y = 0.0,
        //     .w = @intCast(c_int, gameboy.getFramebuffer().getWidth()),
        //     .h = @intCast(c_int, gameboy.getFramebuffer().getHeight()),
        // };

        // var texture_data: ?*anyopaque = undefined;
        // var texture_pitch: c_int = undefined;
        // {
        //     if (sdl.SDL_LockTexture(gameboy_texture, &texture_rect, &texture_data, &texture_pitch) == 0)
        //     {
        //         defer sdl.SDL_UnlockTexture(gameboy_texture);

        //         const byte_length = gameboy.getFramebuffer().getBufferSize();
        //         var ptr = @ptrCast([*]u8, texture_data);
        //         std.mem.copy(u8, ptr[0..byte_length], gameboy.getFramebuffer().buffer[0..byte_length]);
        //     }
        // }
        //std.mem.copy(u8, @ptrCast(**anyopaque, texture_data), @ptrCast(*anyopaque, &gameboy.getFramebuffer().buffer[0])

        window.render();
    }
}

// pub fn main() !void {

//     var gameboy = Gameboy.init();
//     gameboy.initHardware();
//     defer gameboy.deinit();
//     var cartridge = try Cartridge.loadFromFile("src/test_roms/rapid_toggle.gb");//"src/test_roms/mem_timing.gb"); //"roms/Tetris (JUE) (V1.1) [!].gb");
//     // var cartridge = try Cartridge.loadFromFile("src/test_roms/tim00.gb");//"src/test_roms/mem_timing.gb"); //"roms/Tetris (JUE) (V1.1) [!].gb");
//     defer cartridge.deinit();

//     gameboy.insertCartridge(&cartridge);

//     // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
//     const videoMode = sf.sfVideoMode { .width = @intCast(c_uint, constants.lcd_width), .height=  @intCast(c_uint, constants.lcd_height), .bitsPerPixel = @intCast(c_uint, 32)};
//     //const windowStyle = sf.sfResize | sf.sfTitlebar | sf.sfClose;
//     //_ = windowStyle;

//     const style: sf.sfUint32 = sf.sfDefaultStyle;
//     var window = sf.sfRenderWindow_create(videoMode, @ptrCast([*c]const u8, "Gameboy"), style, null) orelse unreachable;
//     sf.sfRenderWindow_setFramerateLimit(window, 60);
//     defer sf.sfRenderWindow_destroy(window);

//     const clock = sf.sfClock_create();
//     defer sf.sfClock_destroy(clock);
//     while (sf.sfRenderWindow_isOpen(window) == 1)
//     {
//         const delta_time = sf.sfTime_asSeconds(sf.sfClock_restart(clock));
//         _ = delta_time;
//         //std.debug.print("FPS: {d}\n", .{1 / delta_time});
//         var event: sf.sfEvent = undefined;
//         while (sf.sfRenderWindow_pollEvent(window, &event) == 1)
//         {
//             if (event.type == sf.sfEvtClosed)
//             {
//                 sf.sfRenderWindow_close(window);
//                 //return;
//             }
//         }
//         if (!gameboy.memory_bank.lcd_control.getFlag(.LCD_PPU_enable)) {
//             //sf.sfRenderWindow_clear(window, sf.sfColor_fromRGB(0, 255, 0));
//         }
//         sf.sfRenderWindow_clear(window, sf.sfColor_fromRGB(0, 255, 0));
//         try gameboy.tick();
//         gameboy.draw(window);
//         sf.sfRenderWindow_display(window);
//     }
// }

test
{
    // _ = @import("MemoryBank.zig");
    // _ = @import("Cpu.zig");
    // _ = @import("LCDStatus.zig");
    // _ = @import("ColorPalette.zig");
    // _ = @import("Interrupt.zig");
    // _ = @import("Timer.zig");
}
