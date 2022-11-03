const std = @import("std");

const Cpu = @import("Cpu.zig");
const Ppu = @import("Ppu.zig");
const MemoryBank = @import("MemoryBank.zig");
const Cartridge = @import("Cartridge.zig");

const Gameboy = @This();


const GameboyErrors = Cpu.CpuErrors;
const CYCLES_PER_FRAME = 4194304 / 60;

pub const ExecutionModes = enum {
    Free,
    Paused,
    Step
};

cpu: ?Cpu,
ppu: ?Ppu,
memory_bank: MemoryBank,

cpu_cycles_this_frame: u32 = 0,

execution_mode: ExecutionModes = .Paused,

pub fn init() Gameboy {

    var gameboy = Gameboy {
        .cpu = null,
        .ppu = null,
        .memory_bank = MemoryBank {},
    };

    return gameboy;
}

pub fn deinit(self: *Gameboy) void {
    if (self.ppu) | *ppu | {
        ppu.deinit();
    }

    if (self.cpu) | *cpu | {
        cpu.deinit();
    }
}

pub fn initHardware(self: *Gameboy) void {
    self.cpu = Cpu.init(&self.memory_bank);
    self.ppu = Ppu.init(&self.memory_bank);
}

pub fn insertCartridge(self: *Gameboy, cartridge: *Cartridge) void {
    self.memory_bank.insertCartridge(cartridge);
}

pub fn tick(self: *Gameboy) GameboyErrors!void {
    var vram_changed = false;
    while (self.cpu_cycles_this_frame < CYCLES_PER_FRAME) {
        if (self.execution_mode == .Paused) {
            return;
        } else if (self.execution_mode == .Step) {
            self.execution_mode = .Paused;
        }

        const cycles_taken = try self.cpu.?.tickInstructions();
        try self.ppu.?.tick(cycles_taken);

        if (self.memory_bank.vram_changed) {
            vram_changed = true;
        }

        self.memory_bank.tick(cycles_taken);

        const interrupt_cycles_taken = try self.cpu.?.tickInterrupts();

        self.cpu_cycles_this_frame += cycles_taken + interrupt_cycles_taken;
    }

    // if (vram_changed) {
    //     self.ppu.?.regenerateTileSheet();
    // }

    self.cpu_cycles_this_frame -= CYCLES_PER_FRAME;
}

pub fn draw(self: Gameboy) void {
    _ = self;
    //self.ppu.?.draw();
}

pub fn getFramebuffer(self: *Gameboy) *Ppu.LCDFrameBuffer {
    if (self.ppu) |*ppu| {
        return &ppu.screen_pixels;
    } else {
        unreachable;
    }
}