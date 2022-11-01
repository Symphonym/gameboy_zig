const testing = @import("std").testing;

const Interrupt = @This();

pub const Types = enum(u8) {
    NONE = 0,
    VBlank = 0x1,
    LCDStat = 0x2,
    Timer = 0x4, 
    Serial = 0x8,
    Joypad = 0x10
};

request_register: u8 = 0xE0,
enabled_register: u8 = 0x00,
interrupt_master_enable: bool = false,

pub fn requestInterrupt(self: *Interrupt, interrupt: Types) void {
    self.request_register |= @enumToInt(interrupt);
}

pub fn clearInterruptRequest(self: *Interrupt, interrupt: Types) void {
    self.request_register &= ~(@enumToInt(interrupt));
}

pub fn isInterruptEnabled(self: Interrupt, interrupt: Types) bool {
    return self.interrupt_master_enable and self.enabled_register & @enumToInt(interrupt) != 0;
}

pub fn isInterruptRequested(self: Interrupt, interrupt: Types) bool {
    return self.request_register & @enumToInt(interrupt) != 0;
}

pub fn isAnyInterruptPending(self: Interrupt) bool {
    return self.request_register & self.enabled_register & 0x1F != 0;
}

test "Interrupts" {
    var interrupts = Interrupt {};
    interrupts.requestInterrupt(.Timer);
    interrupts.requestInterrupt(.VBlank);
    interrupts.requestInterrupt(.LCDStat);
    interrupts.clearInterruptRequest(.Timer);

    try testing.expect(!interrupts.isInterruptRequested(.Timer));
    try testing.expect(interrupts.isInterruptRequested(.VBlank));
    try testing.expect(interrupts.isInterruptRequested(.LCDStat));
}