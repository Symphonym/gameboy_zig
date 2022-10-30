const std = @import("std");
const testing = std.testing;

// Each RAM bank is 8 KiB
const RAMBankList = std.ArrayList([8192]u8);

const MBC1 = @This();

const BankingModes = enum {
    // 0000–3FFF and A000–BFFF locked to bank 0 of ROM/RAM
    Simple,
    
    // 0000–3FFF and A000–BFFF can be bank-switched via the 4000–5FFF bank register
    Advanced
};

rom: []u8,
ram_banks: RAMBankList, 
rom_bank_count: usize,
ram_bank_count: usize,
ram_enabled: bool = false,


selected_rom_bank: u32 = 1,
selected_ram_bank: u32 = 0,
banking_mode: BankingModes = .Simple,

pub fn init(rom: []u8, rom_bank_count: usize, ram_bank_count: usize) !MBC1 {
    return .{
        .rom = rom,
        .ram_banks = try RAMBankList.initCapacity(std.heap.c_allocator, ram_bank_count),
        .rom_bank_count = rom_bank_count,
        .ram_bank_count = ram_bank_count,
    };
}

pub fn readROM(self: *MBC1, comptime T: type, address: u16) T {
    return switch(address) {
        0x0000...0x3FFF => std.mem.bytesToValue(T, self.rom[address..][0..@sizeOf(T)]),
        else => blk: {
            // std.debug.print("MAPPED ROM: {} {X}\n", .{self.getMappedRomBank(), address});
            const adjusted_address = @intCast(u32, 0x4000) * self.getMappedRomBank() + (address - 0x4000);
            break :blk std.mem.bytesToValue(T, self.rom[adjusted_address..][0..@sizeOf(T)]);
        }
    };
}

pub fn writeROM(self: *MBC1, address: u16, value: anytype) void {
    switch(address) {
        0x0000...0x1FFF => self.ram_enabled = address & 0x0F == 0xA,
        0x2000...0x3FFF => {
            self.selected_rom_bank = (self.selected_rom_bank & 0x30) | (@intCast(u8, value) & 0x1F);
        },//self.setCurrentRomBankLo(@intCast(u8, value)),
        0x4000...0x5FFF => {
            self.selected_rom_bank |= (@intCast(u8, value) & 0x3) << 5;
            self.selected_ram_bank = @intCast(u8, value) & 0x3;
        },
        //self.setCurrentRomBankHi(@intCast(u8, value)),
        0x6000...0x7FFF => self.setBankingMode(@intCast(u8, value)),
        else => {},
    }

    // ROM IS READ-ONLY

    // const final_address: u21 = self.getRemappedRomAddress(address);

    // if (final_address <= 0x7FFF) {
    //     // READ ONLY
    //     return;
    // }

    // const bytes_to_write = @sizeOf(@TypeOf(value));
    // std.mem.copy(u8, self.rom[(final_address)..][0..bytes_to_write], &std.mem.toBytes(value));
}

pub fn readRAM(self: *MBC1, comptime T: type, address: u16) T {
    if (!self.ram_enabled or self.ram_banks.items.len <= 0) {
        return @intCast(T, 0xFF);
    }

    const ram_bank: []u8 = self.getCurrentRamBank();
    return std.mem.bytesToValue(T, ram_bank[address..][0..@sizeOf(T)]);
}

pub fn writeRAM(self: *MBC1, address: u16, value: anytype) void {
    if (!self.ram_enabled or self.ram_banks.items.len <= 0) {
        return;
    }

    const ram_bank: []u8 = self.getCurrentRamBank();

    const bytes_to_write = @sizeOf(@TypeOf(value));
    std.mem.copy(u8, ram_bank[address..][0..bytes_to_write], &std.mem.toBytes(value));
}

fn setBankingMode(self: *MBC1, value: u8) void {
    self.banking_mode = if (value & 0x1 == 0x0) .Simple else .Advanced;
}

// fn setCurrentRomBankLo(self: *MBC1, value: u8) void {
//     self.rom_bank_register = @max(@intCast(u8, value) & 0x1F, 0x01);

//     // if (self.rom_bank_register > self.rom_bank_count) {
//     //     var i: u3 = 1;
//     //     // 2^9=512, maximum amount of banks. But any more than 5 bits will zero out the register anyway
//     //     while (i <= 5) : (i += 1) {
//     //         if (std.math.pow(usize, 2, i) >= self.rom_bank_count) {
//     //             break;
//     //         }
//     //     }
      
//     //     self.rom_bank_register = @max(self.rom_bank_register & (~(@intCast(u8, 0xFF) << i)), 0x1); 
//     // }
// }

// fn setCurrentRomBankHi(self: *MBC1, value: u8) void {
//     self.secondary_rom_bank_register = value;
// }

// fn getRemappedRomAddress(self: MBC1, address: u16) u21 {
//     return switch(address) {
//         0x0000...0x3FFF => blk: {
//             if (self.banking_mode == .Simple) {
//                 break :blk @intCast(u21, address) & 0x1FFF;
//             } else {
//                 break :blk (@intCast(u21, address) & 0x1FFF) | (@intCast(u20, self.secondary_rom_bank_register & 0x60) << 14);
//             }
//         },
//         0x4000...0x5FFF => blk: {
//             const additional_bits: u8 = (self.rom_bank_register & 0x1F) | (self.secondary_rom_bank_register & 0x60);
//             break :blk (@intCast(u21, address) & 0x1FFF) | (@intCast(u21, additional_bits) << 14);
//         },
//         else => @intCast(u21, address),
//     };
// }

fn getCurrentRamBank(self: *MBC1) []u8 {
    if (self.banking_mode == .Simple) {
        return self.ram_banks.items[0][0..];
    } else {
        return self.ram_banks.items[self.selected_ram_bank][0..];
    }
}

fn getMappedRomBank(self: MBC1) u32 {
    return switch (self.selected_ram_bank) {
        0x10, 0x20, 0x40, 0x60 => self.selected_rom_bank + 1,
        else => self.selected_rom_bank,
    };
}

// test "MBC1 rom banking" {
//     const rom = [_]u8 { 0 };
//     var mbc1 = MBC1.init(rom, 4, 4);
//     mbc1.banking_mode = .Advanced;

//     mbc1.rom_bank_register = 1;
//     try testing.expectEqual(@intCast(u21, 0x4000 * 2))
// }