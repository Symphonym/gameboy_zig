
const std = @import("std");
const testing = std.testing;

const LCDControl = @import("LCDControl.zig");
const LCDStatus = @import("LCDStatus.zig");
const Timer = @import("Timer.zig");
const Interrupt = @import("Interrupt.zig");
const ColorPalette = @import("ColorPalette.zig");
const Cartridge = @import("Cartridge.zig");

const MemoryBank = @This();


bootstrap_rom: [256]u8 = @embedFile("DMG_ROM.bin").*,
work_ram: [8192]u8 = .{0} ** 8192, // 8 KiB
video_ram: [8192]u8 = .{0} ** 8192, // 8 KiB
high_ram: [127]u8 = .{0} ** 127, // 127 bytes
sprite_oam: [160]u8 = .{0} ** 160, // 160 bytes
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
is_bootram_mapped: bool = true,

cartridge: ?*Cartridge = null,

pub const MemoryBankErrors = error
{
    InvalidAddress,
    NotWriteableMemory,
};

pub fn tick(self: *MemoryBank, cycles_taken: u32) void {
    self.vram_changed = false;
    self.timer.tick(cycles_taken, &self.interrupt);
}

fn isVRAMAccessAllowed(self: MemoryBank) bool {
    // TODO: Add more conditions
    _ = self;
    return true;
    //return self.lcd_control.getFlag(.LCD_PPU_enable);
}

pub fn insertCartridge(self: *MemoryBank, cartridge: *Cartridge) void {
    self.cartridge = cartridge;
}

fn readIO(self: *MemoryBank, comptime T: type, address: u16) MemoryBankErrors!T {
    return switch (address) {
        0xFF00 => 0xFF, // TODO: Temp make sure all buttons are unpressed
        0xFF04 => @intCast(T, self.timer.readDivider()),
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

fn readOAM(self: *MemoryBank, comptime T: type, address: u16) MemoryBankErrors!T {
    if (self.lcd_status.getMode() == .HBlank or self.lcd_status.getMode() == .VBlank) {
        return @intCast(T, 0xFF);
    }
    
    return std.mem.bytesToValue(T, self.io_registers[(address - 0xFE00)..][0..@sizeOf(T)]);
}

pub fn read(self: *MemoryBank, comptime T: type, address: u16) MemoryBankErrors!T {
    errdefer {
        std.debug.print("ADDR: {X}\n", .{address});
    }
    return switch(address) {
        0x00...0xFF => blk: {
            if (self.is_bootram_mapped) {
                break :blk std.mem.bytesToValue(T, self.bootstrap_rom[address..][0..@sizeOf(T)]);
            } else if (self.cartridge) | *cartridge| {
                break :blk cartridge.*.readROM(T, address);
            }
        },
        0x100...0x7FFF => if (self.cartridge) | *cartridge| cartridge.*.readROM(T, address) else MemoryBankErrors.InvalidAddress,
        0xC000...0xDFFF => std.mem.bytesToValue(T, self.work_ram[(address - 0xC000)..][0..@sizeOf(T)]),
        0x8000...0x9FFF => blk: {
            if (self.isVRAMAccessAllowed()) {
                break :blk std.mem.bytesToValue(T, self.video_ram[(address - 0x8000)..][0..@sizeOf(T)]);
            } else {
                break :blk 0xFF;
            }
        },
        0xA000...0xBFFF => if (self.cartridge) | *cartridge| cartridge.*.readRAM(T, address - 0xA000) else MemoryBankErrors.InvalidAddress,
        0xFE00...0xFE9F => try self.readOAM(T, address),
        0xFEA0...0xFEFF => 0xFF, // Unusable memory
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
        0xFF01 => std.debug.print("{c}", .{@intCast(u8, value)}), // Blargg rom debug
        0xFF04 => self.timer.writeDivider(@intCast(u8, value)),
        0xFF05 => self.timer.counter = @intCast(u8, value),
        0xFF06 => self.timer.modulo = @intCast(u8, value),
        0xFF07 => self.timer.writeControl(@intCast(u8, value)),
        0xFF0F => self.interrupt.request_register = @intCast(u8, value),
        0xFF40 => self.lcd_control.register = @intCast(u8, value),
        0xFF41 => self.lcd_status.register = @intCast(u8, value),
        0xFF42 => self.scroll_y = @intCast(u8, value),
        0xFF43 => self.scroll_x = @intCast(u8, value),
        0xFF44 => self.scanline_index = @intCast(u8, value),
        0xFF47 => self.background_palette.palette = @intCast(u8, value),
        0xFF46 => {
            // TODO: This is not entirely accurate (cycle and read/write) access-wise
            // DMA transfer
            var i: usize = 0;
            const base_address: u16 = @intCast(u16, value) << 8;
            while (i < 0xA0) : (i += 1) {
                try self.write(@intCast(u16, 0xFE00 + i), try self.read(u8, base_address + @intCast(u16, i)));
            }
        },
        0xFF50 => self.is_bootram_mapped = false,
        0xFF4A => self.window_y = @intCast(u8, value),
        0xFF4B => self.window_x = @intCast(u8, value),
        else => std.mem.copy(u8, self.io_registers[(address - 0xFF00)..][0..bytes_to_write], &std.mem.toBytes(value)),
    }
}

fn writeOAM(self: *MemoryBank, address: u16, value: anytype) MemoryBankErrors!void {
    if (self.lcd_status.getMode() == .HBlank or self.lcd_status.getMode() == .VBlank) {
        return;
    }
    
    const bytes_to_write = @sizeOf(@TypeOf(value));
    std.mem.copy(u8, self.sprite_oam[(address - 0xFE00)..][0..bytes_to_write], &std.mem.toBytes(value));
}

pub fn write(self: *MemoryBank, address: u16, value: anytype) MemoryBankErrors!void
{
    const bytes_to_write = @sizeOf(@TypeOf(value));
    switch(address)
    {
        0x0...0x7FFF => if (self.cartridge) | *cartridge| cartridge.*.writeROM(address, value) else return MemoryBankErrors.InvalidAddress,
        //0x104...0x133 => return MemoryBankErrors.NotWriteableMemory,
        0xC000...0xDFFF => std.mem.copy(u8, self.work_ram[(address - 0xC000)..][0..bytes_to_write], &std.mem.toBytes(value)),
        0x8000...0x9FFF => {
            if (self.isVRAMAccessAllowed()) {
                self.vram_changed = true;
                std.mem.copy(u8, self.video_ram[(address - 0x8000)..][0..bytes_to_write], &std.mem.toBytes(value));
            }
        },
        0xA000...0xBFFF => if (self.cartridge) | *cartridge| cartridge.*.writeRAM(address - 0xA000, value) else return MemoryBankErrors.InvalidAddress,
        0xFE00...0xFE9f => try self.writeOAM(address, value),
        0xFEA0...0xFEFF => {}, // Unusable memory
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

