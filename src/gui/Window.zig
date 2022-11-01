const std = @import("std");

const sdl = @import("../wrappers/sdl2.zig");
const zgui = @import("zgui");

const Color = @import("Color.zig");

const Window = @This();

window: *sdl.SDL_Window,
renderer: *sdl.SDL_Renderer,

desired_fps: u32 = 60,

last_render_timestamp: u64 = 0,

pub const WindowErrors = error {
    FailedSDLInitialization,
    FailedSDLWindowCreation,
    FailedSDLRendererCreation,

    FailedIMGUIInitialization,
};

pub const WindowFlags = struct {
    flags: u32 = sdl.SDL_WINDOW_RESIZABLE
};

pub fn init(title: []const u8, width: u32, height: u32, flags: WindowFlags) WindowErrors!Window {
    if (sdl.SDL_Init(sdl.SDL_INIT_VIDEO) != 0) {
        return WindowErrors.FailedSDLInitialization;
    }
    
    const window = sdl.SDL_CreateWindow(
        &title[0],
        sdl.SDL_WINDOWPOS_UNDEFINED,
        sdl.SDL_WINDOWPOS_UNDEFINED,
        @intCast(c_int, width),
        @intCast(c_int, height),
        flags.flags) orelse return WindowErrors.FailedSDLWindowCreation;
    errdefer sdl.SDL_DestroyWindow(window);

    const renderer = sdl.SDL_CreateRenderer(window, -1, 0) orelse return WindowErrors.FailedSDLRendererCreation;
    errdefer sdl.SDL_DestroyRenderer(renderer);

    zgui.init(std.heap.c_allocator);
    if (!sdl.ImGui_ImplSDL2_InitForSDLRenderer(window, renderer)) {
        return WindowErrors.FailedIMGUIInitialization;
    }
    errdefer _ = sdl.ImGui_ImplSDL2_Shutdown();

    if (!sdl.ImGui_ImplSDLRenderer_Init(renderer)) {
        return WindowErrors.FailedIMGUIInitialization;
    }
    errdefer sdl.ImGui_ImplSDLRenderer_Shutdown();

    return .{
        .window = window,
        .renderer = renderer,
        .last_render_timestamp = sdl.SDL_GetPerformanceCounter()
    };
}

pub fn deinit(self: *Window) void {
    sdl.SDL_DestroyWindow(self.window);
    sdl.SDL_DestroyRenderer(self.renderer);

    sdl.ImGui_ImplSDLRenderer_Shutdown();
    _ = sdl.ImGui_ImplSDL2_Shutdown();
    sdl.SDL_Quit();
}

pub fn pollEvent(self: Window, event: *sdl.SDL_Event) bool {
    _ = self;

    const has_event = sdl.SDL_PollEvent(event) != 0;
    if (has_event) {
        _ = sdl.ImGui_ImplSDL2_ProcessEvent(event);
    }
    
    return has_event;
}

pub fn clear(self: *Window, clear_color: Color) void {
    sdl.ImGui_ImplSDLRenderer_NewFrame();
    _ = sdl.ImGui_ImplSDL2_NewFrame();
    zgui.newFrame();

    const color_8 = clear_color.toRGBA8Array();
    _ = sdl.SDL_SetRenderDrawColor(self.renderer, color_8[0], color_8[1], color_8[2], color_8[3]);
    _ = sdl.SDL_RenderClear(self.renderer);
}

pub fn render(self: *Window) void {
    zgui.render();
    sdl.ImGui_ImplSDLRenderer_RenderDrawData(zgui.getDrawData());
    sdl.SDL_RenderPresent(self.renderer);

    
    const end_timestamp = sdl.SDL_GetPerformanceCounter();
    const elapsed_time_tick: f64 = @intToFloat(f64, end_timestamp - self.last_render_timestamp);
    const elapsed_time_s: f64 = (elapsed_time_tick / @intToFloat(f64, sdl.SDL_GetPerformanceFrequency()));

    const desired_seconds_per_frame = 1.0 / @intToFloat(f32, self.desired_fps);
    if (elapsed_time_s < desired_seconds_per_frame) {
        sdl.SDL_Delay((@floatToInt(u32, (desired_seconds_per_frame - elapsed_time_s) * 1000.0)));
    }
    self.last_render_timestamp = sdl.SDL_GetPerformanceCounter();
}

//     if (sdl.SDL_Init(sdl.SDL_INIT_VIDEO) != 0) {
//         sdl.SDL_Log("Unable to initialize SDL: %s", sdl.SDL_GetError());
//     }
//     defer sdl.SDL_Quit();

//     const window_flags = sdl.SDL_WINDOW_RESIZABLE;
//     var window = sdl.SDL_CreateWindow(
//         "Gameboy",
//         sdl.SDL_WINDOWPOS_UNDEFINED,
//         sdl.SDL_WINDOWPOS_UNDEFINED,
//         500,
//         500,
//         window_flags) orelse unreachable;
//     defer sdl.SDL_DestroyWindow(window);

//     var renderer = sdl.SDL_CreateRenderer(window, -1, 0);
//     defer sdl.SDL_DestroyRenderer(renderer);

//     zgui.init(std.heap.c_allocator);
//     _ = sdl.ImGui_ImplSDL2_InitForSDLRenderer(window, renderer);
//     _ = sdl.ImGui_ImplSDLRenderer_Init(renderer);
//     defer sdl.ImGui_ImplSDLRenderer_Shutdown();
//     defer _ = sdl.ImGui_ImplSDL2_Shutdown();

//     const desired_fps = 60.0;
//     const desired_seconds_per_frame = 1.0 / desired_fps;

//     var last_timestamp = sdl.SDL_GetPerformanceCounter();
//     outer: while (true) {
        
//         var event: sdl.SDL_Event = undefined;
//         while (sdl.SDL_PollEvent(&event) != 0) {
//             _ = sdl.ImGui_ImplSDL2_ProcessEvent(&event);
//             switch (event.type) {
//                 sdl.SDL_QUIT => {
//                     break :outer;
//                 },
//                 else => {},
//             }
//         }


//         sdl.ImGui_ImplSDLRenderer_NewFrame();
//         _ = sdl.ImGui_ImplSDL2_NewFrame();
//         zgui.newFrame();

// if (zgui.button("Setup Scene", .{})) {
//         // Button pressed.
//     }

//         zgui.render();
//         _ = sdl.SDL_SetRenderDrawColor(renderer, 255, 0, 0, 255);
//         _ = sdl.SDL_RenderClear(renderer);
//         sdl.ImGui_ImplSDLRenderer_RenderDrawData(zgui.getDrawData());
//         sdl.SDL_RenderPresent(renderer);





//         const end_timestamp = sdl.SDL_GetPerformanceCounter();
//         const elapsed_time_tick: f64 = @intToFloat(f64, end_timestamp - last_timestamp);
//         const elapsed_time_s: f64 = (elapsed_time_tick / @intToFloat(f64, sdl.SDL_GetPerformanceFrequency()));

//         if (elapsed_time_s < desired_seconds_per_frame) {
//             sdl.SDL_Delay((@floatToInt(u32, (desired_seconds_per_frame - elapsed_time_s) * 1000.0) ));
//         }
//         last_timestamp = sdl.SDL_GetPerformanceCounter();
//     }