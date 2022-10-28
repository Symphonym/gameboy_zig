const std = @import("std");
// Each RAM bank is 32 KiB
const RAMBankList = std.ArrayList([32768]u8);

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


rom_bank_register: u8 = 0,
secondary_rom_bank_register: u8 = 0,
banking_mode: BankingModes = .Simple,
// TODO: Add ram banks variable, 8kb arrays, one for each RAM bank
// ROM banking is just offsetting addresses deeper into ROM by 0x4000 (16KB) for each ROM bank. I think.. read more

pub fn init(rom: []u8, rom_bank_count: usize, ram_bank_count: usize) !MBC1 {
    return .{
        .rom = rom,
        .ram_banks = try RAMBankList.initCapacity(std.heap.c_allocator, ram_bank_count),
        .rom_bank_count = rom_bank_count,
        .ram_bank_count = ram_bank_count,
    };
}

pub fn readROM(self: *MBC1, comptime T: type, address: u16) T {
    self.ram_enabled = address == 0xA;

    return std.mem.bytesToValue(T, self.rom[address..][0..@sizeOf(T)]);
}

pub fn writeROM(self: *MBC1, address: u16, value: anytype) void {
    switch(address) {
        0x2000...0x3FFF => self.setCurrentRomBankLo(@intCast(u8, value)),
        0x4000...0x5FFF => self.setCurrentRomBankHi(@intCast(u8, value)),
        0x6000...0x7FFF => self.setBankingMode(@intCast(u8, value)),
        else => {},
    }

    const final_address: u21 = self.getRemappedRomAddress(address);

    if (final_address <= 0x7FFF) {
        // READ ONLY
        return;
    }

    const bytes_to_write = @sizeOf(@TypeOf(value));
    std.mem.copy(u8, self.rom[(final_address)..][0..bytes_to_write], &std.mem.toBytes(value));
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

fn setCurrentRomBankLo(self: *MBC1, value: u8) void {
    self.rom_bank_register = @max(@intCast(u8, value) & 0x1F, 0x01);

    if (self.rom_bank_register > self.rom_bank_count) {
        var i: u3 = 1;
        // 2^9=512, maximum amount of banks. But any more than 5 bits will zero out the register anyway
        while (i <= 5) : (i += 1) {
            if (std.math.pow(usize, 2, i) >= self.rom_bank_count) {
                break;
            }
        }
      
        self.rom_bank_register = @max(self.rom_bank_register & (~(@intCast(u8, 0xFF) << i)), 0x1); 
    }
}

fn setCurrentRomBankHi(self: *MBC1, value: u8) void {
    self.secondary_rom_bank_register = value;
}

fn getRemappedRomAddress(self: MBC1, address: u16) u21 {
    return switch(address) {
        0x0000...0x3FFF => blk: {
            if (self.banking_mode == .Simple) {
                break :blk @intCast(u21, address) & 0x1FFF;
            } else {
                break :blk (@intCast(u21, address) & 0x1FFF) | (@intCast(u20, self.secondary_rom_bank_register & 0x60) << 14);
            }
        },
        0x4000...0x5FFF => blk: {
            const additional_bits: u8 = (self.rom_bank_register & 0x1F) | (self.secondary_rom_bank_register & 0x60);
            break :blk (@intCast(u21, address) & 0x1FFF) | (@intCast(u21, additional_bits) << 14);
        },
        else => @intCast(u21, address),
    };
}

fn getCurrentRamBank(self: *MBC1) []u8 {
    if (self.banking_mode == .Simple) {
        return self.ram_banks.items[0][0..];
    } else {
        return self.ram_banks.items[self.secondary_rom_bank_register & 0x3][0..];
    }
}