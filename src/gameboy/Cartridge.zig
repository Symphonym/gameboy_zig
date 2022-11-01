const std = @import("std");
const fs = std.fs;

const MBC_RomOnly = @import("MBC/MBC_RomOnly.zig");
const MBC1 = @import("MBC/MBC1.zig");

const Cartridge = @This();
const c_allocator = std.heap.c_allocator;
const max_cartridge_size = 2097152; // 2MB

pub const MBCTypes = union(enum) {
    MBC_RomOnly: MBC_RomOnly,
    MBC1: MBC1,
};

pub const CartridgeErrors = error {
    RomTooBig,
    UnsupportedMBCType,
    UnsupportedRAMSize,
    UnsupportedROMSize,
};

title: [16]u8 = .{0} ** 16,
mbc: MBCTypes,
rom: []u8,
rom_bank_count: usize,
ram_bank_count: usize,
// rom_size: u16,

pub fn loadFromFile(relative_file_path: []const u8) !Cartridge {
    const rom = fs.cwd().readFileAlloc(c_allocator, relative_file_path, max_cartridge_size) catch return CartridgeErrors.RomTooBig;
    errdefer c_allocator.free(rom);

    const rom_bank_count: usize = switch (rom[0x0148]) {
        0x00 => 2,
        0x01 => 4,
        0x02 => 8,
        0x03 => 16,
        0x04 => 32,
        0x05 => 64,
        0x06 => 128,
        0x07 => 256,
        0x08 => 512,
        else => return CartridgeErrors.UnsupportedROMSize,
    };

    const ram_bank_count: usize = switch (rom[0x0149]) {
        0x00 => 0,
        0x01 => 0,
        0x02 => 1,
        0x03 => 4,
        0x04 => 16,
        0x05 => 8,
        else => return CartridgeErrors.UnsupportedRAMSize,
    };

    const mbc: MBCTypes = switch (rom[0x0147]) {
        0x00 => .{ .MBC_RomOnly = MBC_RomOnly.init(rom) },
        0x01 => .{ .MBC1 = try MBC1.init(rom, rom_bank_count, ram_bank_count) },
        // 0x01 => .MBC1,
        // 0x05 => .MBC2,
        // 0x19 => .MBC5,
        else => |val|{
            std.debug.print("Unsupported MBC Type {}\n", .{val});
            return CartridgeErrors.UnsupportedMBCType; 
        },
    };

    var cartridge = Cartridge {
        .rom = rom,
        .mbc = mbc,
        .rom_bank_count = rom_bank_count,
        .ram_bank_count = ram_bank_count,
    };

    const mbc_name = switch(mbc) {
        inline else => | val | @typeName(@TypeOf(val)),
    };

    std.mem.copy(u8, &cartridge.title, rom[0x0134..0x144]);
    std.debug.print("Loaded cartridge \"{s}\"", .{&cartridge.title});
    std.debug.print("\nSize: {} bytes\nMBC: {s}\nROM Bank Count: {}\nRAM Bank Count: {}\n", .{cartridge.rom.len, mbc_name, rom_bank_count, ram_bank_count});
    return cartridge;
}

pub fn readROM(self: *Cartridge, comptime T: type, address: u16) T {
    return switch (self.mbc) {
        inline else => | *mbc | blk: {
            if (@hasDecl(@TypeOf(mbc.*), "readROM")) {
                break :blk mbc.readROM(T, address);
            } else {
                return 0xFF;
            }
        }
    };
}

pub fn writeROM(self: *Cartridge, address: u16, value: anytype) void {
    switch (self.mbc) {
        inline else => | *mbc | blk: {
            if (@hasDecl(@TypeOf(mbc.*), "writeROM")) {
                break :blk mbc.writeROM(address, value);
            }
        }
    }
}

pub fn readRAM(self: *Cartridge, comptime T: type, address: u16) T {
    return switch (self.mbc) {
        inline else => | *mbc | blk: {
            if (@hasDecl(@TypeOf(mbc.*), "readRAM")) {
                break :blk mbc.readRAM(T, address);
            } else {
                return 0xFF;
            }
        }
    };
}

pub fn writeRAM(self: *Cartridge, address: u16, value: anytype) void {
    switch (self.mbc) {
        inline else => | *mbc | blk: {
            if (@hasDecl(@TypeOf(mbc.*), "writeRAM")) {
                break :blk mbc.writeRAM(address, value);
            }
        }
    }
}

pub fn deinit(self: *Cartridge) void {
    c_allocator.free(self.rom);
}