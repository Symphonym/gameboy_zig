const std = @import("std");
const testing = std.testing;

const MemoryBank = @import("MemoryBank.zig");
const Interrupt = @import("Interrupt.zig");
const OpCode = @import("op_code.zig");
const settings = @import("settings.zig");

const Cpu = @This();

pub const CpuErrors = error {
    UnhandledOpCode,
    OperandNotHandled,
    MissingOperand,
    InvalidInterrupt,
} || MemoryBank.MemoryBankErrors || OpCode.OpCodeErrors;

pub const Flags = enum(u8) {
    Z = 0x80, // 7th bit
    N = 0x40, // 6th bit
    H = 0x20, // 5th bit
    C = 0x10 // 4th bit
};

pub const Register = packed struct {
    Lo: u8 = 0,
    Hi: u8 = 0,

    pub fn ptr(self: *Register) *u16 { return @ptrCast(*u16, self); }
}; 

pub const RegisterBank = struct {
    AF: Register = .{ .Hi = 0x01, .Lo = 0xB0 },
    BC: Register = .{ .Hi = 0x00, .Lo = 0x13 },
    DE: Register = .{ .Hi = 0x00, .Lo = 0xD8 },
    HL: Register = .{ .Hi = 0x01, .Lo = 0x4D },
    SP: u16 = 0xFFFE,
    PC: u16 = 0x100
};

const InstructionResult = struct {
    new_pc: ?u16 = null, // New PC value, PC is simply incremented if null
    cycles_taken: ?u8 = null // Cycles taken by the instruction, uses OpCode specified value if null
};

memory_bank: *MemoryBank,
registers: RegisterBank = .{},

cpu_halted: bool = false,
halt_bug_triggered: bool = false,

IME_request: ?bool = null,
// file_handle: std.fs.File,
// buffer_writer: ?std.io.BufferedWriter(4096, std.fs.File.Writer) = null,

pub fn init(memory_bank: *MemoryBank) Cpu {
    return .{
        .memory_bank = memory_bank,
        // .file_handle = std.fs.createFileAbsolute("C:\\Users\\larss\\Documents\\Programming\\Zig\\Gameboy\\zig-out\\bin\\execution_log.txt", .{}) catch unreachable,
    };
}

pub fn deinit(self: *Cpu) void {
    _ = self;
    // if (self.buffer_writer) |*writer| {
    //     writer.*.flush() catch unreachable;
    // }
    // self.file_handle.close();
}

fn setFlag(self: *Cpu, flag: Flags, value: bool) void {
    if (value) {
        self.registers.AF.Lo |= @enumToInt(flag);
    } else {
        self.registers.AF.Lo &= ~(@enumToInt(flag));
    }
}

fn getFlag(self: *Cpu, flag: Flags) bool {
    return self.registers.AF.Lo & @enumToInt(flag) != 0;
}

pub fn tickInstructions(self: *Cpu) CpuErrors!u32 {
    // if (self.buffer_writer == null) {
    //     self.buffer_writer = std.io.bufferedWriter(self.file_handle.writer());
    // }

    // if (!self.memory_bank.is_bootram_mapped) {
    //     _ = std.fmt.format(self.buffer_writer.?.writer(), "A: {X:0>2} F: {X:0>2} B: {X:0>2} C: {X:0>2} D: {X:0>2} E: {X:0>2} H: {X:0>2} L: {X:0>2} SP: {X:0>4} PC: 00:{X:0>4} ({X:0>2} {X:0>2} {X:0>2} {X:0>2})\n",
    // .{self.registers.AF.Hi, self.registers.AF.Lo,
    // self.registers.BC.Hi, self.registers.BC.Lo,
    // self.registers.DE.Hi, self.registers.DE.Lo,
    // self.registers.HL.Hi, self.registers.HL.Lo,
    // self.registers.SP,
    // self.registers.PC,
    // try self.memory_bank.read(u8, self.registers.PC),
    // try self.memory_bank.read(u8, self.registers.PC + 1),
    // try self.memory_bank.read(u8, self.registers.PC + 2),
    // try self.memory_bank.read(u8, self.registers.PC + 3)}) catch unreachable;
    // }

    if (self.cpu_halted) {
        return 1;
    }

    if (comptime settings.debug) {
        std.debug.print("PC at 0x{X}\n", .{self.registers.PC});
    }
    const op_code = try self.memory_bank.read(u8, self.registers.PC);

    // TODO: d8 and d16 values etc won't be read correctly for CB op codes due to the extra offset
    const op_code_info = blk: {
        if (op_code == 0xCB) {
            const cb_op_code = try self.memory_bank.read(u8, self.registers.PC + 1);
            break :blk try OpCode.getCBOpCodeInfo(cb_op_code);
        } else {
            break :blk try OpCode.getOpCodeInfo(op_code);
        }
    };

    errdefer {
        std.debug.print("Cpu tick failed at\n", .{});
        std.debug.print("PC: 0x{X}\n", .{self.registers.PC});
        std.debug.print("Op code: 0x{X} ({s} {s},{s})\n", .{
            op_code,
            @tagName(op_code_info.inst),
            if (op_code_info.op_1) |val| @tagName(val) else "null",
            if (op_code_info.op_2) |val| @tagName(val) else "null"
        });
    }

    // if (self.registers.PC == 0xC7F3) // ((op_code_info.op_1 orelse .A == .HL) or (op_code_info.op_2 orelse .A == .HL)))
    {
        // std.debug.print("Cpu tick failed at\n", .{});
        // std.debug.print("PC: 0x{X}\n", .{self.registers.PC});
        // std.debug.print("Op code: 0x{X} ({s} {s},{s})\n", .{
        //     op_code,
        //     @tagName(op_code_info.inst),
        //     if (op_code_info.op_1) |val| @tagName(val) else "null",
        //     if (op_code_info.op_2) |val| @tagName(val) else "null"
        // });
        // const wat: u16 = @intCast(u16, try self.readOperand(u8, op_code_info.op_2 orelse unreachable));
        // std.debug.print("FF ADDRESS: {X}\n", .{ (0xFF00 + wat)});
        // std.debug.print("SCANLINE: {X}\n", .{ (self.memory_bank.scanline_index)});
        // @panic("YO");
    }

    const halt_bug_applies = self.halt_bug_triggered;
    self.halt_bug_triggered = false;
    const instruction_result = try self.processInstruction(op_code_info);

    const cycles_taken = instruction_result.cycles_taken orelse op_code_info.cycles_taken;
    if (!halt_bug_applies) {
        self.registers.PC = instruction_result.new_pc orelse self.registers.PC + op_code_info.length;
    }
    
    if (comptime settings.debug and instruction_result.new_pc != null) {
        std.debug.print("Jumped to new PC 0x{X}\n", .{self.registers.PC});
    }

    return cycles_taken;
}

fn adjustFlagFromInstruction(self: *Cpu, flag: Flags, instruction_flag_state: OpCode.OperationFlagStates) void {
    self.setFlag(flag, switch(instruction_flag_state) {
        .Set => true,
        .Reset => false,
        else => self.getFlag(flag)
    });
}

fn handleCpuHalt(self: *Cpu) void {
    if (self.memory_bank.interrupt.interrupt_master_enable) {

        // If IME is enabled and an interrupt is pending, CPU is woken up
        if (self.memory_bank.interrupt.isAnyInterruptPending()) {
            self.cpu_halted = false;
        }
    } else {
        if (self.memory_bank.interrupt.isAnyInterruptPending()) {
            self.cpu_halted = false;
            self.halt_bug_triggered = true;
        }
    }
}

pub fn tickInterrupts(self: *Cpu) CpuErrors!u32 {
    var bit_offset: u3 = 0;
    var cycles_consumed: u32 = 0;

    if (self.cpu_halted) {
        self.handleCpuHalt();
    }

    while (bit_offset < 5) : (bit_offset += 1) {
        const interrupt = @intToEnum(Interrupt.Types, @intCast(u8, 0x1) << bit_offset);

        if (self.memory_bank.interrupt.isInterruptRequested(interrupt) and self.memory_bank.interrupt.isInterruptEnabled(interrupt)) {
            try self.pushStack(self.registers.PC);
            self.registers.PC = switch(interrupt) {
                .VBlank => 0x40,
                .LCDStat => 0x48,
                .Timer => 0x50,
                .Serial => 0x58,
                .Joypad => 0x60,
                else => return CpuErrors.InvalidInterrupt
            };

            if (comptime settings.debug) {
                std.debug.print("Processed interrupt {s}", .{@tagName(interrupt)});
            }

            // Clear the relevant interrupt flags
            self.memory_bank.interrupt.interrupt_master_enable = false;
            self.memory_bank.interrupt.clearInterruptRequest(interrupt);

            const extra_cycle_cost: u32 = if (self.halt_bug_triggered) 4 else 0;
            cycles_consumed = 22 + extra_cycle_cost;
            break;
        }
    }
    
    if (self.IME_request) |value| {
        self.memory_bank.interrupt.interrupt_master_enable = value;
        self.IME_request = null;
    }

    return cycles_consumed;
}

fn processInstruction(self: *Cpu, op_code_info: OpCode.OpCodeInfo) CpuErrors!InstructionResult {
    const instruction_result = switch (op_code_info.inst) {
        .NOP => InstructionResult {},
        .HALT => try self.halt(op_code_info),
        .LD8 => try self.ld8(op_code_info),
        .LD8d => try self.ld8d(op_code_info),
        .LD8i => try self.ld8i(op_code_info),
        .LD8io_to => try self.ld8io_to(op_code_info),
        .LD8io_from => try self.ld8io_from(op_code_info),
        .LD16 => try self.ld16(op_code_info),
        .XOR => try self.xor(op_code_info),
        .CCF => try self.ccf(op_code_info),
        .OR => try self.doOr(op_code_info),
        .AND => try self.doAnd(op_code_info),
        .BIT => try self.bit(op_code_info),
        .SET => try self.set(op_code_info),
        .RES => try self.res(op_code_info),
        .SWAP => try self.swap(op_code_info),
        .RR => try self.rr(op_code_info),
        .RRC => try self.rrc(op_code_info),
        .SRA => try self.sra(op_code_info),
        .SRL => try self.srl(op_code_info),
        .RL => try self.rl(op_code_info),
        .RLC => try self.rlc(op_code_info),
        .SLA => try self.sla(op_code_info),
        .JR => try self.jr(op_code_info),
        .JP => try self.jp(op_code_info),
        .RET => try self.ret(op_code_info),
        .RETI => try self.reti(op_code_info),
        .RST => try self.rst(op_code_info),
        .CALL => try self.call(op_code_info),
        .PUSH => try self.push(op_code_info),
        .POP => try self.pop(op_code_info),
        .ADC => try self.adc(op_code_info),
        .ADD8 => try self.add8(op_code_info),
        .ADD16 => try self.add16(op_code_info),
        .ADD16_SPi8 => try self.add16_SPi8(op_code_info),
        .SUB => try self.sub(op_code_info),
        .SBC => try self.sbc(op_code_info),
        .INC8 => try self.inc8(op_code_info),
        .INC16 => try self.inc16(op_code_info),
        .DEC8 => try self.dec8(op_code_info),
        .DEC16 => try self.dec16(op_code_info),
        .CP => try self.cp(op_code_info),
        .EI => try self.ei(op_code_info),
        .DI => try self.di(op_code_info),
        .DAA => try self.daa(op_code_info),
        .CPL => try self.cpl(op_code_info),
        .SCF => try self.scf(op_code_info),
        // else => return CpuErrors.UnhandledOpCode,
    };
    
    self.adjustFlagFromInstruction(.Z, op_code_info.flags.Z);
    self.adjustFlagFromInstruction(.N, op_code_info.flags.N);
    self.adjustFlagFromInstruction(.H, op_code_info.flags.H);
    self.adjustFlagFromInstruction(.C, op_code_info.flags.C);

    return instruction_result;
}

fn readOperand(self: *Cpu, comptime T: type, operand: OpCode.Operands) CpuErrors!T {
    if (comptime settings.debug) {
        std.debug.print("Reading from Operand {s}\n", .{@tagName(operand)});
    }

    errdefer {
        std.debug.print("Read Operand not handled {s}\n", .{@tagName(operand)});
    }

    const type_size = @sizeOf(T);
    if (type_size == 1) {
        const ret_val = switch (operand) {
            .A => self.registers.AF.Hi,
            .F => self.registers.AF.Lo,
            .B => self.registers.BC.Hi,
            .C => self.registers.BC.Lo,
            .D => self.registers.DE.Hi,
            .E => self.registers.DE.Lo,
            .H => self.registers.HL.Hi,
            .L => self.registers.HL.Lo,
            .AF_Addr => try self.memory_bank.read(u8, self.registers.AF.ptr().*),
            .BC_Addr => try self.memory_bank.read(u8, self.registers.BC.ptr().*),
            .DE_Addr => try self.memory_bank.read(u8, self.registers.DE.ptr().*),
            .HL_Addr => try self.memory_bank.read(u8, self.registers.HL.ptr().*),
            .d16_Addr => blk: {
                const address = try self.memory_bank.read(u16, self.registers.PC + 1);
                break :blk try self.memory_bank.read(u8, address);                
            },
            .r8, .d8 => self.memory_bank.read(u8, self.registers.PC + 1),
            .Bit_0 => 0x1,
            .Bit_1 => 0x2,
            .Bit_2 => 0x4,
            .Bit_3 => 0x8,
            .Bit_4 => 0x10,
            .Bit_5 => 0x20,
            .Bit_6 => 0x40,
            .Bit_7 => 0x80,
            .Cond_C => @boolToInt(self.getFlag(.C)),
            .Cond_NC => @boolToInt(!self.getFlag(.C)),
            .Cond_Z => @boolToInt(self.getFlag(.Z)),
            .Cond_NZ => @boolToInt(!self.getFlag(.Z)),
            .True => 1,
            .False => 0,
            .Hex_00 => 0x00,
            .Hex_10 => 0x10,
            .Hex_20 => 0x20,
            .Hex_30 => 0x30,
            .Hex_08 => 0x08,
            .Hex_18 => 0x18,
            .Hex_28 => 0x28,
            .Hex_38 => 0x38,
            else => CpuErrors.OperandNotHandled,
        };

        return @bitCast(T, ret_val catch |err| return err);
    }
    else if (type_size == 2) {
        return switch (operand) {
            .AF => self.registers.AF.ptr().*,
            .BC => self.registers.BC.ptr().*,
            .DE => self.registers.DE.ptr().*,
            .HL => self.registers.HL.ptr().*,
            .SP => self.registers.SP,
            .AF_Addr => try self.memory_bank.read(T, self.registers.AF.ptr().*),
            .BC_Addr => try self.memory_bank.read(T, self.registers.BC.ptr().*),
            .DE_Addr => try self.memory_bank.read(T, self.registers.DE.ptr().*),
            .HL_Addr => try self.memory_bank.read(T, self.registers.HL.ptr().*),
            .d16 => try self.memory_bank.read(T, self.registers.PC + 1),
            .d16_Addr => blk: {
                const address = try self.memory_bank.read(u16, self.registers.PC + 1);
                break :blk try self.memory_bank.read(T, address);                
            },
            else => return CpuErrors.OperandNotHandled,
        };
    }
    else {
        return CpuErrors.OperandNotHandled;
    }
}

fn writeOperand(self: *Cpu, operand: OpCode.Operands, value: anytype) CpuErrors!void {
    if (comptime settings.debug) {
        std.debug.print("Writing value 0x{X} to Operand {s}\n", .{value, @tagName(operand)});
    }

    errdefer {
        std.debug.print("Write Operand not handled {s}\n", .{@tagName(operand)});
    }

    const ValueType = @TypeOf(value);

    const type_size = @sizeOf(ValueType);
    if (type_size == 1) {
        switch (operand) {
            .A => self.registers.AF.Hi = @bitCast(u8, value),
            .F => self.registers.AF.Lo = @bitCast(u8, value) & 0xF0,
            .B => self.registers.BC.Hi = @bitCast(u8, value),
            .C => self.registers.BC.Lo = @bitCast(u8, value),
            .D => self.registers.DE.Hi = @bitCast(u8, value),
            .E => self.registers.DE.Lo = @bitCast(u8, value),
            .H => self.registers.HL.Hi = @bitCast(u8, value),
            .L => self.registers.HL.Lo = @bitCast(u8, value),
            .AF_Addr => try self.memory_bank.write(self.registers.AF.ptr().*, value),
            .BC_Addr => try self.memory_bank.write(self.registers.BC.ptr().*, value),
            .DE_Addr => try self.memory_bank.write(self.registers.DE.ptr().*, value),
            .HL_Addr => try self.memory_bank.write(self.registers.HL.ptr().*, value),
            .d16_Addr => {
                const address = try self.memory_bank.read(u16, self.registers.PC + 1);
                try self.memory_bank.write(address, value);
            },
            else => return CpuErrors.OperandNotHandled,
        }
    }
    else if (type_size == 2) {
        switch (operand) {
            .AF => self.registers.AF.ptr().* = value & 0xFFF0,
            .BC => self.registers.BC.ptr().* = value,
            .DE => self.registers.DE.ptr().* = value,
            .HL => self.registers.HL.ptr().* = value,
            .SP => self.registers.SP = value,
            .AF_Addr => try self.memory_bank.write(self.registers.AF.ptr().*, value),
            .BC_Addr => try self.memory_bank.write(self.registers.BC.ptr().*, value),
            .DE_Addr => try self.memory_bank.write(self.registers.DE.ptr().*, value),
            .HL_Addr => try self.memory_bank.write(self.registers.HL.ptr().*, value),
            .d16_Addr => {
                const address = try self.memory_bank.read(u16, self.registers.PC + 1);
                try self.memory_bank.write(address, value);
            },
            else => return CpuErrors.OperandNotHandled,
        }
    }
    else {
        return CpuErrors.OperandNotHandled;
    }
}

fn getAddrOfNextInstruction(self: *Cpu, current_op_code_info: OpCode.OpCodeInfo) u16 {
    return self.registers.PC + current_op_code_info.length;
}
fn pushStack(self: *Cpu, value: anytype) CpuErrors!void {
    self.registers.SP -%= 1;
    self.registers.SP -%= @sizeOf(@TypeOf(value)) - 1;
    try self.memory_bank.write(self.registers.SP, value);
}


// INSTRUCTIONS
///////////////

fn halt(self: *Cpu, op_code_info: OpCode.OpCodeInfo) CpuErrors!InstructionResult {
    _ = op_code_info;
    self.cpu_halted = true;
    return .{};
}

fn ld8i(self: *Cpu, op_code_info: OpCode.OpCodeInfo) CpuErrors!InstructionResult {
    const result = try self.ld8(op_code_info);
    self.registers.HL.ptr().* +%= 1;
    return result;
}

fn ld8d(self: *Cpu, op_code_info: OpCode.OpCodeInfo) CpuErrors!InstructionResult {
    const result = self.ld8(op_code_info);
    self.registers.HL.ptr().* -%= 1;
    return result;
}

fn ld8io_to(self: *Cpu, op_code_info: OpCode.OpCodeInfo) CpuErrors!InstructionResult {
    const io_address: u16 = 0xFF00 + @intCast(u16, try self.readOperand(u8, op_code_info.op_1 orelse return CpuErrors.MissingOperand));
    try self.memory_bank.write(
        io_address,
        try self.readOperand(u8, op_code_info.op_2 orelse return CpuErrors.MissingOperand));
    return .{};
}

fn ld8io_from(self: *Cpu, op_code_info: OpCode.OpCodeInfo) CpuErrors!InstructionResult {
    const io_address: u16 = 0xFF00 + @intCast(u16, try self.readOperand(u8, op_code_info.op_2 orelse return CpuErrors.MissingOperand));
    const io_value = try self.memory_bank.read(u8, io_address);
    try self.writeOperand(
        op_code_info.op_1 orelse return CpuErrors.MissingOperand,
        io_value);
    return .{};
}

fn ld8(self: *Cpu, op_code_info: OpCode.OpCodeInfo) CpuErrors!InstructionResult {
    try self.writeOperand(
        op_code_info.op_1 orelse return CpuErrors.MissingOperand,
        try self.readOperand(u8, op_code_info.op_2 orelse return CpuErrors.MissingOperand));
    return .{};
}

fn ld16(self: *Cpu, op_code_info: OpCode.OpCodeInfo) CpuErrors!InstructionResult {
    try self.writeOperand(
        op_code_info.op_1 orelse return CpuErrors.MissingOperand,
        try self.readOperand(u16, op_code_info.op_2 orelse return CpuErrors.MissingOperand));
    return .{};
}

fn xor(self: *Cpu, op_code_info: OpCode.OpCodeInfo) CpuErrors!InstructionResult {
    const operand_value = try self.readOperand(u8, op_code_info.op_1 orelse return CpuErrors.MissingOperand);
    const result_value = self.registers.AF.Hi ^ operand_value;

    self.setFlag(.Z, result_value == 0);
    try self.writeOperand(.A, result_value);
    return .{};
}

fn ccf(self: *Cpu, op_code_info: OpCode.OpCodeInfo) CpuErrors!InstructionResult {
    _ = op_code_info;
    self.setFlag(.C, !self.getFlag(.C));
    return .{};
}

fn doOr(self: *Cpu, op_code_info: OpCode.OpCodeInfo) CpuErrors!InstructionResult {
    const operand_value = try self.readOperand(u8, op_code_info.op_1 orelse return CpuErrors.MissingOperand);
    const result_value = self.registers.AF.Hi | operand_value;

    self.setFlag(.Z, result_value == 0);
    try self.writeOperand(.A, result_value);
    return .{};
}

fn doAnd(self: *Cpu, op_code_info: OpCode.OpCodeInfo) CpuErrors!InstructionResult {
    const operand_value = try self.readOperand(u8, op_code_info.op_1 orelse return CpuErrors.MissingOperand);
    const result_value = self.registers.AF.Hi & operand_value;

    self.setFlag(.Z, result_value == 0);
    try self.writeOperand(.A, result_value);
    return .{};
}

fn bit(self: *Cpu, op_code_info: OpCode.OpCodeInfo) CpuErrors!InstructionResult {
    const bit_operand = try self.readOperand(u8, op_code_info.op_1 orelse return CpuErrors.MissingOperand);
    const target_operand = try self.readOperand(u8, op_code_info.op_2 orelse return CpuErrors.MissingOperand);
    const result_value = target_operand & bit_operand;

    self.setFlag(.Z, result_value == 0);
    return .{};
}

fn res(self: *Cpu, op_code_info: OpCode.OpCodeInfo) CpuErrors!InstructionResult {
    const bit_operand = try self.readOperand(u8, op_code_info.op_1 orelse return CpuErrors.MissingOperand);
    const target_operand = try self.readOperand(u8, op_code_info.op_2 orelse return CpuErrors.MissingOperand);
    const result_value: u8 = target_operand & (~bit_operand);
    try self.writeOperand(
        op_code_info.op_2 orelse return CpuErrors.MissingOperand,
        result_value
    );

    return .{};
}

fn swap(self: *Cpu, op_code_info: OpCode.OpCodeInfo) CpuErrors!InstructionResult {
    const target_operand = try self.readOperand(u8, op_code_info.op_1 orelse return CpuErrors.MissingOperand);
    const result_value: u8 = ((target_operand & 0xF) << 4) | ((target_operand & 0xF0) >> 4);
    
    self.setFlag(.Z, result_value == 0);
    
    try self.writeOperand(
        op_code_info.op_1 orelse return CpuErrors.MissingOperand,
        result_value
    );

    return .{};
}

fn set(self: *Cpu, op_code_info: OpCode.OpCodeInfo) CpuErrors!InstructionResult {
    const bit_operand = try self.readOperand(u8, op_code_info.op_1 orelse return CpuErrors.MissingOperand);
    const target_operand = try self.readOperand(u8, op_code_info.op_2 orelse return CpuErrors.MissingOperand);
    const result_value: u8 = target_operand | bit_operand;
    try self.writeOperand(
        op_code_info.op_2 orelse return CpuErrors.MissingOperand,
        result_value
    );

    return .{};
}

fn rr(self: *Cpu, op_code_info: OpCode.OpCodeInfo) CpuErrors!InstructionResult {

    const target_operand = try self.readOperand(u8, op_code_info.op_2 orelse return CpuErrors.MissingOperand);

    const prev_carry = self.getFlag(.C);
    self.setFlag(.C, target_operand & 0x1 != 0);

    const result_value = (target_operand >> 1) | (@intCast(u8, @boolToInt(prev_carry)) << 7);
    if (op_code_info.flags.Z == .Dependent) {
        self.setFlag(.Z, result_value == 0);
    }

    try self.writeOperand(op_code_info.op_1 orelse return CpuErrors.MissingOperand, result_value);
    
    return .{};
}

fn rl(self: *Cpu, op_code_info: OpCode.OpCodeInfo) CpuErrors!InstructionResult {

    const target_operand = try self.readOperand(u8, op_code_info.op_2 orelse return CpuErrors.MissingOperand);

    const prev_carry = self.getFlag(.C);
    self.setFlag(.C, target_operand & 0x80 != 0);

    const result_value = (target_operand << 1) | @boolToInt(prev_carry);//std.math.rotl(u8, 1, target_operand);
    if (op_code_info.flags.Z == .Dependent) {
        self.setFlag(.Z, result_value == 0);
    }

    try self.writeOperand(op_code_info.op_1 orelse return CpuErrors.MissingOperand, result_value);
    
    return .{};
}

fn rlc(self: *Cpu, op_code_info: OpCode.OpCodeInfo) CpuErrors!InstructionResult {

    const target_operand = try self.readOperand(u8, op_code_info.op_1 orelse return CpuErrors.MissingOperand);
    const result = std.math.rotl(u8, target_operand, 1);

    self.setFlag(.C, result & 0x1 != 0);
    self.setFlag(.Z, result == 0);
    
    try self.writeOperand(op_code_info.op_1 orelse return CpuErrors.MissingOperand, result);
    
    return .{};
}

fn rrc(self: *Cpu, op_code_info: OpCode.OpCodeInfo) CpuErrors!InstructionResult {

    const target_operand = try self.readOperand(u8, op_code_info.op_1 orelse return CpuErrors.MissingOperand);
    const result = std.math.rotr(u8, target_operand, 1);

    self.setFlag(.C, result & 0x80 != 0);
    self.setFlag(.Z, result == 0);
    
    try self.writeOperand(op_code_info.op_1 orelse return CpuErrors.MissingOperand, result);
    
    return .{};
}

fn sla(self: *Cpu, op_code_info: OpCode.OpCodeInfo) CpuErrors!InstructionResult {
    const target_operand = try self.readOperand(u8, op_code_info.op_1 orelse return CpuErrors.MissingOperand);
    const result = target_operand << 1;

    self.setFlag(.C, target_operand & 0x80 != 0);
    self.setFlag(.Z, result == 0);
    
    try self.writeOperand(op_code_info.op_1 orelse return CpuErrors.MissingOperand, result);
    
    return .{};
}

fn sra(self: *Cpu, op_code_info: OpCode.OpCodeInfo) CpuErrors!InstructionResult {

    const target_operand = try self.readOperand(u8, op_code_info.op_1 orelse return CpuErrors.MissingOperand);
    const result = (target_operand >> 1) | (target_operand & 0x80);

    self.setFlag(.C, target_operand & 0x1 != 0);
    self.setFlag(.Z, result == 0);
    
    try self.writeOperand(op_code_info.op_1 orelse return CpuErrors.MissingOperand, result);
    
    return .{};
}

fn srl(self: *Cpu, op_code_info: OpCode.OpCodeInfo) CpuErrors!InstructionResult {

    const target_operand = try self.readOperand(u8, op_code_info.op_1 orelse return CpuErrors.MissingOperand);

    const result_value = target_operand >> 1;
    self.setFlag(.Z, result_value == 0);
    self.setFlag(.C, target_operand & 0x1 != 0);

    try self.writeOperand(op_code_info.op_1 orelse return CpuErrors.MissingOperand, result_value);
    
    return .{};
}

fn jr(self: *Cpu, op_code_info: OpCode.OpCodeInfo) CpuErrors!InstructionResult {
    const condition: bool = try self.readOperand(u8, op_code_info.op_1 orelse return CpuErrors.MissingOperand) != 0;
    const offset: i8 = try self.readOperand(i8, op_code_info.op_2 orelse return CpuErrors.MissingOperand);
    const new_pc: u16 = self.getAddrOfNextInstruction(op_code_info) +% @bitCast(u16, @intCast(i16, offset));
    
    return .{ 
        .cycles_taken = if (condition) 8 else 12,
        .new_pc = if (condition) new_pc else null
    };
}

fn jp(self: *Cpu, op_code_info: OpCode.OpCodeInfo) CpuErrors!InstructionResult {
    const has_condition = op_code_info.op_1 != null and op_code_info.op_2 != null;
    const condition: bool = blk: {
        if (has_condition) {
            break :blk try self.readOperand(u8, op_code_info.op_1 orelse return CpuErrors.MissingOperand) != 0;
        }
        break :blk true;
    };
    const new_pc: u16 = blk: {
        const pc_operand = if (has_condition) op_code_info.op_2 else op_code_info.op_1;
        break :blk try self.readOperand(u16, pc_operand orelse return CpuErrors.MissingOperand);
    };
    
    return .{ 
        .cycles_taken = if (condition) op_code_info.cycles_taken else 12,
        .new_pc = if (condition) new_pc else null
    };
}

fn ret(self: *Cpu, op_code_info: OpCode.OpCodeInfo) CpuErrors!InstructionResult {
    // Condition is optional so we can handle both RET C/NC/Z/NZ and RET here
    const has_condition = op_code_info.op_1 != null;
    const should_jump: bool = blk: {
        if (op_code_info.op_1) | op | {
            break :blk try self.readOperand(u8, op) != 0;
        } else {
            break :blk true;
        }
    };

    const cycles_taken = blk: {
        if (has_condition) {
            break :blk if (should_jump) op_code_info.cycles_taken else 8;
        } else {
            break :blk op_code_info.cycles_taken;
        }
    };

    const new_pc = try self.memory_bank.read(u16, self.registers.SP);
    if (should_jump) {
        self.registers.SP += 2;
    }

    return .{ 
        .cycles_taken = cycles_taken,
        .new_pc = if (should_jump) new_pc else null
    };
}

fn reti(self: *Cpu, op_code_info: OpCode.OpCodeInfo) CpuErrors!InstructionResult {
    const result = self.ret(op_code_info);
    self.memory_bank.interrupt.interrupt_master_enable = true;
    return result;
}

fn rst(self: *Cpu, op_code_info: OpCode.OpCodeInfo) CpuErrors!InstructionResult {
    const target_address = try self.readOperand(u8, op_code_info.op_1 orelse return CpuErrors.MissingOperand);
    try self.pushStack(self.getAddrOfNextInstruction(op_code_info));
    
    return .{ 
        .new_pc = @intCast(u16, target_address),
    };
}

fn call(self: *Cpu, op_code_info: OpCode.OpCodeInfo) CpuErrors!InstructionResult {
    const has_condition = op_code_info.op_1 != null and op_code_info.op_2 != null;
    const condition: bool = blk: {
        if (has_condition) {
            break :blk try self.readOperand(u8, op_code_info.op_1 orelse return CpuErrors.MissingOperand) != 0;
        }
        break :blk true;
    };
    const new_pc: u16 = blk: {
        const pc_operand = if (has_condition) op_code_info.op_2 else op_code_info.op_1;
        break :blk try self.readOperand(u16, pc_operand orelse return CpuErrors.MissingOperand);
    };

    if (condition) {
        try self.pushStack(self.getAddrOfNextInstruction(op_code_info));
    }
    
    return .{ 
        .cycles_taken = if (condition) op_code_info.cycles_taken else 12,
        .new_pc = if (condition) new_pc else null
    };
}

fn push(self: *Cpu, op_code_info: OpCode.OpCodeInfo) CpuErrors!InstructionResult {
    const value_to_push: u16 = try self.readOperand(u16, op_code_info.op_1 orelse return CpuErrors.MissingOperand);
    
    try self.pushStack(value_to_push);

    return .{};
}

fn pop(self: *Cpu, op_code_info: OpCode.OpCodeInfo) CpuErrors!InstructionResult {
    // Write value of memory at SP into operand
    try self.writeOperand(
        op_code_info.op_1 orelse return CpuErrors.MissingOperand,
        try self.memory_bank.read(u16, self.registers.SP));
    
    self.registers.SP += 2;

    return .{};
}

fn inc8(self: *Cpu, op_code_info: OpCode.OpCodeInfo) CpuErrors!InstructionResult {
    const inital_value = try self.readOperand(u8, op_code_info.op_1 orelse return CpuErrors.MissingOperand);
    const result = inital_value +% 1;
    try self.writeOperand(
        op_code_info.op_1 orelse return CpuErrors.MissingOperand,
        result);

    self.setFlag(.Z, result == 0);
    self.setFlag(.H, result & 0x0F == 0x00);
    return .{};
}

fn inc16(self: *Cpu, op_code_info: OpCode.OpCodeInfo) CpuErrors!InstructionResult {
    const inital_value = try self.readOperand(u16, op_code_info.op_1 orelse return CpuErrors.MissingOperand);
    const result = inital_value +% 1;
    try self.writeOperand(
        op_code_info.op_1 orelse return CpuErrors.MissingOperand,
        result);

    return .{};
}

fn dec8(self: *Cpu, op_code_info: OpCode.OpCodeInfo) CpuErrors!InstructionResult {
    const first_operand = try self.readOperand(u8, op_code_info.op_1 orelse return CpuErrors.MissingOperand);
    const second_operand: u8 = 1;
    const result = first_operand -% second_operand;
    try self.writeOperand(
        op_code_info.op_1 orelse return CpuErrors.MissingOperand,
        result);

    self.setFlag(.Z, result == 0);
    self.setFlag(.H, (first_operand & 0xF) < (second_operand & 0xF));
    return .{};
}

fn dec16(self: *Cpu, op_code_info: OpCode.OpCodeInfo) CpuErrors!InstructionResult {
    const first_operand = try self.readOperand(u16, op_code_info.op_1 orelse return CpuErrors.MissingOperand);
    const second_operand: u16 = 1;
    const result = first_operand -% second_operand;
    try self.writeOperand(
        op_code_info.op_1 orelse return CpuErrors.MissingOperand,
        result);
    return .{};
}

fn cp(self: *Cpu, op_code_info: OpCode.OpCodeInfo) CpuErrors!InstructionResult {
    const operand_value = try self.readOperand(u8, op_code_info.op_1 orelse return CpuErrors.MissingOperand);
    const result = self.registers.AF.Hi -% operand_value;

    self.setFlag(.Z, result == 0);
    self.setFlag(.H, (self.registers.AF.Hi & 0xF) < (operand_value & 0xF));
    self.setFlag(.C, self.registers.AF.Hi < operand_value);
    return .{};
}

fn adc(self: *Cpu, op_code_info: OpCode.OpCodeInfo) CpuErrors!InstructionResult {
    const first_operand = try self.readOperand(u8, op_code_info.op_1 orelse return CpuErrors.MissingOperand);
    const second_operand = try self.readOperand(u8, op_code_info.op_2 orelse return CpuErrors.MissingOperand);

    var result: u8 = undefined;
    var overflow: bool = @addWithOverflow(u8, first_operand, second_operand, &result);
    overflow = @addWithOverflow(u8, result, @boolToInt(self.getFlag(.C)), &result) or overflow;

    self.setFlag(.Z, result == 0);
    self.setFlag(.H, (first_operand & 0xF) + (second_operand & 0xF) + @boolToInt(self.getFlag(.C)) > 0xF);
    self.setFlag(.C, overflow);

    try self.writeOperand(op_code_info.op_1 orelse return CpuErrors.MissingOperand, result);
    return .{};
}

fn add8(self: *Cpu, op_code_info: OpCode.OpCodeInfo) CpuErrors!InstructionResult {
    const first_operand = try self.readOperand(u8, op_code_info.op_1 orelse return CpuErrors.MissingOperand);
    const second_operand = try self.readOperand(u8, op_code_info.op_2 orelse return CpuErrors.MissingOperand);
    var result: u8 = undefined;
    const overflow: bool = @addWithOverflow(u8, first_operand, second_operand, &result);

    self.setFlag(.Z, result == 0);
    self.setFlag(.H, (first_operand & 0xF) + (second_operand & 0xF) > 0xF);
    self.setFlag(.C, overflow);

    try self.writeOperand(op_code_info.op_1 orelse return CpuErrors.MissingOperand, result);
    return .{};
}

fn add16(self: *Cpu, op_code_info: OpCode.OpCodeInfo) CpuErrors!InstructionResult {
    const first_operand = try self.readOperand(u16, op_code_info.op_1 orelse return CpuErrors.MissingOperand);
    const second_operand = try self.readOperand(u16, op_code_info.op_2 orelse return CpuErrors.MissingOperand);
    var result: u16 = undefined;
    const overflow: bool = @addWithOverflow(u16, first_operand, second_operand, &result);

    self.setFlag(.H, (first_operand & 0xFFF) + (second_operand & 0xFFF) > 0xFFF);
    self.setFlag(.C, overflow);

    try self.writeOperand(op_code_info.op_1 orelse return CpuErrors.MissingOperand, result);
    return .{};
}

fn add16_SPi8(self: *Cpu, op_code_info: OpCode.OpCodeInfo) CpuErrors!InstructionResult {
    const first_operand: u16 = self.registers.SP;
    const offset: i8 = try self.readOperand(i8, op_code_info.op_2 orelse return CpuErrors.MissingOperand);
    const positive_offset: u8 = std.math.absCast(offset);

    var result: u16 = undefined;
    if (offset < 0) {
        result = first_operand -% positive_offset;
        self.setFlag(.H, (result & 0xF) <= (first_operand & 0xF));
        self.setFlag(.C, (result & 0xFF) <= (first_operand & 0xFF));
    } else {
        result = first_operand +% positive_offset;
        self.setFlag(.H, ((first_operand & 0xF) +% (positive_offset & 0xF)) > 0xF);
        self.setFlag(.C, ((first_operand & 0xFF) +% positive_offset) > 0xFF);
    }

    try self.writeOperand(op_code_info.op_1 orelse return CpuErrors.MissingOperand, result);
    return .{};
}

fn sub(self: *Cpu, op_code_info: OpCode.OpCodeInfo) CpuErrors!InstructionResult {
    const operand_value = try self.readOperand(u8, op_code_info.op_1 orelse return CpuErrors.MissingOperand);
    const result = self.registers.AF.Hi -% operand_value;

    self.setFlag(.Z, result == 0);
    self.setFlag(.H, (self.registers.AF.Hi & 0xF) < (operand_value & 0xF));
    self.setFlag(.C, self.registers.AF.Hi < operand_value);

    try self.writeOperand(.A, result);
    return .{};
}

fn sbc(self: *Cpu, op_code_info: OpCode.OpCodeInfo) CpuErrors!InstructionResult {
    //var result = undefined;
    const first_operand = try self.readOperand(u8, op_code_info.op_1 orelse return CpuErrors.MissingOperand);
    const second_operand = try self.readOperand(u8, op_code_info.op_2 orelse return CpuErrors.MissingOperand);
    const first_operand_i32 = @intCast(i32, first_operand);
    const second_operand_i32 = @intCast(i32, second_operand);
    
    const result_full: i32 = first_operand_i32 - second_operand_i32 - @boolToInt(self.getFlag(.C));
    const half_full: i32 = (first_operand_i32 & 0xF) - (second_operand_i32 & 0xF) - @boolToInt(self.getFlag(.C));
    const result = first_operand -% second_operand -% @boolToInt(self.getFlag(.C));

    self.setFlag(.Z, result == 0);
    self.setFlag(.H, half_full < 0);
    self.setFlag(.C, result_full < 0);

    try self.writeOperand(op_code_info.op_1 orelse return CpuErrors.MissingOperand, @intCast(u8, result));
    return .{};
}

fn ei(self: *Cpu, op_code_info: OpCode.OpCodeInfo) CpuErrors!InstructionResult {
    _ = op_code_info;
    self.IME_request = true;
    return .{};
}

fn di(self: *Cpu, op_code_info: OpCode.OpCodeInfo) CpuErrors!InstructionResult {
    _ = op_code_info;
    self.memory_bank.interrupt.interrupt_master_enable = false;
    return .{};
}

fn daa(self: *Cpu, op_code_info: OpCode.OpCodeInfo) CpuErrors!InstructionResult {
    _ = op_code_info;

    const target_operand = try self.readOperand(u8, .A);
    var result = target_operand;
    if (self.getFlag(.N)) {
        if (self.getFlag(.C)) { result -%= 0x60; self.setFlag(.C, true); }
        if (self.getFlag(.H)) { result -%= 0x6; }
    } else { 
        if (self.getFlag(.C) or (target_operand > 0x99)) { result +%= 0x60; self.setFlag(.C, true); }
        if (self.getFlag(.H) or ((target_operand & 0xF) > 0x9)) { result +%= 0x6; }
    }
    self.setFlag(.Z, result == 0);
    try self.writeOperand(.A, result);
    return .{};
}

fn cpl(self: *Cpu, op_code_info: OpCode.OpCodeInfo) CpuErrors!InstructionResult {
    _ = op_code_info;

    const target_operand = try self.readOperand(u8, .A);
    try self.writeOperand(.A, ~target_operand);
    return .{};
}

fn scf(self: *Cpu, op_code_info: OpCode.OpCodeInfo) CpuErrors!InstructionResult {
    _ = op_code_info;

    self.setFlag(.C, true);
    return .{};
}

test "Cpu Lo/Hi register access" {
    var memory_bank = MemoryBank {};
    var cpu = Cpu.init(&memory_bank);

    // Check individual Lo/Hi 8 bit assignment
    cpu.registers.DE.Lo = 0xAB;
    cpu.registers.DE.Hi = 0xCD;
    try testing.expectEqual(@intCast(u16, 0xCDAB), @bitCast(u16, cpu.registers.DE));

    // Check 16 bit assignment
    cpu.registers.DE.ptr().* = 0xAABB;
    try testing.expectEqual(@intCast(u8, 0xBB), cpu.registers.DE.Lo);
    try testing.expectEqual(@intCast(u8, 0xAA), cpu.registers.DE.Hi);
}

test "Cpu flags access" {
    var memory_bank = MemoryBank {};
    var cpu = Cpu.init(&memory_bank);
    cpu.setFlag(.N, true);
    cpu.setFlag(.C, true);
    cpu.setFlag(.Z, true);
    cpu.setFlag(.N, false);

    try testing.expect(cpu.getFlag(.C));
    try testing.expect(cpu.getFlag(.Z));
    try testing.expect(!cpu.getFlag(.N));
}

test "Cpu ld8 access" {
    var memory_bank = MemoryBank {};
    var cpu = Cpu.init(&memory_bank);
    cpu.registers.BC.Lo = 0xEF;
    cpu.registers.DE.Lo = 0xAA;

    const op_code_info = OpCode.OpCodeInfo.init(.LD8, .E, .C, 0, 0, .{});
    _ = try cpu.processInstruction(op_code_info);

    try testing.expectEqual(@intCast(u8, 0xEF), cpu.registers.DE.Lo);
    try testing.expectEqual(@intCast(u8, 0xEF), cpu.registers.BC.Lo);
}

test "Cpu ld16 address access" {
    var memory_bank = MemoryBank {};
    var cpu = Cpu.init(&memory_bank);
    const value_to_write: u16 = 0xCCDD;

    // Write value to memorybank
    try cpu.memory_bank.write(0xC000, value_to_write);
    // Make HL register point to the address in the memorybank
    cpu.registers.HL.ptr().* = 0xC000;

    // Do a ld operation from (HL) to BC
    const op_code_info = OpCode.OpCodeInfo.init(.LD16, .BC, .HL_Addr, 0, 0, .{});
    _ = try cpu.processInstruction(op_code_info);

    try testing.expectEqual(value_to_write, cpu.registers.BC.ptr().*);
}

test "Cpu inc flag check" {
    var memory_bank = MemoryBank {};
    var cpu = Cpu.init(&memory_bank);
    const op_code_info = OpCode.OpCodeInfo.init(.INC8, .A, null, 0, 0, .{ .Z = .Dependent, .N = .Reset, .H = .Dependent});

    cpu.registers.AF.Hi = 0x0F;
    _ = try cpu.processInstruction(op_code_info);

    try testing.expect(cpu.getFlag(.H));
    try testing.expectEqual(@intCast(u8, 0x10), cpu.registers.AF.Hi);

     cpu.registers.AF.Hi = 0x0E;
    _ = try cpu.processInstruction(op_code_info);

    try testing.expect(!cpu.getFlag(.H));
    try testing.expectEqual(@intCast(u8, 0x0F), cpu.registers.AF.Hi);
}

test "Cpu xor flag check" {
    var memory_bank = MemoryBank {};
    var cpu = Cpu.init(&memory_bank);

    cpu.registers.DE.Lo = 0x11;
    cpu.registers.AF.Hi = 0x11;

    const op_code_info = OpCode.OpCodeInfo.init(.XOR, .E, null, 0, 0, .{ .Z = .Dependent, .N = .Reset, .H = .Reset, .C = .Reset});
    _ = try cpu.processInstruction(op_code_info);

    try testing.expect(cpu.getFlag(.Z));
    try testing.expect(!cpu.getFlag(.N));
    try testing.expect(!cpu.getFlag(.H));
    try testing.expect(!cpu.getFlag(.C));

    cpu.registers.DE.Lo = 0x10;
    cpu.registers.AF.Hi = 0x11;

    _ = try cpu.processInstruction(op_code_info);

    try testing.expect(!cpu.getFlag(.Z));
    try testing.expect(!cpu.getFlag(.N));
    try testing.expect(!cpu.getFlag(.H));
    try testing.expect(!cpu.getFlag(.C));
}

test "Cpu bit flag check" {
    var memory_bank = MemoryBank {};
    var cpu = Cpu.init(&memory_bank);
    const op_code_info = OpCode.OpCodeInfo.init(.BIT, .Bit_7, .B, 2, 8, .{.Z = .Dependent, .N = .Reset, .H = .Set });

    // 7th bit set
    cpu.registers.BC.Hi = 0x80;
    _ = try cpu.processInstruction(op_code_info);

    try testing.expect(!cpu.getFlag(.Z));

    // 7th bit unset
    cpu.registers.BC.Hi = 0x40;
    _ = try cpu.processInstruction(op_code_info);

    try testing.expect(cpu.getFlag(.Z));
}

test "Cpu signed operands" {
    var memory_bank = MemoryBank {};
    var cpu = Cpu.init(&memory_bank);

    const negative_value: i8 = -23;
    try cpu.writeOperand(.B, negative_value);

    const read_value = try cpu.readOperand(i8, .B);
    try testing.expectEqual(negative_value, read_value);
}

test "Cpu push stack" {
    var memory_bank = MemoryBank {};
    var cpu = Cpu.init(&memory_bank);
    cpu.registers.SP = 0xFFFE;

    const val: u16 = 0xAABB;
    try cpu.pushStack(val);

    try testing.expectEqual(val, try memory_bank.read(u16, cpu.registers.SP));
}

test "Cpu dec8 flags" {
    var memory_bank = MemoryBank {};
    var cpu = Cpu.init(&memory_bank);
    const op_code_info = OpCode.OpCodeInfo.init(.DEC8, .C, null, 1, 4, .{.Z = .Dependent, .N = .Set, .H = .Dependent });

    cpu.registers.BC.Lo = 0x10;
    _ = try cpu.processInstruction(op_code_info);

    try testing.expect(!cpu.getFlag(.Z));
    try testing.expect(cpu.getFlag(.H));
}

test "Cpu add16 flags" {
    var memory_bank = MemoryBank {};
    var cpu = Cpu.init(&memory_bank);
    const op_code_info = OpCode.OpCodeInfo.init(.ADD16, .HL, .HL, 1, 8, .{ .Z = .Unchanged, .N = .Reset, .H = .Dependent, .C = .Dependent });

    cpu.registers.HL.ptr().* = 0x2610;
    _ = try cpu.processInstruction(op_code_info);

    try testing.expect(!cpu.getFlag(.H));
    try testing.expect(!cpu.getFlag(.C));
}

test "Cpu swap flags" {
    var memory_bank = MemoryBank {};
    var cpu = Cpu.init(&memory_bank);
    const op_code_info = OpCode.OpCodeInfo.init(.SWAP, .B, null, 2, 8, .{ .Z = .Dependent, .N = .Reset, .H = .Reset, .C = .Reset });

    cpu.registers.BC.Hi = 0xAB;
    _ = try cpu.processInstruction(op_code_info);

    try testing.expectEqual(@intCast(u8, 0xBA), cpu.registers.BC.Hi);
}

test "Cpu add16_SPi8 flags" {
    var memory_bank = MemoryBank {};
    var cpu = Cpu.init(&memory_bank);
    const op_code_info = OpCode.OpCodeInfo.init(.ADD16_SPi8, .HL, .B, 2, 12, .{ .Z = .Reset, .N = .Reset, .H = .Dependent, .C = .Dependent });

    const signed_val: i8 = -2;
    cpu.registers.BC.Hi = @bitCast(u8, signed_val);
    cpu.registers.SP = 0xDFFD;
    _ = try cpu.processInstruction(op_code_info);

    try testing.expectEqual(@intCast(u16, 0xDFFB), cpu.registers.HL.ptr().*);

    try testing.expect(cpu.getFlag(.H));
    try testing.expect(cpu.getFlag(.C));
}

test "Cpu sbc flags" {
    var memory_bank = MemoryBank {};
    var cpu = Cpu.init(&memory_bank);
    const op_code_info = OpCode.OpCodeInfo.init(.SBC, .A, .C, 1, 4, .{ .Z = .Dependent, .N = .Set, .H = .Dependent, .C = .Dependent });

    cpu.registers.AF.Hi = 0x10;
    cpu.registers.BC.Lo = 0x10;
    cpu.setFlag(.C, true);
    _ = try cpu.processInstruction(op_code_info);

    try testing.expectEqual(@intCast(u8, 0) -% 1, cpu.registers.AF.Hi);

    try testing.expect(cpu.getFlag(.H));
    try testing.expect(cpu.getFlag(.C));
}