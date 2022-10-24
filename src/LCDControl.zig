
const LCDControl = @This();

register: u8 = 0,

pub const Flags = enum(u8) {
    LCD_PPU_enable = 0x80, // 0=Off, 1=On
    Window_TileMapArea = 0x40, // 0=9800-9BFF, 1=9C00-9FFF
    Window_Enable = 0x20, // 0=Off, 1=On
    BG_Window_TileDataArea = 0x10, // 0=8800-97FF, 1=8000-8FFF
    BG_TileMapArea = 0x08, //0=9800-9BFF, 1=9C00-9FFF,
    OBJ_Size = 0x04, // 0=8x8, 1=8x16
    OBJ_Enable = 0x02, // 0=Off, 1=On
    BG_Window_EnableOrPriority, // 0=Off, 1=On
};

pub fn setFlag(self: *LCDControl, flag: Flags, value: bool) void {
    if (value) {
        self.register |= @enumToInt(flag);
    } else {
        self.register &= ~(@enumToInt(flag));
    }
}

pub fn getFlag(self: LCDControl, flag: Flags) bool {
    return self.register & @enumToInt(flag) != 0;
}

