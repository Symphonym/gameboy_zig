const std = @import("std");
const sf = @import("sfml.zig");

const MemoryBank = @import("MemoryBank.zig");
const Cpu = @import("Cpu.zig");
const Ppu = @import("Ppu.zig");

pub fn main() !void {

    var memory_bank = MemoryBank {};
    var cpu = Cpu.init(&memory_bank);
    var ppu = Ppu.init(&memory_bank);

    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});
    const videoMode = sf.sfVideoMode { .width = @intCast(c_uint, 160), .height=  @intCast(c_uint, 144), .bitsPerPixel = @intCast(c_uint, 32)};
    //const windowStyle = sf.sfResize | sf.sfTitlebar | sf.sfClose;
    //_ = windowStyle;

    const style: sf.sfUint32 = sf.sfDefaultStyle;
    var window = sf.sfRenderWindow_create(videoMode, @ptrCast([*c]const u8, "SFML Works"), style, null);
    sf.sfRenderWindow_setFramerateLimit(window, 60);
    defer sf.sfRenderWindow_destroy(window);

    const clock = sf.sfClock_create();
    defer sf.sfClock_destroy(clock);
    while (sf.sfRenderWindow_isOpen(window) == 1)
    {
        const delta_time = sf.sfTime_asSeconds(sf.sfClock_restart(clock));
        _ = delta_time;

        memory_bank.tick();
        try cpu.tick();
        ppu.tick();
        

        var event: sf.sfEvent = undefined;
        while (sf.sfRenderWindow_pollEvent(window, &event) == 1)
        {
            if (event.type == sf.sfEvtClosed)
            {
                sf.sfRenderWindow_close(window);
            }
        }
        if (!memory_bank.lcd_control.getFlag(.LCD_PPU_enable)) {
            sf.sfRenderWindow_clear(window, sf.sfColor_fromRGB(0, 255, 0));
        }
        ppu.draw(window);
        sf.sfRenderWindow_display(window);
    }
}

test
{
    _ = @import("MemoryBank.zig");
    _ = @import("Cpu.zig");
    _ = @import("LCDStatus.zig");
}
