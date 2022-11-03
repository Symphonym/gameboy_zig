const std = @import("std");
const zgui = @import("zgui");
const nfd = @import("nfd");
const sdl = @import("../wrappers/sdl2.zig");

const Gameboy = @import("../gameboy/Gameboy.zig");
const Cartridge = @import("../gameboy/Cartridge.zig");

const Self = @This();

const GUIState = struct {
    memory_min_address: u16 = 0xC000,
    memory_max_address: u16 = 0xDFFF,
    hovered_address: ?u16 = null,
};

gameboy: ?Gameboy = null,
cartridge: ?Cartridge = null,

renderer: *sdl.SDL_Renderer,
gameboy_screen: ?*sdl.SDL_Texture = null,

gui_state: GUIState = .{},


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

    try self.imguiMemory();
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

fn imguiMemory(self: *Self) !void {
    
    if (self.gameboy) |*gameboy| {
        
        zgui.setNextWindowSize(.{ .w = 600, .h = 600 });
        _= zgui.begin("Memory", .{ .flags = .{ .no_resize = true } });
        
        if (zgui.beginChild("##memory_view", .{ .h = 420 })) {
            var i: u16 = self.gui_state.memory_min_address;
            while (i <= self.gui_state.memory_max_address -| 16) : (i +|= 16) {
                zgui.textColored(.{ 0.0, 1.0, 0.0, 1.0 }, "{X:0>4}: ", .{i});

                var byte_index: u8 = 0;
                while (byte_index < 16 and i + byte_index < 0xFFFF) : (byte_index += 1) {
                    zgui.sameLine(.{});
                    if (byte_index % 8 == 0) {
                        zgui.text("  ", .{});
                        zgui.sameLine(.{});
                    } 

                    const byte = try gameboy.memory_bank.read(u8, i + byte_index);
                    var color: [4]f32 = if (byte == 0) .{0.5, 0.5, 0.5, 1.0 } else .{ 1.0, 1.0, 1.0, 1.0 };
                    if (self.gui_state.hovered_address == i + byte_index) {
                        color = .{ 1.0, 0.0, 0.0, 1.0 };
                    }

                    zgui.textColored(color, "{X:0>2}", .{byte});
                    if (zgui.isItemHovered(.{})) {
                        self.gui_state.hovered_address = i + byte_index;
                    }
                }

                byte_index = 0;
                while (byte_index < 16 and i + byte_index < 0xFFFF) : (byte_index += 1) {
                    zgui.sameLine(.{ .spacing = if (byte_index == 0) -1 else 0});
        
                    const byte = try gameboy.memory_bank.read(u8, i + byte_index);
                    const ascii_character = if (std.ascii.isASCII(byte) and !std.ascii.isControl(byte)) byte else 0x2E;
                    var color: [4]f32 = if (ascii_character != 0x2E) .{ 1.0, 1.0, 1.0, 1.0 } else .{0.5, 0.5, 0.5, 1.0 };
                    if (self.gui_state.hovered_address == i + byte_index) {
                        color = .{ 1.0, 0.0, 0.0, 1.0 };
                    }

                    zgui.textColored(color, "{c}", .{ascii_character});
                    if (zgui.isItemHovered(.{})) {
                        self.gui_state.hovered_address = i + byte_index;
                    }
                }
            }
            zgui.endChild();
        }
        
        var start_address_str: [5:0]u8 = undefined;
        var end_address_str: [5:0]u8 = undefined;
        _ = std.fmt.bufPrint(start_address_str[0..4], "{X:0>4}", .{self.gui_state.memory_min_address}) catch start_address_str[0..4];
        _ = std.fmt.bufPrint(end_address_str[0..4], "{X:0>4}", .{self.gui_state.memory_max_address}) catch end_address_str[0..4];

        zgui.separator();
        zgui.pushItemWidth(50);
        if (zgui.inputText("##from_addr", .{ .buf = &start_address_str, .flags = .{ .chars_hexadecimal = true, .enter_returns_true = true}})) {
            self.gui_state.memory_min_address = std.math.clamp(
                std.fmt.parseUnsigned(u16, std.mem.sliceTo(&start_address_str, 0), 16) catch self.gui_state.memory_min_address,
                0x0000,
                0xFFFF);
            if (self.gui_state.memory_min_address >= self.gui_state.memory_max_address) {
                self.gui_state.memory_max_address = std.math.clamp(self.gui_state.memory_min_address +| 1, 0x0000, 0xFFFF);
            }
        }

        zgui.sameLine(.{});
        if (zgui.inputText("##to_addr", .{ .buf = &end_address_str, .flags = .{ .chars_hexadecimal = true, .enter_returns_true = true }})) {
            self.gui_state.memory_max_address = std.math.clamp(
                std.fmt.parseUnsigned(u16, std.mem.sliceTo(&end_address_str, 0), 16) catch self.gui_state.memory_max_address,
                0x0000,
                0xFFFF);
            if (self.gui_state.memory_max_address <= self.gui_state.memory_min_address) {
                self.gui_state.memory_min_address = std.math.clamp(self.gui_state.memory_max_address -| 1, 0x0000, 0xFFFF);
            }
        }

        std.debug.print("{X} - {X}", .{self.gui_state.memory_min_address, self.gui_state.memory_max_address});
        zgui.popItemWidth();
        zgui.sameLine(.{});
        zgui.text("Hovered Address: {X:0>4}", .{self.gui_state.hovered_address orelse 0});
        zgui.end();
    }
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

