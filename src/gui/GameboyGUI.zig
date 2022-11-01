const std = @import("std");
const zgui = @import("zgui");
const nfd = @import("nfd");
const sdl = @import("../wrappers/sdl2.zig");

const Gameboy = @import("../gameboy/Gameboy.zig");
const Cartridge = @import("../gameboy/Cartridge.zig");

const Self = @This();

gameboy: ?Gameboy = null,
cartridge: ?Cartridge = null,

renderer: *sdl.SDL_Renderer,
gameboy_screen: ?*sdl.SDL_Texture = null,


pub fn init(renderer: *sdl.SDL_Renderer) Self {
    return .{
        .renderer = renderer,
    };
}

pub fn deinit(self: *Self) void {
    if (self.gameboy) |gameboy| {
        gameboy.deinit();
    }

    if (self.cartridge) |cartridge| {
        cartridge.deinit();
    }

    sdl.SDL_DestroyTexture(self.gameboy_texture);
}

pub fn tick(self: *Self) !void {
    var open = false;
    zgui.showDemoWindow(&open);

    if (self.gameboy) |*gameboy| {
        try gameboy.tick();

        var texture_data: ?*anyopaque = undefined;
        var texture_pitch: c_int = undefined;
        {
            const texture_rect = sdl.SDL_Rect {
                .x = 0.0,
                .y = 0.0,
                .w = @intCast(c_int, gameboy.getFramebuffer().getWidth()),
                .h = @intCast(c_int, gameboy.getFramebuffer().getHeight()),
            };

            if (sdl.SDL_LockTexture(self.gameboy_screen, &texture_rect, &texture_data, &texture_pitch) == 0)
            {
                defer sdl.SDL_UnlockTexture(self.gameboy_screen);

                const byte_length = gameboy.getFramebuffer().getBufferSize();
                var ptr = @ptrCast([*]u8, texture_data);
                std.mem.copy(u8, ptr[0..byte_length], gameboy.getFramebuffer().buffer[0..byte_length]);
            }
        }
    }
    

    zgui.setNextWindowSize(.{ .w = 160, .h = 144, .cond = zgui.Condition.once });
    _ = zgui.begin("Screen", .{ .flags = .{ .no_scrollbar = true }});
    if (self.gameboy_screen) |screen|{
        zgui.image(screen, . { .w = zgui.getContentRegionAvail()[0], .h = zgui.getContentRegionAvail()[1]});
    }
    zgui.end();

    self.imguiCartridgeSelect();
}

fn loadNewCartridge(self: *Self, new_cartridge: Cartridge) void {
    if (self.gameboy) |*gameboy| {
        gameboy.deinit();
        self.gameboy = null;
    }

    if (self.cartridge) |*cartridge| {
        cartridge.deinit();
        self.cartridge = null;
    }

    if (self.gameboy_screen) |*screen| {
        sdl.SDL_DestroyTexture(screen.*);
        self.gameboy_screen = null;
    }

    self.gameboy = Gameboy.init();
    self.gameboy.?.initHardware();
    self.cartridge = new_cartridge;
    self.gameboy.?.insertCartridge(&self.cartridge.?);

    self.gameboy_screen = sdl.SDL_CreateTexture(
        self.renderer,
        sdl.SDL_PIXELFORMAT_RGBA32,
        sdl.SDL_TEXTUREACCESS_STREAMING,
        @intCast(c_int, self.gameboy.?.getFramebuffer().getWidth()),
        @intCast(c_int, self.gameboy.?.getFramebuffer().getHeight())) orelse unreachable;
}

fn imguiCartridgeSelect(self: *Self) void {

    _= zgui.begin("Cartridge", .{ .flags = .{.no_resize = true, .always_auto_resize = true} });

    var exe_path: [250]u8 = undefined;
    var adjusted_exe_path = std.fs.selfExeDirPath(exe_path[0..]) catch unreachable;

    exe_path[adjusted_exe_path.len] = 0;
    if (zgui.button("Open ROM", .{})) {
        var rom_path = nfd.openFileDialog(null, exe_path[0..adjusted_exe_path.len:0]) catch unreachable;
        if (rom_path) |val| {

            if (Cartridge.loadFromFile(val)) |*cartridge| {
                self.loadNewCartridge(cartridge.*);
            } else |_| {}
        }
    }

    if (self.cartridge) |cartridge| {

        zgui.textColored(.{ 0.0, 1.0, 0.0, 1.0 }, "Cartridge: {s}", .{cartridge.title});

        const mbc_name = switch(cartridge.mbc) {
            inline else => | val | @typeName(@TypeOf(val)),
        };
        zgui.text("MBC: {s}", .{mbc_name});
        zgui.text("ROM Bank count: {}", .{cartridge.rom_bank_count});
        zgui.text("RAM Bank count: {}", .{cartridge.ram_bank_count});
    }

    zgui.end();
}
