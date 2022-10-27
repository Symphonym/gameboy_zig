
const std = @import("std");
const testing = std.testing;

const LCDControl = @import("LCDControl.zig");
const LCDStatus = @import("LCDStatus.zig");
const Timer = @import("Timer.zig");
const Interrupt = @import("Interrupt.zig");
const ColorPalette = @import("ColorPalette.zig");

const MemoryBank = @This();


bootstrap_rom: [256]u8 = @embedFile("DMG_ROM.bin").*,
work_ram: [8192]u8 = .{0} ** 8192, // 8 KiB
video_ram: [8192]u8 = .{0} ** 8192, // 8 KiB
high_ram: [127]u8 = .{0} ** 127, // 127 bytes
io_registers: [128]u8 = .{0} ** 128, // 128 bytes

lcd_control: LCDControl = .{},
lcd_status: LCDStatus = .{},
timer: Timer = .{},
interrupt: Interrupt = .{},
scroll_x: u8 = 0,
scroll_y: u8 = 0,
ly_compare: u8 = 0,
window_x: u8 = 0,
window_y: u8 = 0,
scanline_index: u8 = 0,

background_palette: ColorPalette = .{},

vram_changed: bool = false,

const nintendo_logo = [_]u8 {
    0xCE, 0xED, 0x66, 0x66, 0xCC, 0x0D, 0x00, 0x0B, 0x03, 0x73, 0x00, 0x83, 0x00, 0x0C, 0x00, 0x0D,
    0x00, 0x08 ,0x11 ,0x1F ,0x88 ,0x89 ,0x00 ,0x0E ,0xDC ,0xCC ,0x6E ,0xE6 ,0xDD ,0xDD ,0xD9 ,0x99 ,
    0xBB, 0xBB ,0x67 ,0x63 ,0x6E ,0x0E ,0xEC ,0xCC ,0xDD ,0xDC ,0x99 ,0x9F ,0xBB ,0xB9 ,0x33  ,0x3E 
};

pub const MemoryBankErrors = error
{
    InvalidAddress,
    NotWriteableMemory,
};

pub fn tick(self: *MemoryBank, cycles_taken: u32) void {
    self.vram_changed = false;
    self.timer.tick(cycles_taken, self);
}

fn isVRAMAccessAllowed(self: MemoryBank) bool {
    // TODO: Add more conditions
    _ = self;
    return true;
    //return self.lcd_control.getFlag(.LCD_PPU_enable);
}

fn readIO(self: *MemoryBank, comptime T: type, address: u16) MemoryBankErrors!T {
    return switch (address) {
        0xFF04 => @intCast(T, self.timer.divider),
        0xFF05 => @intCast(T, self.timer.counter),
        0xFF06 => @intCast(T, self.timer.modulo),
        0xFF07 => @intCast(T, self.timer.control),
        0xFF0F => @intCast(T, self.interrupt.request_register),
        0xFF40 => @intCast(T, self.lcd_control.register),
        0xFF41 => @intCast(T, self.lcd_status.register),
        0xFF42 => @intCast(T, self.scroll_y),
        0xFF43 => @intCast(T, self.scroll_x),
        0xFF44 => @intCast(T, self.scanline_index),
        0xFF45 => @intCast(T, self.ly_compare),
        0xFF47 => @intCast(T, self.background_palette.palette),
        0xFF4A => @intCast(T, self.window_y),
        0xFF4B => @intCast(T, self.window_x),
        else => std.mem.bytesToValue(T, self.io_registers[(address - 0xFF00)..][0..@sizeOf(T)])
    };
}

pub fn read(self: *MemoryBank, comptime T: type, address: u16) MemoryBankErrors!T {
    return switch(address) {
        // TODO: if 0xFF50 is set then we unmap bootrom and read from cartridge
        0x00...0xFF => std.mem.bytesToValue(T, self.bootstrap_rom[address..][0..@sizeOf(T)]),
        0x104...0x133 => std.mem.bytesToValue(T, nintendo_logo[(address - 0x104)..][0..@sizeOf(T)]),
        0xC000...0xDFFF => std.mem.bytesToValue(T, self.work_ram[(address - 0xC000)..][0..@sizeOf(T)]),
        0x8000...0x9FFF => blk: {
            if (self.isVRAMAccessAllowed()) {
                break :blk std.mem.bytesToValue(T, self.video_ram[(address - 0x8000)..][0..@sizeOf(T)]);
            } else {
                break :blk 0xFF;
            }
        },
        0xFF00...0xFF7F => try self.readIO(T, address),
        0xFF80...0xFFFE => std.mem.bytesToValue(T, self.high_ram[(address - 0xFF80)..][0..@sizeOf(T)]),
        0xFFFF => @intCast(T, self.interrupt.enabled_register),
        else => blk: {
            std.debug.print("Invalid address read at 0x{X}\n", .{address});
            break :blk MemoryBankErrors.InvalidAddress;
        }
    };
}

fn writeIO(self: *MemoryBank, address: u16, value: anytype) MemoryBankErrors!void {
    const bytes_to_write = @sizeOf(@TypeOf(value));
    switch (address) {
        0xFF04 => self.timer.divider = 0,
        0xFF05 => self.timer.counter = @intCast(u8, value),
        0xFF06 => self.timer.modulo = @intCast(u8, value),
        0xFF07 => self.timer.control = @intCast(u8, value),
        0xFF0F => self.interrupt.request_register = @intCast(u8, value),
        0xFF40 => self.lcd_control.register = @intCast(u8, value),
        0xFF41 => self.lcd_status.register = @intCast(u8, value),
        0xFF42 => self.scroll_y = @intCast(u8, value),
        0xFF43 => self.scroll_x = @intCast(u8, value),
        0xFF44 => self.scanline_index = @intCast(u8, value),
        0xFF47 => self.background_palette.palette = @intCast(u8, value),
        0xFF46 => {
            // TODO: This is not entirely accurate (cycle and read/write) access-wise
            var i: usize = 0;
            const base_address: u16 = @intCast(u16, value) << 8;
            while (i < 0xA0) : (i += 1) {
                try self.write(@intCast(u16, 0xFE00 + i), try self.read(u8, base_address + @intCast(u16, i)));
            }
        },
        0xFF4A => self.window_y = @intCast(u8, value),
        0xFF4B => self.window_x = @intCast(u8, value),
        else => std.mem.copy(u8, self.io_registers[(address - 0xFF00)..][0..bytes_to_write], &std.mem.toBytes(value)),
    }
}

pub fn write(self: *MemoryBank, address: u16, value: anytype) MemoryBankErrors!void
{
    if (address == 0x8010 and value != 0) {
        std.debug.print("HELLO {X}\n", .{value});
        // return MemoryBankErrors.NotWriteableMemory; 
    }

    const bytes_to_write = @sizeOf(@TypeOf(value));
    switch(address)
    {
        0x00...0xFF,
        0x104...0x133 => return MemoryBankErrors.NotWriteableMemory,
        0xC000...0xDFFF => std.mem.copy(u8, self.work_ram[(address - 0xC000)..][0..bytes_to_write], &std.mem.toBytes(value)),
        0x8000...0x9FFF => {
            if (self.isVRAMAccessAllowed()) {
                self.vram_changed = true;
                std.mem.copy(u8, self.video_ram[(address - 0x8000)..][0..bytes_to_write], &std.mem.toBytes(value));
            }
        },
        0xFF00...0xFF7F => try self.writeIO(address, value),
        0xFF80...0xFFFE => std.mem.copy(u8, self.high_ram[(address - 0xFF80)..][0..bytes_to_write], &std.mem.toBytes(value)),
        0xFFFF => self.interrupt.enabled_register = @intCast(u8, value),
        else => {
            std.debug.print("Invalid address write at 0x{X}\n", .{address});
            return MemoryBankErrors.InvalidAddress;
        }
    }
}


test "test byte read/write"
{
    var bank = MemoryBank {};
    const byte: u8 = 0xAB;
    const address: u16 = 0xDFFF;
    try bank.write(address, byte);

    try testing.expectEqual(byte, try bank.read(u8, address));
}

test "test 2byte read/write"
{
    var bank = MemoryBank {};
    const double_byte: u16 = 0xABCD;
    const address: u16 = 0xDFFE;
    try bank.write(address, double_byte);

    try testing.expectEqual(double_byte, try bank.read(u16, address));
}

