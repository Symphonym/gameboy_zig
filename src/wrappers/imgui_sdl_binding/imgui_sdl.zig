
const zgui = @import("zgui");
const sdl = @import("../sdl2.zig");


pub const ImGui_ImplSDLRenderer_Init = zigImGui_ImplSDLRenderer_Init;
extern fn zigImGui_ImplSDLRenderer_Init(renderer: ?*sdl.SDL_Renderer) bool;

pub const ImGui_ImplSDLRenderer_Shutdown = zigImGui_ImplSDLRenderer_Shutdown;
extern fn zigImGui_ImplSDLRenderer_Shutdown() void;

pub const ImGui_ImplSDLRenderer_NewFrame = zigImGui_ImplSDLRenderer_NewFrame;
extern fn zigImGui_ImplSDLRenderer_NewFrame() void;

pub const ImGui_ImplSDLRenderer_RenderDrawData = zigImGui_ImplSDLRenderer_RenderDrawData;
extern fn zigImGui_ImplSDLRenderer_RenderDrawData(draw_data: zgui.DrawData) void;


pub const ImGui_ImplSDLRenderer_CreateFontsTexture = zigImGui_ImplSDLRenderer_CreateFontsTexture;
extern fn zigImGui_ImplSDLRenderer_CreateFontsTexture() bool;

pub const ImGui_ImplSDLRenderer_DestroyFontsTexture = zigImGui_ImplSDLRenderer_DestroyFontsTexture;
extern fn zigImGui_ImplSDLRenderer_DestroyFontsTexture() void;

pub const ImGui_ImplSDLRenderer_CreateDeviceObjects = zigImGui_ImplSDLRenderer_CreateDeviceObjects;
extern fn zigImGui_ImplSDLRenderer_CreateDeviceObjects() bool;

pub const ImGui_ImplSDLRenderer_DestroyDeviceObjects = zigImGui_ImplSDLRenderer_DestroyDeviceObjects;
extern fn zigImGui_ImplSDLRenderer_DestroyDeviceObjects() void;


pub const ImGui_ImplSDL2_InitForOpenGL = zigImGui_ImplSDL2_InitForOpenGL;
extern fn zigImGui_ImplSDL2_InitForOpenGL(window: ?*sdl.SDL_Window, sdl_gl_context: *anyopaque) bool;

pub const ImGui_ImplSDL2_InitForVulkan = zigImGui_ImplSDL2_InitForVulkan;
extern fn zigImGui_ImplSDL2_InitForVulkan(window: ?*sdl.SDL_Window) bool;

pub const ImGui_ImplSDL2_InitForD3D = zigImGui_ImplSDL2_InitForD3D;
extern fn zigImGui_ImplSDL2_InitForD3D(window: ?*sdl.SDL_Window) bool;

pub const ImGui_ImplSDL2_InitForMetal = zigImGui_ImplSDL2_InitForMetal;
extern fn zigImGui_ImplSDL2_InitForMetal(window: ?*sdl.SDL_Window) bool;

pub const ImGui_ImplSDL2_InitForSDLRenderer = zigImGui_ImplSDL2_InitForSDLRenderer;
extern fn zigImGui_ImplSDL2_InitForSDLRenderer(window: ?*sdl.SDL_Window, renderer: ?*sdl.SDL_Renderer) bool;

pub const ImGui_ImplSDL2_Shutdown = zigImGui_ImplSDL2_Shutdown;
extern fn zigImGui_ImplSDL2_Shutdown() bool;

pub const ImGui_ImplSDL2_NewFrame = zigImGui_ImplSDL2_NewFrame;
extern fn zigImGui_ImplSDL2_NewFrame() bool;

pub const ImGui_ImplSDL2_ProcessEvent = zigImGui_ImplSDL2_ProcessEvent;
extern fn zigImGui_ImplSDL2_ProcessEvent(event: *const sdl.SDL_Event) bool;