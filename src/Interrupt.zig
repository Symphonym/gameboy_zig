
const Interrupt = @This();

pub const Types = enum(u8) {
    NONE = 0,
    VBlank = 0x1,
    LCDStat = 0x2,
    Timer = 0x4, 
    Serial = 0x8,
    Joypad = 0x10
};

request_register: u8 = 0,
enabled_register: u8 = 0,
interrupt_master_enable: bool = true,

pub fn requestInterrupt(self: *Interrupt, interrupt: Types) void {
    self.request_register |= @enumToInt(interrupt);
}

pub fn clearInterruptRequest(self: *Interrupt, interrupt: Types) void {
    self.request_register &= ~(@enumToInt(interrupt));
}

pub fn isInterruptEnabled(self: Interrupt, interrupt: Types) bool {
    return self.interrupt_master_enable and self.enabled_register & @enumToInt(interrupt) != 0;
}

pub fn getInterruptPriority(interrupt: Types) u8 {
    if (interrupt == .NONE) {
        return 0;
    }

    // Lower bits mean higher priority
    return @intCast(u8, 0xFF) - @enumToInt(interrupt);
}