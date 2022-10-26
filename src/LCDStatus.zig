
const LCDStatus = @This();
const testing = @import("std").testing;

register: u8 = 0,

pub const Flags = enum(u8) {
    LY_InterruptSource = 0x40, // (1=Enable) (Read/Write)
    OAM_InterruptSource = 0x20, // (1=Enable) (Read/Write)
    VBlank_InterruptSource = 0x10, // (1=Enable) (Read/Write)
    HBlank_InterruptSource = 0x08, // (1=Enable) (Read/Write)
    LYC = 0x04, // (0=Different, 1=Equal) (Read Only)
    
    ModeFlag = 0x03
    // Last 2 bits is the mode flag, handled separately
};

pub const Modes = enum(u8) {
    HBlank = 0,
    VBlank = 1,
    SearchingOAM = 2,
    TransferringDataToLCD = 3,
};

pub fn setMode(self: LCDStatus, mode: Modes) void {
    self.register = (self.register & 0xFC) | @enumToInt(mode);
}
pub fn getMode(self: LCDStatus) Modes {
    return @intToEnum(Modes, self.register & @enumToInt(Flags.ModeFlag));
}

pub fn setFlag(self: *LCDStatus, flag: Flags, value: bool) void {
    if (value) {
        self.register |= @enumToInt(flag);
    } else {
        self.register &= ~(@enumToInt(flag));
    }
}

pub fn getFlag(self: LCDStatus, flag: Flags) bool {
    return self.register & @enumToInt(flag) != 0;
}


test "LCD STAT flags" {
    var lcd_status = LCDStatus {};

    lcd_status.register = 0xF0;
    try testing.expectEqual(Modes.HBlank, lcd_status.getMode());

    lcd_status.register = 0xF1;
    try testing.expectEqual(Modes.VBlank, lcd_status.getMode());

    lcd_status.register = 0xF2;
    try testing.expectEqual(Modes.SearchingOAM, lcd_status.getMode());

    lcd_status.register = 0xF3;
    try testing.expectEqual(Modes.TransferringDataToLCD, lcd_status.getMode());
}
