/* City Deathmatch II - tdwsl 2022 */

import sdlutil;

import bindbc.sdl;
import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;
import std.format;
import std.stdio;

SDL_Texture* t_feet, t_eyes, t_bodies, t_tileset, t_editor, t_font;

bool g_quit = false;

int g_mapw, g_maph;
byte[] g_map;
int[2][] g_markers;

const Uint8[] g_controls = [
    SDL_SCANCODE_UP,
    SDL_SCANCODE_DOWN,
    SDL_SCANCODE_LEFT,
    SDL_SCANCODE_RIGHT,
    SDL_SCANCODE_Z,
    SDL_SCANCODE_X,
];

bool mapSafe(int x, int y);

class Actor {
private:
    long xv=0, yv=0;
    int d=0;
    byte body, eyes, feet;
public:
    float x, y;

    void init(float x, float y) {
        this.x = x;
        this.y = y;
    }

    void draw(long xo, long yo) {
        long dx = cast(long)(x*16-8+xo), dy = cast(long)(y*16-8+yo);
        int w, h;
        SDL_GetWindowSize(g_window, &w, &h);
        w /= g_scale;
        h /= g_scale;
        if(dx < 8*g_scale || dy < 8*g_scale || dx >= w+8*g_scale || dy >= h+8*g_scale)
            return;
        drawTexture(t_bodies, d*16, body*16, 16, 16, cast(int)(x*16-8+xo), cast(int)(y*16-8+yo));
    }

    void control() {
        xv = 0; yv = 0;
        if(g_keyboard[g_controls[0]]) yv = -1;
        if(g_keyboard[g_controls[1]]) yv = 1;
        if(g_keyboard[g_controls[2]]) xv = -1;
        if(g_keyboard[g_controls[3]]) xv = 1;
    }

    void update(float m) {
        float dx = x+xv*m, dy = y+yv*m;
        if(mapSafe(cast(int)dx, cast(int)dy)) {
            x = dx;
            y = dy;
        }
    }
}

void loadMap(const(char)* filename) {
    FILE* fp = fopen(filename, "r");
    assert(fp != null);

    fscanf(fp, "%d%d", &g_mapw, &g_maph);
    g_map.length = g_mapw*g_maph;

    for(int i = 0; i < g_mapw*g_maph; i++)
        fscanf(fp, "%d", &g_map[i]);

    int n;
    fscanf(fp, "%d", &n);
    g_markers.length = n;
    for(int i = 0; i < g_markers.length; i++)
        fscanf(fp, "%d%d", &g_markers[i][0], &g_markers[i][1]);

    fclose(fp);
}

void saveMap(const(char)* filename) {
    FILE *fp = fopen(filename, "w");
    assert(fp != null);

    fprintf(fp, "%d %d\n", g_mapw, g_maph);

    for(int i = 0; i < g_mapw*g_maph; i++) {
        fprintf(fp, "%d ", g_map[i]);
        if((i+1)%g_mapw == 0)
            fprintf(fp, "\n");
    }

    fprintf(fp, "%d\n", g_markers.length);
    for(int i = 0; i < g_markers.length; i++)
        fprintf(fp, "%d %d\n", g_markers[i][0], g_markers[i][1]);

    fclose(fp);
}

bool mapSafe(int x, int y) {
    if(x < 0 || y < 0 || x >= g_mapw || y >= g_maph)
        return false;
    if(g_map[y*g_mapw+x] >= 8)
        return false;
    return true;
}

void drawMap(long xo, long yo) {
    for(int i = 0; i < g_mapw*g_maph; i++)
        drawTexture(t_tileset, (g_map[i]%8)*16, (g_map[i]/8)*16, 16, 16, cast(int)((i%g_mapw)*16+xo), cast(int)((i/g_mapw)*16+yo));
}

void drawText(char[] text, int x, int y) {
    for(int i = 0; i < text.length; i++)
        drawTexture(t_font, (text[i]%32)*8, (text[i]/32)*8, 8, 8, x+i*8, y);
}

/* basic map editor */
void editor(char[] filename) {
    loadMap(cast(const(char)*)filename.ptr);

    bool quit = false;
    int cx = 0, cy = 0;
    byte ctile = 0;
    int lastUpdate = SDL_GetTicks();
    const int delay = 100;
    bool changed = false;

    while(!quit) {
        SDL_Event ev;
        while(SDL_PollEvent(&ev))
            sw: switch(ev.type) {
            default: break;
            case SDL_QUIT:
                quit = true;
                g_quit = true;
                break;
            case SDL_KEYDOWN:
                switch(ev.key.keysym.sym) {
                case SDLK_ESCAPE:
                    quit = true;
                    break;
                case SDLK_m:
                    if(cx >= 0 && cy >= 0 && cx < g_mapw && cy < g_maph) {
                        for(int i = 0; i < g_markers.length; i++)
                            if(g_markers[i][0] == cx && g_markers[i][1] == cy) {
                                int[2][] markers = g_markers[0..i];
                                markers ~= g_markers[(i+1)..g_markers.length];
                                g_markers = markers;
                                break sw;
                            }
                        g_markers.length++;
                        g_markers[g_markers.length-1] = [cx, cy];
                    }
                    break;
                case SDLK_s:
                    saveMap(cast(const(char)*)filename.ptr);
                    changed = false;
                    break;
                case SDLK_z:
                    if(cx < 0 || cy < 0 || cx >= g_mapw || cy >= g_maph) {
                        int nw = g_mapw, nh = g_maph;
                        if(cx < 0) nw--;
                        if(cx >= g_mapw) nw++;
                        if(cy < 0) nh--;
                        if(cy >= g_maph) nh++;

                        if(nw < 1) nw = 1; if(nh < 1) nh = 1;
                        byte[] nmap;
                        nmap.length = nw*nh;
                        for(int i = 0; i < nw*nh; i++) nmap[i] = 0;
                        for(int i = 0; i < g_mapw*g_maph; i++) {
                            if(i%g_mapw >= nw || i/g_mapw >= nh) continue;
                            nmap[(i/g_mapw)*nw+i%g_mapw] = g_map[i];
                        }

                        g_mapw = nw;
                        g_maph = nh;
                        g_map = nmap;
                        changed = true;

                        break;
                    }
                default:
                    lastUpdate = SDL_GetTicks()-delay;
                    break;
                }
                break;
            }

        /* update */
        int currentTime = SDL_GetTicks();
        if(currentTime-lastUpdate > delay) {
            lastUpdate += delay;
            if(g_keyboard[SDL_SCANCODE_UP]) cy--;
            if(g_keyboard[SDL_SCANCODE_DOWN]) cy++;
            if(g_keyboard[SDL_SCANCODE_LEFT]) cx--;
            if(g_keyboard[SDL_SCANCODE_RIGHT]) cx++;

            if(cx < -1) cx = -1;
            if(cx > g_mapw) cx = g_mapw;
            if(cy < -1) cy = -1;
            if(cy > g_maph) cy = g_maph;

            if(g_keyboard[SDL_SCANCODE_X])
                ctile = (ctile+1)%16;

            if(g_keyboard[SDL_SCANCODE_Z])
                if(cx >= 0 && cy >= 0 && cx < g_mapw && cy < g_maph) {
                    g_map[cy*g_mapw+cx] = ctile;
                    changed = true;
                }
        }

        /* draw */

        SDL_RenderClear(g_renderer);

        int w, h;
        SDL_GetWindowSize(g_window, &w, &h);
        w /= g_scale; h /= g_scale;
        long xo = w/2-cx*16-8, yo = h/2-cy*16-8;
        drawMap(xo, yo);

        char[100] buf;

        for(int i = 0; i < g_markers.length; i++) {
            drawText("M".dup, cast(int)(g_markers[i][0]*16+xo), cast(int)(g_markers[i][1]*16+yo));
            drawText(sformat(buf, "%d", i), cast(int)(g_markers[i][0]*16+xo), cast(int)(g_markers[i][1]*16+yo+8));
        }

        drawText(sformat(buf, "\"%s\"", filename), 0, 0);
        if(changed)
            drawText("(not saved)".dup, cast(int)filename.length*8+24, 0);

        drawTexture(t_editor, 32, 0, 32, 32, w/2-16, h/2-16);
        drawTexture(t_editor, 0, 0, 32, 32, w-64, 0);
        drawTexture(t_tileset, (ctile%8)*16, (ctile/8)*16, 16, 16, w-64+8, 8);
        drawText(sformat(buf, "t:%d/%d", ctile, 15), w-64, 32);

        drawText(sformat(buf, "%dx%d", g_mapw, g_maph), 0, 8);
        drawText(sformat(buf, "[%d,%d]", cx, cy), 0, 16);

        drawText("arrows: move  z: place  x: next".dup, 0, h-16);
        drawText("m: marker  s: save".dup, 0, h-8);

        SDL_RenderPresent(g_renderer);
    }
}

void runGame(char[] filename) {
    loadMap(cast(const(char)*)filename.ptr);

    Actor player;
    player.init(g_markers[0][0], g_markers[0][1]);

    bool quit = false;
    int lastUpdate = SDL_GetTicks();

    while(!quit) {
        SDL_Event ev;
        while(SDL_PollEvent(&ev))
            switch(ev.type) {
            default: break;
            case SDL_QUIT:
                quit = true;
                g_quit = true;
                break;
            }

        player.control();

        /* update */
        int currentTime = SDL_GetTicks();
        int diff = currentTime-lastUpdate;
        currentTime = lastUpdate;
        float m = diff*0.01;
        player.update(diff);

        /* draw */
        SDL_RenderClear(g_renderer);

        int w, h;
        SDL_GetWindowSize(g_window, &w, &h);
        w /= g_scale; h /= g_scale;
        long xo = cast(long)(player.x-w/2), yo = cast(long)(player.y-h/2);

        drawMap(xo, yo);
        player.draw(xo, yo);

        SDL_RenderPresent(g_renderer);
    }
}

void main(string[] args) {
    initSDL();
    t_feet = loadTexture("data/img/feet.bmp");
    t_eyes = loadTexture("data/img/eyes.bmp");
    t_bodies = loadTexture("data/img/bodies.bmp");
    t_tileset = loadTexture("data/img/tileset.bmp");
    t_editor = loadTexture("data/img/editor.bmp");
    t_font = loadTexture("data/img/font.bmp");

    /*if(args.length > 1) {
        if(args[1] == "-e" || args[1] == "--editor") {
            if(args.length > 3)
                editor(args[3].dup);
            else
                editor("map.txt".dup);
        }
        else {
            writefln("usage: %s [--editor / --e <filename>]", args[0]);
        }
    }
    else {
        runGame("map.txt".dup);
    }*/
    editor("map.txt".dup);

    endSDL();
}
