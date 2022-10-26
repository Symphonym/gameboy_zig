
const MemoryBank = @import("MemoryBank.zig");
const Timer = @This();

divider: u8 = 0,
counter: u8 = 0,
modulo: u8 = 0,
control: u8 = 0,

cycles_processed: u32 = 0,
divider_cycles_processed: u32 = 0,

pub const TimerSpeed = enum(u8) {
    Cpu_Div_1024 = 0,
    Cpu_Div_16 = 1,
    Cpu_Div_64 = 2,
    Cpu_Div_256 = 3,
};

pub fn init(memory_bank: *MemoryBank) Timer {
    return .{
        .memory_bank = memory_bank
    };
}

pub fn tick(self: *Timer, cycles_taken: u32, memory_bank: *MemoryBank) void {
    self.tickDivider(cycles_taken);
    self.tickTimer(cycles_taken, memory_bank);
}

fn tickTimer(self: *Timer, cycles_taken: u32, memory_bank: *MemoryBank) void {
    if (!self.isTimerEnabled()) {
        return;
    }
    
    const cycles_needed: u32 = switch(self.getTimerSpeed()) {
        .Cpu_Div_1024 => 1024,
        .Cpu_Div_16 => 16,
        .Cpu_Div_64 => 64,
        .Cpu_Div_256 => 256,
    };

    self.cycles_processed += cycles_taken;
    if (self.cycles_processed >= cycles_needed) {
        var result: u8 = 0;
        if (@addWithOverflow(u8, self.counter, 1, &result)) {
            memory_bank.interrupt.requestInterrupt(.Timer);
            self.counter = self.modulo;
        } else {
            self.counter = result;
        }
        self.cycles_processed = 0;
    }
}

fn tickDivider(self: *Timer, cycles_taken: u32) void {
    self.divider_cycles_processed += cycles_taken;
    if (self.divider_cycles_processed >= 256) {
        var result: u8 = 0;
        if (@addWithOverflow(u8, self.divider, 1, &result)) {
            self.divider = self.modulo;
        } else {
            self.divider = result;
        }
        self.cycles_processed = 0;
    }
}

pub fn getTimerSpeed(self: Timer) TimerSpeed {
    return @intToEnum(TimerSpeed, (self.control & 0x3) >> 1);
}

pub fn isTimerEnabled(self: Timer) bool {
    return self.control & 0x4 != 0;
}