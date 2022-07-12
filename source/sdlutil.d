/* City Deathmatch II - tdwsl 2022 */

module sdlutil;

import bindbc.sdl;
import std.stdio;
import core.stdc.stdlib;

export SDL_Window* g_window;
export SDL_Renderer* g_renderer;
export const(Uint8)* g_keyboard;

export int g_scale = 2;

SDL_Texture*[] g_textures;

export void initSDL() {
    /* load shared lib */
    auto ret = loadSDL();
    if(ret != sdlSupport) {
        writeln("failed to load SDL library!");
        exit(1);
    }

    assert(SDL_Init(SDL_INIT_EVERYTHING) >= 0);
    g_window = SDL_CreateWindow("City Deathmatch II", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, 640, 480, SDL_WINDOW_RESIZABLE);
    assert(g_window != null);
    g_renderer = SDL_CreateRenderer(g_window, -1, SDL_RENDERER_SOFTWARE);
    assert(g_renderer != null);
    SDL_SetRenderDrawColor(g_renderer, 0, 0, 0, 0xff);

    g_keyboard = SDL_GetKeyboardState(null);
}

export void endSDL() {
    foreach(SDL_Texture *tex ; g_textures)
        SDL_DestroyTexture(tex);

    SDL_DestroyRenderer(g_renderer);
    SDL_DestroyWindow(g_window);
    SDL_Quit();
}

export SDL_Texture* loadTexture(const(char)* filename) {
    SDL_Surface* surf = SDL_LoadBMP(filename);
    assert(surf != null);
    SDL_SetColorKey(surf, SDL_TRUE, SDL_MapRGB(surf.format, 0, 0xff, 0xff));

    SDL_Texture* tex = SDL_CreateTextureFromSurface(g_renderer, surf);
    SDL_FreeSurface(surf);
    assert(tex != null);

    g_textures ~= tex;
    return tex;
}

export void drawTexture(SDL_Texture* tex, int cx, int cy, int cw, int ch, int dx, int dy) {
    auto src = SDL_Rect(cx, cy, cw, ch);
    auto dst = SDL_Rect(dx*g_scale, dy*g_scale, cw*g_scale, ch*g_scale);
    SDL_RenderCopy(g_renderer, tex, &src, &dst);
}
