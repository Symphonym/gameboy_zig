#include "imgui_impl_sdlrenderer.h"
#include "imgui_impl_sdl.h"

extern "C" bool zigImGui_ImplSDLRenderer_Init(SDL_Renderer* renderer) {
    return ImGui_ImplSDLRenderer_Init(renderer);
}
extern "C" void zigImGui_ImplSDLRenderer_Shutdown() {
    ImGui_ImplSDLRenderer_Shutdown();
}
extern "C" void zigImGui_ImplSDLRenderer_NewFrame() {
    ImGui_ImplSDLRenderer_NewFrame();
}
extern "C" void zigImGui_ImplSDLRenderer_RenderDrawData(ImDrawData* draw_data) {
    ImGui_ImplSDLRenderer_RenderDrawData(draw_data);
}

extern "C" bool zigImGui_ImplSDLRenderer_CreateFontsTexture() {
    return ImGui_ImplSDLRenderer_CreateFontsTexture();
}
extern "C" void zigImGui_ImplSDLRenderer_DestroyFontsTexture() {
    ImGui_ImplSDLRenderer_DestroyFontsTexture();
}
extern "C" bool zigImGui_ImplSDLRenderer_CreateDeviceObjects() {
    ImGui_ImplSDLRenderer_CreateDeviceObjects();
}
extern "C" void zigImGui_ImplSDLRenderer_DestroyDeviceObjects() {
    ImGui_ImplSDLRenderer_DestroyDeviceObjects();
}


extern "C" bool zigImGui_ImplSDL2_InitForOpenGL(SDL_Window* window, void* sdl_gl_context) {
    return ImGui_ImplSDL2_InitForOpenGL(window, sdl_gl_context);
}
extern "C" bool zigImGui_ImplSDL2_InitForVulkan(SDL_Window* window) {
    return ImGui_ImplSDL2_InitForVulkan(window);
}
extern "C" bool zigImGui_ImplSDL2_InitForD3D(SDL_Window* window) {
    return ImGui_ImplSDL2_InitForD3D(window);
}
extern "C" bool zigImGui_ImplSDL2_InitForMetal(SDL_Window* window) {
    return ImGui_ImplSDL2_InitForMetal(window);
}
extern "C" bool zigImGui_ImplSDL2_InitForSDLRenderer(SDL_Window* window, SDL_Renderer* renderer) {
    return ImGui_ImplSDL2_InitForSDLRenderer(window, renderer);
}
extern "C" void zigImGui_ImplSDL2_Shutdown() {
    ImGui_ImplSDL2_Shutdown();
}
extern "C" void zigImGui_ImplSDL2_NewFrame() {
    ImGui_ImplSDL2_NewFrame();
}
extern "C" bool zigImGui_ImplSDL2_ProcessEvent(const SDL_Event* event) {
    return ImGui_ImplSDL2_ProcessEvent(event);
}