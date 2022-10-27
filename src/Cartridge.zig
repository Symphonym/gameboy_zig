const std = @import("std");
const fs = std.fs;

const MBC_RomOnly = @import("MBC/MBC_RomOnly.zig");

const Cartridge = @This();
const c_allocator = std.heap.c_allocator;
const max_cartridge_size = 2097152; // 2MB

pub const MBCTypes = union(enum) {
    MBC_RomOnly: MBC_RomOnly
};

pub const CartridgeErrors = error {
    RomTooBig,
    UnsupportedMBCType,
};

title: [16]u8 = .{0} ** 16,
mbc: MBCTypes,
rom: []u8,
// rom_size: u16,

pub fn loadFromFile(relative_file_path: []const u8) !Cartridge {
    const rom = fs.cwd().readFileAlloc(c_allocator, relative_file_path, max_cartridge_size) catch return CartridgeErrors.RomTooBig;
    errdefer c_allocator.free(rom);

    const mbc = switch (rom[0x0147]) {
        0x00 => .{ .MBC_RomOnly = MBC_RomOnly.init(rom) },
        // 0x01 => .MBC1,
        // 0x05 => .MBC2,
        // 0x19 => .MBC5,
        else => |val|{
            std.debug.print("Unsupported MBC Type {}\n", .{val});
            return CartridgeErrors.UnsupportedMBCType; 
        },
    };
    
    // const rom_size: u16 = switch(rom[0x0148]) {
    //     0x00 => 32
    // }
    
    var cartridge = Cartridge {
        .rom = rom,
        .mbc = mbc
    };

    std.mem.copy(u8, &cartridge.title, rom[0x0134..0x144]);
    std.debug.print("Loaded cartridge \"{s}\", Size:{} bytes\n", .{&cartridge.title, cartridge.rom.len});
    // switch (cartridge.mbc) {
    //     inline else => | tag |
    // }
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