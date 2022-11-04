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
        try gameboy_gui.tick();
        window.render();
    }
}

test
{
    // _ = @import("MemoryBank.zig");
    // _ = @import("Cpu.zig");
    // _ = @import("LCDStatus.zig");
    // _ = @import("ColorPalette.zig");
    // _ = @import("Interrupt.zig");
    // _ = @import("Timer.zig");
}
