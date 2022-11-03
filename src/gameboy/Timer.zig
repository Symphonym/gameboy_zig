const std = @import("std");
const testing = std.testing;

const Interrupt = @import("Interrupt.zig");
const Timer = @This();


internal_counter: u16 = 0xABCC,

counter: u8 = 0, // TIMA
modulo: u8 = 0, // TMA
control: u8 = 0, // TAC

cycles_processed: u32 = 0,
divider_cycles_processed: u32 = 0,
previous_obscure_bit: bool = false,
request_interrupt: bool = false,

pub const TimerSpeed = enum(u8) {
    Cpu_Div_1024 = 0,
    Cpu_Div_16 = 1,
    Cpu_Div_64 = 2,
    Cpu_Div_256 = 3,

    pub fn getCyclesRequired(self: TimerSpeed) u16 {
        return switch (self) {
            .Cpu_Div_1024 => 1024,
            .Cpu_Div_16 => 16,
            .Cpu_Div_64 => 64,
            .Cpu_Div_256 => 256,
        };
    }
};

pub fn tick(self: *Timer, cycles_taken: u32, interrupt: *Interrupt) void {
    
    if (self.request_interrupt) {
        self.counter = self.modulo;
        interrupt.requestInterrupt(.Timer);
    }

    self.tickDivider(cycles_taken);

    const falling_edge: bool = self.previous_obscure_bit and !self.getObscureBit();
    self.previous_obscure_bit = self.getObscureBit();
    if (falling_edge) {
        self.incrementTimer();
    }
}

pub fn writeControl(self: *Timer, control_value: u8) void {
    // const old_enable = self.isTimerEnabled();
    // const old_speed = self.getTimerSpeed().getCyclesRequired();
    const old_multiplexer_bit = self.getObscureBit();
    self.control = control_value & 0b111;
    const new_multiplexer_bit = self.getObscureBit();
    // const new_enable = self.isTimerEnabled();
    // const new_speed = self.getTimerSpeed().getCyclesRequired();

    // const glitch_triggerd = blk: {
    //     if (old_enable) {
    //         break :blk false;
    //     }
        
    //     if (new_enable) {
    //         break :blk self.internal_counter & (old_speed / 2) != 0;
    //     } else {
    //         break :blk self.internal_counter & (old_speed / 2) != 0 and self.internal_counter & (new_speed / 2) != 0;
    //     }
    // };

    if (old_multiplexer_bit and !new_multiplexer_bit) {
        std.debug.print("AYO, \n", .{});
        self.incrementTimer();
    }
}

pub fn writeDivider(self: *Timer, divider_value: u8) void {
    _ = divider_value;
    self.internal_counter = 0;
}

pub fn readDivider(self: *Timer) u8 {
    return @intCast(u8, (self.internal_counter >> 8) & 0xFF);
}

fn tickDivider(self: *Timer, cycles_taken: u32) void {
    self.internal_counter +%= @truncate(u16, cycles_taken);
    self.divider_cycles_processed += cycles_taken;

    if (self.divider_cycles_processed >= 256) {
        self.divider_cycles_processed = 0;
    }
}

fn incrementTimer(self: *Timer) void {
    var result: u8 = 0;
    if (@addWithOverflow(u8, self.counter, 1, &result)) {
        self.request_interrupt = true;
        self.counter = 0;
    } else {
        self.counter = result;
    }
}

fn getMultiplexerBit(self: Timer) bool {
    const internal_clock_bits_to_select = [_]u4 { 9, 3, 5, 7 };
    const bit_index_to_select = self.control & 0x3;
    const internal_clock_bit_value = self.internal_counter & (@intCast(u16, 0x1) << internal_clock_bits_to_select[bit_index_to_select]);
    return internal_clock_bit_value != 0;
}

fn getObscureBit(self: Timer) bool {
    return self.getMultiplexerBit() and self.isTimerEnabled();
}

pub fn getTimerSpeed(self: Timer) TimerSpeed {
    return @intToEnum(TimerSpeed, self.control & 0x3);
}

pub fn isTimerEnabled(self: Timer) bool {
    return self.control & 0x4 != 0;
}

test "Timer speed mode" {
    var timer = Timer {};

    timer.control = 0b100;
    try testing.expectEqual(TimerSpeed.Cpu_Div_1024, timer.getTimerSpeed());

    timer.control = 0b101;
    try testing.expectEqual(TimerSpeed.Cpu_Div_16, timer.getTimerSpeed());

    timer.control = 0b110;
    try testing.expectEqual(TimerSpeed.Cpu_Div_64, timer.getTimerSpeed());

    timer.control = 0b111;
    try testing.expectEqual(TimerSpeed.Cpu_Div_256, timer.getTimerSpeed());
}

// test "Timer obscure bit" {
//     var timer = Timer {};

//     timer.internal_counter = 0b01000;
//     timer.control = 0b101;

//     try testing.expect(timer.getObscureBit());

//     timer.control = 0b110;

//     try testing.expect(!timer.getObscureBit());

//     timer.internal_counter = 0b101000;

//     try testing.expect(timer.getObscureBit());
// }

// test "Timer TIMA obscure increase, div reset" {
//     var timer = Timer {};
//     var interrupt = Interrupt {};

//     timer.internal_counter = 0;
//     timer.control = 0x4 | @enumToInt(TimerSpeed.Cpu_Div_1024);

//     while (!timer.previous_obscure_bit) {
//         timer.tick(4, &interrupt);
//     }

//     const counter_before_div_reset = timer.counter;
//     try testing.expect(timer.previous_obscure_bit);

//     timer.writeDivider(0);
//     timer.tick(4, &interrupt);

//     try testing.expectEqual(counter_before_div_reset + 1, timer.counter);
// }

// test "Timer TIMA obscure increase, timer disable" {
//     var timer = Timer {};
//     var interrupt = Interrupt {};

//     timer.internal_counter = 0;
//     timer.control = 0x4 | @enumToInt(TimerSpeed.Cpu_Div_256);

//     while (!timer.previous_obscure_bit) {
//         timer.tick(4, &interrupt);
//     }

//     const counter_before_div_reset = timer.counter;
//     try testing.expect(timer.previous_obscure_bit);

//     timer.control &= ~@intCast(u8, 0x4); // Disable timer
//     timer.tick(4, &interrupt);

//     try testing.expectEqual(counter_before_div_reset + 1, timer.counter);
// }