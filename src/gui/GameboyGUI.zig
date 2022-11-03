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

    run_bootrom: bool = false,
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
    try self.imguiCPUView();
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

    self.gameboy.?.cpu.?.registers.PC = if (self.gui_state.run_bootrom) 0x0 else 0x100;

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
        zgui.popItemWidth();

        zgui.sameLine(.{});
        zgui.textColored(.{0.0, 1.0, 0.0, 1.0}, "Hovered Address:", .{});
        const hovered_address_data = try gameboy.memory_bank.read(u8, self.gui_state.hovered_address orelse 0);
        zgui.sameLine(.{});
        zgui.text("{X:0>4}", .{self.gui_state.hovered_address orelse 0 });
        zgui.sameLine(.{ .spacing = 10 });
        zgui.textColored(.{0.0, 1.0, 0.0, 1.0}, "({X:0>4} {b:0>8})", .{hovered_address_data, hovered_address_data});

        zgui.textColored(.{0.0, 1.0, 0.0, 1.0}, "Timer", .{});
        zgui.text("DIV({X:0>2}) TIMA({X:0>2}) TMA({X:0>2})", .{
            gameboy.memory_bank.timer.readDivider(),
            gameboy.memory_bank.timer.counter,
            gameboy.memory_bank.timer.modulo});
        zgui.sameLine(.{ .spacing = 10 });
        zgui.text("Enabled: {}", .{gameboy.memory_bank.timer.isTimerEnabled()});
        zgui.sameLine(.{ .spacing = 10 });
        zgui.text("Speed: {s}", .{@tagName(gameboy.memory_bank.timer.getTimerSpeed())});

        zgui.textColored(.{0.0, 1.0, 0.0, 1.0}, "Interrupts", .{});
        zgui.text("{b:0>8} IF (Requests)", .{gameboy.memory_bank.interrupt.request_register});
        zgui.sameLine(.{ .spacing = 10 });
        zgui.text("IME: {}", .{gameboy.memory_bank.interrupt.interrupt_master_enable});
        zgui.text("{b:0>8} IF (Enabled)", .{gameboy.memory_bank.interrupt.enabled_register});

        zgui.end();
    }
}

fn imguiCPUView(self: *Self) !void {
    
    if (self.gameboy) |*gameboy| {
        if (zgui.begin("CPU", .{ .flags = .{.no_resize = true, .always_auto_resize = true} })) {
            zgui.text("Execution Mode: ", .{});
            zgui.sameLine(.{});

            const execution_mode_color: [4]f32 = switch(gameboy.execution_mode) {
                .Free => .{ 1.0, 1.0, 1.0, 1.0},
                else => .{ 1.0, 0.0, 0.0, 1.0 },
            };

            zgui.textColored(execution_mode_color, "{s}", .{@tagName(gameboy.execution_mode)});

            zgui.text("AF: {X:0>4} Flags: {b:0>8} Z({}) N({}) H({}) C({})", .{
                gameboy.cpu.?.registers.AF.ptr().*,
                gameboy.cpu.?.registers.AF.Lo,
                @boolToInt(gameboy.cpu.?.getFlag(.Z)),
                @boolToInt(gameboy.cpu.?.getFlag(.N)),
                @boolToInt(gameboy.cpu.?.getFlag(.H)),
                @boolToInt(gameboy.cpu.?.getFlag(.C))});

            zgui.text("BC: {X:0>4}", .{ gameboy.cpu.?.registers.BC.ptr().* });
            zgui.sameLine(.{ .spacing = 10});
            zgui.text("DE: {X:0>4}", .{ gameboy.cpu.?.registers.DE.ptr().* });
            zgui.sameLine(.{ .spacing = 10});
            zgui.text("HL: {X:0>4}", .{ gameboy.cpu.?.registers.HL.ptr().* });
        
            zgui.text("SP: {X:0>4}", .{ gameboy.cpu.?.registers.SP });
            zgui.sameLine(.{ .spacing = 10});
            zgui.text("PC: {X:0>4}", .{ gameboy.cpu.?.registers.PC });

            const op_code = try gameboy.cpu.?.getCurrentOpCode();
            zgui.text("Op Code:", .{});
            zgui.sameLine(.{});
            zgui.textColored(.{0.0, 1.0, 0.0, 1.0 }, "{s} {s},{s}", .{
                @tagName(op_code.inst),
                if (op_code.op_1) |val| @tagName(val) else "null",
                if (op_code.op_2) |val| @tagName(val) else "null"});

            if (zgui.button(if (gameboy.execution_mode == .Paused) ">" else "=", .{})) {
                gameboy.execution_mode = if (gameboy.execution_mode == .Free) .Paused else .Free;
            }

            zgui.sameLine(.{});
            if (zgui.button("Step", .{})) {
                gameboy.execution_mode = .Step;
            }

            // if (zgui.beginChild("Breakpoint View", .{})) {
                
            //     if (zgui.beginListBox("Breakpoints", .{})) {
                    
            //         zgui.endListBox();
            //     }
            //     zgui.endChild();
            // }


            zgui.end();    
        }
        
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
    zgui.sameLine(.{});
    _ = zgui.checkbox("Run Bootrom ", .{ .v = &self.gui_state.run_bootrom});

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

