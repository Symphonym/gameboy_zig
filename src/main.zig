const std = @import("std");
const sf = @import("sfml.zig");

const MemoryBank = @import("MemoryBank.zig");
const Cpu = @import("Cpu.zig");
const Ppu = @import("Ppu.zig");
const Gameboy = @import("Gameboy.zig");
const Cartridge = @import("Cartridge.zig");
const constants = @import("constants.zig");

pub fn main() !void {

    var gameboy = Gameboy.init();
    gameboy.initHardware();
    defer gameboy.deinit();

    //var cartridge = try Cartridge.loadFromFile("src/test_roms/02-interrupts.gb");//"src/test_roms/mem_timing.gb"); //"roms/Tetris (JUE) (V1.1) [!].gb");
    var cartridge = try Cartridge.loadFromFile("src/test_roms/intr_timing.gb");//"src/test_roms/mem_timing.gb"); //"roms/Tetris (JUE) (V1.1) [!].gb");
    defer cartridge.deinit();

    gameboy.insertCartridge(&cartridge);

    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    const videoMode = sf.sfVideoMode { .width = @intCast(c_uint, constants.lcd_width), .height=  @intCast(c_uint, constants.lcd_height), .bitsPerPixel = @intCast(c_uint, 32)};
    //const windowStyle = sf.sfResize | sf.sfTitlebar | sf.sfClose;
    //_ = windowStyle;

    const style: sf.sfUint32 = sf.sfDefaultStyle;
    var window = sf.sfRenderWindow_create(videoMode, @ptrCast([*c]const u8, "Gameboy"), style, null) orelse unreachable;
    sf.sfRenderWindow_setFramerateLimit(window, 60);
    defer sf.sfRenderWindow_destroy(window);

    const clock = sf.sfClock_create();
    defer sf.sfClock_destroy(clock);
    while (sf.sfRenderWindow_isOpen(window) == 1)
    {
        const delta_time = sf.sfTime_asSeconds(sf.sfClock_restart(clock));
        _ = delta_time;
        //std.debug.print("FPS: {d}\n", .{1 / delta_time});
        var event: sf.sfEvent = undefined;
        while (sf.sfRenderWindow_pollEvent(window, &event) == 1)
        {
            if (event.type == sf.sfEvtClosed)
            {
                sf.sfRenderWindow_close(window);
                //return;
            }
        }
        if (!gameboy.memory_bank.lcd_control.getFlag(.LCD_PPU_enable)) {
            //sf.sfRenderWindow_clear(window, sf.sfColor_fromRGB(0, 255, 0));
        }
        sf.sfRenderWindow_clear(window, sf.sfColor_fromRGB(0, 255, 0));
        try gameboy.tick();
        gameboy.draw(window);
        sf.sfRenderWindow_display(window);
    }
}

test
{
    _ = @import("MemoryBank.zig");
    _ = @import("Cpu.zig");
    _ = @import("LCDStatus.zig");
    _ = @import("ColorPalette.zig");
    _ = @import("Interrupt.zig");
}
