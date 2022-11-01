const std = @import("std");

const MBC_RomOnly = @This();

rom: []u8,

pub fn init(rom: []u8) MBC_RomOnly {
    return .{
        .rom = rom
    };
}

pub fn readROM(self: *MBC_RomOnly, comptime T: type, address: u16) T {
    return std.mem.bytesToValue(T, self.rom[address..][0..@sizeOf(T)]);
}

pub fn writeROM(self: *MBC_RomOnly, address: u16, value: anytype) void {
    const bytes_to_write = @sizeOf(@TypeOf(value));
    std.mem.copy(u8, self.rom[(address)..][0..bytes_to_write], &std.mem.toBytes(value));
}