const std = @import("std");

const MBC1 = @This();

const BankingModes = enum {
    // 0000–3FFF and A000–BFFF locked to bank 0 of ROM/RAM
    Simple,
    
    // 0000–3FFF and A000–BFFF can be bank-switched via the 4000–5FFF bank register
    Advanced
};

rom: []u8,
rom_bank_count: usize,
ram_enabled: bool = false,
rom_bank_register: u8 = 0,
secondary_rom_bank_register: u8 = 0,
banking_mode: BankingModes = .Simple,
// TODO: Add ram banks variable, 8kb arrays, one for each RAM bank
// ROM banking is just offsetting addresses deeper into ROM by 0x4000 (16KB) for each ROM bank. I think.. read more

pub fn init(rom: []u8, rom_bank_count: usize) MBC1 {
    return .{
        .rom = rom,
        .rom_bank_count = rom_bank_count,
    };
}

pub fn readROM(self: *MBC1, comptime T: type, address: u16) T {
    self.ram_enabled = address == 0xA;

    return std.mem.bytesToValue(T, self.rom[address..][0..@sizeOf(T)]);
}

pub fn writeROM(self: *MBC1, address: u16, value: anytype) void {
    if (address <= 0x7FFF) {
        return;
    }

    switch(address) {
        0x2000...0x3FFF => self.setCurrentRomBankLo(@intCast(u8, value)),
        0x4000...0x5FFF => self.setCurrentRomBankHi(@intCast(u8, value)),
        else => {},
    }

    const bytes_to_write = @sizeOf(@TypeOf(value));
    std.mem.copy(u8, self.rom[(address)..][0..bytes_to_write], &std.mem.toBytes(value));
}

pub fn readRAM(self: *MBC1, comptime T: type, address: u16) T {
    if (!self.ram_enabled) {
        return @intCast(T, 0xFF);
    }

    return std.mem.bytesToValue(T, self.rom[address..][0..@sizeOf(T)]);
}

pub fn writeRAM(self: *MBC1, address: u16, value: anytype) void {
    if (!self.ram_enabled) {
        return;
    }

    const bytes_to_write = @sizeOf(@TypeOf(value));
    std.mem.copy(u8, self.rom[(address)..][0..bytes_to_write], &std.mem.toBytes(value));
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
      
        self.rom_bank_register = @max(self.rom_bank_register & (@intCast(u8, 0xFF) >> i), 0x1); 
    }
}

fn setCurrentRomBankHi(self: *MBC1, value: u8) void {
    self.secondary_rom_bank_register = value;
}

fn getRomBankNumber(self: MBC1) u16 {
    if (self.banking_mode == .Advanced) {
        return @max(@intCast(u16, self.rom_bank_register) | (@intCast(u16, self.secondary_rom_bank_register) & 0x1F), 0x1);
    } else {
        return @max(@intCast(u16, self.rom_bank_register), 0x1);
    }
}

fn getRamBankNumber(self: MBC1) u16 {
    if (self.banking_mode == .Simple) {
        return 0;
    } else {
        return self.secondary_rom_bank_register & 0x3;
    }
}