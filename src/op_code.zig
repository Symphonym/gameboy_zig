const std = @import("std");

const settings = @import("settings.zig");

pub const OpCodeErrors = error {
    UnknownOpCode
};

pub const Operands = enum {
    A,
    F,
    AF,
    B,
    C,
    BC,
    D,
    E,
    DE,
    H,
    L,
    HL,

    SP,

    AF_Addr,
    BC_Addr,
    DE_Addr,
    HL_Addr,

    Cond_Z,
    Cond_NZ,
    Cond_C,
    Cond_NC,

    Bit_0,
    Bit_1,
    Bit_2,
    Bit_3,
    Bit_4,
    Bit_5,
    Bit_6,
    Bit_7,

    d8,
    d16,
    r8,
    d16_Addr,

    True, // Used as an easy way to handle non-conditional JR jumps
    False
};

pub const Instructions = enum {
    NOP,

    LD8,
    LD8i,
    LD8io_to,
    LD8io_from,
    LD8d,
    LD16,

    CP,
    OR,
    AND,

    INC8,
    INC16,
    DEC8,
    DEC16,

    ADC,
    ADD,
    SUB,

    XOR,

    CALL,
    JP,
    JR,
    RET,
    RETI,

    PUSH,
    POP,

    BIT,
    RL,

    EI,
    DI,
};

pub const OperationFlagStates = enum {
    Set,
    Reset,
    Unchanged,
    Dependent
};

pub const OperationFlags = struct {
    Z: OperationFlagStates = .Unchanged, // Zero
    N: OperationFlagStates = .Unchanged, // Negative
    H: OperationFlagStates = .Unchanged, // Half-Carry
    C: OperationFlagStates = .Unchanged // Carry
};

pub const OpCodeInfo = struct {
    pub fn init(inst: Instructions,
        op_1: ?Operands,
        op_2: ?Operands,
        length: u8,
        cycles_taken: u8,
        flags: OperationFlags) OpCodeInfo {
        return .{
            .inst = inst,
            .op_1 = op_1,
            .op_2 = op_2,
            .length = length,
            .cycles_taken = cycles_taken,
            .flags = flags
        };
    }

    inst: Instructions,
    op_1: ?Operands,
    op_2: ?Operands,
    length: u8,
    cycles_taken: u8,
    flags: OperationFlags
};

pub fn getCBOpCodeInfo(op_code: u8) OpCodeErrors!OpCodeInfo {
    if (comptime settings.debug) {
        std.debug.print("HANDLED CB opcode 0x{X}\n", .{op_code});
    }

    return switch(op_code) {
        0x11 => OpCodeInfo.init(.RL, .C, .C, 2, 8, .{.Z = .Dependent, .N = .Reset, .H = .Reset, .C = .Dependent }),
        0x7C => OpCodeInfo.init(.BIT, .Bit_7, .H, 2, 8, .{.Z = .Dependent, .N = .Reset, .H = .Set }),
        else => blk: {
            std.debug.print("Unhandled CB opcode 0x{X}\n", .{op_code});
            break :blk OpCodeErrors.UnknownOpCode;
        },
    };
}

pub fn getOpCodeInfo(op_code: u8) OpCodeErrors!OpCodeInfo {

    if (comptime settings.debug) {
        std.debug.print("HANDLED opcode 0x{X}\n", .{op_code});
    }

    return switch(op_code) {
        0x00 => OpCodeInfo.init(.NOP, null, null, 1, 4, .{}),
        0x01 => OpCodeInfo.init(.LD16, .BC, .d16, 3, 12, .{}),
        0x04 => OpCodeInfo.init(.INC8, .B, null, 1, 4, .{ .Z = .Dependent, .N = .Reset, .H = .Dependent}),
        0x05 => OpCodeInfo.init(.DEC8, .B, null, 1, 4, .{.Z = .Dependent, .N = .Set, .H = .Dependent }),
        0x06 => OpCodeInfo.init(.LD8, .B, .d8, 2, 8, .{}),
        0x0B => OpCodeInfo.init(.DEC16, .BC, null, 1, 8, .{}),
        0x0C => OpCodeInfo.init(.INC8, .C, null, 1, 4, .{ .Z = .Dependent, .N = .Reset, .H = .Dependent}),
        0x0D => OpCodeInfo.init(.DEC8, .C, null, 1, 4, .{.Z = .Dependent, .N = .Set, .H = .Dependent }),
        0x0E => OpCodeInfo.init(.LD8, .C, .d8, 2, 8, .{}),
        0x11 => OpCodeInfo.init(.LD16, .DE, .d16, 3, 12, .{}),
        0x13 => OpCodeInfo.init(.INC16, .DE, null, 1, 8, .{}),
        0x15 => OpCodeInfo.init(.DEC8, .D, null, 1, 4, .{.Z = .Dependent, .N = .Set, .H = .Dependent }),
        0x16 => OpCodeInfo.init(.LD8, .D, .d8, 2, 8, .{}),
        0x17 => OpCodeInfo.init(.RL, .A, .A, 1, 4, .{.Z = .Reset, .N = .Reset, .H = .Reset, .C = .Dependent }),
        0x18 => OpCodeInfo.init(.JR, .True, .r8, 2, 12, .{}),
        0x20 => OpCodeInfo.init(.JR, .Cond_NZ, .r8, 2, 12, .{}),
        0x1A => OpCodeInfo.init(.LD8, .A, .DE_Addr, 1, 8, .{}),
        0x1E => OpCodeInfo.init(.LD8, .E, .d8, 2, 8, .{}),
        0x1D => OpCodeInfo.init(.DEC8, .E, null, 1, 4, .{.Z = .Dependent, .N = .Set, .H = .Dependent }),
        0x21 => OpCodeInfo.init(.LD16, .HL, .d16, 3, 12, .{}),
        0x22 => OpCodeInfo.init(.LD8i, .HL_Addr, .A, 1, 8, .{}),
        0x23 => OpCodeInfo.init(.INC16, .HL, null, 1, 8, .{}),
        0x24 => OpCodeInfo.init(.INC8, .H, null, 1, 4, .{ .Z = .Dependent, .N = .Reset, .H = .Dependent}),
        0x28 => OpCodeInfo.init(.JR, .Cond_Z, .r8, 2, 12, .{}),
        0x2A => OpCodeInfo.init(.LD8i, .A, .HL_Addr, 1, 8, .{}),
        0x2E => OpCodeInfo.init(.LD8, .L, .d8, 2, 8, .{}),
        0x31 => OpCodeInfo.init(.LD16, .SP, .d16, 3, 12, .{}),
        0x32 => OpCodeInfo.init(.LD8d, .HL_Addr, .A, 1, 8, .{}),
        0x34 => OpCodeInfo.init(.INC8, .HL_Addr, null, 1, 12, .{ .Z = .Dependent, .N = .Reset, .H = .Dependent}),
        0x36 => OpCodeInfo.init(.LD8, .HL_Addr, .d8, 2, 12, .{}),
        0x3C => OpCodeInfo.init(.INC8, .A, null, 1, 4, .{ .Z = .Dependent, .N = .Reset, .H = .Dependent}),
        0x3D => OpCodeInfo.init(.DEC8, .A, null, 1, 4, .{.Z = .Dependent, .N = .Set, .H = .Dependent }),
        0x3E => OpCodeInfo.init(.LD8, .A, .d8, 2, 8, .{}),
        0x4F => OpCodeInfo.init(.LD8, .C, .A, 1, 4, .{}),
        0x51 => OpCodeInfo.init(.LD8, .D, .B, 1, 4, .{}),
        0x57 => OpCodeInfo.init(.LD8, .D, .A, 1, 4, .{}),
        0x66 => OpCodeInfo.init(.LD8, .H, .HL_Addr, 1, 8, .{}),
        0x67 => OpCodeInfo.init(.LD8, .H, .A, 1, 4, .{}),
        0x77 => OpCodeInfo.init(.LD8, .HL_Addr, .A, 1, 8, .{}),
        0x78 => OpCodeInfo.init(.LD8, .A, .B, 1, 4, .{}),
        0x7B => OpCodeInfo.init(.LD8, .A, .E, 1, 4, .{}),
        0x7C => OpCodeInfo.init(.LD8, .A, .H, 1, 4, .{}),
        0x7D => OpCodeInfo.init(.LD8, .A, .L, 1, 4, .{}),
        0x86 => OpCodeInfo.init(.ADD, .A, .HL_Addr, 1, 8, .{ .Z = .Dependent, .N = .Reset, .H = .Dependent, .C = .Dependent}),
        0x90 => OpCodeInfo.init(.SUB, .B, null, 1, 4, .{ .Z = .Dependent, .N = .Reset, .H = .Dependent, .C = .Dependent}),
        0xA7 => OpCodeInfo.init(.AND, .A, null, 1, 4, .{ .Z = .Dependent, .N = .Reset, .H = .Set, .C = .Reset}),
        0xAF => OpCodeInfo.init(.XOR, .A, null, 1, 4, .{ .Z = .Dependent, .N = .Reset, .H = .Reset, .C = .Reset}),
        0xB1 => OpCodeInfo.init(.OR, .C, null, 1, 4, .{ .Z = .Dependent, .N = .Reset, .H = .Reset, .C = .Reset}),
        0xBE => OpCodeInfo.init(.CP, .HL_Addr, null, 1, 8, .{ .Z = .Dependent, .N = .Set, .H = .Dependent, .C = .Dependent}),
        0xC0 => OpCodeInfo.init(.RET, .Cond_NZ, null, 1, 20, .{}),
        0xC1 => OpCodeInfo.init(.POP, .BC, null, 1, 12, .{}),
        0xC3 => OpCodeInfo.init(.JP, .d16, null, 3, 16, .{}),
        0xC5 => OpCodeInfo.init(.PUSH, .BC, null, 1, 16, .{}),
        0xC8 => OpCodeInfo.init(.RET, .Cond_Z, null, 1, 20, .{}),
        0xC9 => OpCodeInfo.init(.RET, null, null, 1, 16, .{}),
        0xCC => OpCodeInfo.init(.CALL, .Cond_Z, .d16, 3, 24, .{}),
        0xCD => OpCodeInfo.init(.CALL, .d16, null, 3, 24, .{}),
        0xCE => OpCodeInfo.init(.ADC, .A, .d8, 2, 8, .{ .Z = .Dependent, .N = .Reset, .H = .Dependent, .C = .Dependent}),
        0xD1 => OpCodeInfo.init(.POP, .DE, null, 1, 12, .{}),
        0xD5 => OpCodeInfo.init(.PUSH, .DE, null, 1, 16, .{}),
        0xD9 => OpCodeInfo.init(.RETI, null, null, 1, 16, .{}),
        0xE0 => OpCodeInfo.init(.LD8io_to, .d8, .A, 2, 12, .{}),
        0xE1 => OpCodeInfo.init(.POP, .HL, null, 1, 12, .{}),
        0xE2 => OpCodeInfo.init(.LD8io_to, .C, .A, 1, 8, .{}),
        0xE5 => OpCodeInfo.init(.PUSH, .HL, null, 1, 16, .{}),
        0xEA => OpCodeInfo.init(.LD8, .d16_Addr, .A, 3, 16, .{}),
        0xF0 => OpCodeInfo.init(.LD8io_from, .A, .d8, 2, 12, .{}),
        0xF1 => OpCodeInfo.init(.POP, .AF, null, 1, 12, .{}),
        0xF3 => OpCodeInfo.init(.DI, null, null, 1, 4, .{}),
        0xF5 => OpCodeInfo.init(.PUSH, .AF, null, 1, 16, .{}),
        0xFA => OpCodeInfo.init(.LD8, .A, .d16_Addr, 3, 16, .{}),
        0xFB => OpCodeInfo.init(.EI, null, null, 1, 4, .{}),
        0xFE => OpCodeInfo.init(.CP, .d8, null, 2, 8, .{ .Z = .Dependent, .N = .Set, .H = .Dependent, .C = .Dependent}),
        else => blk: {
            std.debug.print("Unhandled opcode 0x{X}\n", .{op_code});
            break :blk OpCodeErrors.UnknownOpCode;
        },
    };
}