// torii-ctm: a colour matrix per monitor (night light with an own temperature on each screen).
// The same Hyprland protocol hyprsunset uses (hyprland-ctm-control-v1), but one matrix per output.
// Reads a file with one line per monitor:  <output name> <r> <g> <b>   (multipliers 0..1; monitors not listed stay neutral)
// and applies it again whenever the file changes. Quit with SIGTERM (the colours go back to normal).
// Build: wayland-scanner client-header hyprland-ctm-control-v1.xml hyprland-ctm-control-v1-client.h  (and private-code .c), cc -O2 -o torii-ctm torii-ctm.c hyprland-ctm-control-v1-protocol.c -lwayland-client
#include <poll.h>
#include <signal.h>
#include <time.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <wayland-client.h>
#include "hyprland-ctm-control-v1-client.h"

struct out { struct wl_output *o; char name[64]; };
static struct out outs[16];
static int nouts;
static struct hyprland_ctm_control_manager_v1 *mgr;
static volatile sig_atomic_t quit;
static int blocked;

static void o_geometry(void *d, struct wl_output *o, int32_t x, int32_t y, int32_t pw, int32_t ph, int32_t sp, const char *mk, const char *md, int32_t tr) {}
static void o_mode(void *d, struct wl_output *o, uint32_t f, int32_t w, int32_t h, int32_t r) {}
static void o_done(void *d, struct wl_output *o) {}
static void o_scale(void *d, struct wl_output *o, int32_t s) {}
static void o_name(void *d, struct wl_output *o, const char *n) { snprintf(((struct out *)d)->name, 64, "%s", n); }
static void o_desc(void *d, struct wl_output *o, const char *n) {}
static const struct wl_output_listener ol = { o_geometry, o_mode, o_done, o_scale, o_name, o_desc };

static void m_blocked(void *d, struct hyprland_ctm_control_manager_v1 *m) { blocked = 1; }
static const struct hyprland_ctm_control_manager_v1_listener ml = { m_blocked };

static void reg_global(void *d, struct wl_registry *r, uint32_t id, const char *iface, uint32_t ver) {
    if (!strcmp(iface, "wl_output") && nouts < 16) {
        outs[nouts].o = wl_registry_bind(r, id, &wl_output_interface, ver < 4 ? ver : 4);
        wl_output_add_listener(outs[nouts].o, &ol, &outs[nouts]);
        nouts++;
    } else if (!strcmp(iface, "hyprland_ctm_control_manager_v1")) {
        mgr = wl_registry_bind(r, id, &hyprland_ctm_control_manager_v1_interface, ver < 2 ? ver : 2);
        hyprland_ctm_control_manager_v1_add_listener(mgr, &ml, NULL);
    }
}
static void reg_remove(void *d, struct wl_registry *r, uint32_t id) {}
static const struct wl_registry_listener rl = { reg_global, reg_remove };

static void on_term(int s) { quit = 1; }

static void apply(const char *path) {
    for (int i = 0; i < nouts; i++) {
        double r = 1, g = 1, b = 1;
        FILE *f = fopen(path, "r");
        char line[256], nm[64];
        double lr, lg, lb;
        while (f && fgets(line, sizeof line, f))
            if (sscanf(line, "%63s %lf %lf %lf", nm, &lr, &lg, &lb) == 4 && !strcmp(nm, outs[i].name)) { r = lr; g = lg; b = lb; }
        if (f) fclose(f);
        hyprland_ctm_control_manager_v1_set_ctm_for_output(mgr, outs[i].o,
            wl_fixed_from_double(r), 0, 0, 0, wl_fixed_from_double(g), 0, 0, 0, wl_fixed_from_double(b));
    }
    hyprland_ctm_control_manager_v1_commit(mgr);
}

int main(int argc, char **argv) {
    if (argc < 2) { fprintf(stderr, "usage: torii-ctm <file>\n"); return 2; }
    struct wl_display *dpy = wl_display_connect(NULL);
    if (!dpy) { fprintf(stderr, "no Wayland display\n"); return 1; }
    struct wl_registry *reg = wl_display_get_registry(dpy);
    wl_registry_add_listener(reg, &rl, NULL);
    wl_display_roundtrip(dpy);
    wl_display_roundtrip(dpy);                       // the output names
    if (!mgr) { fprintf(stderr, "the compositor has no hyprland-ctm-control-v1\n"); return 1; }
    signal(SIGTERM, on_term);
    signal(SIGINT, on_term);
    time_t last = 0; long lastn = -1;
    struct stat st;
    int first = 1;
    while (!quit) {
        if (stat(argv[1], &st) == 0 && (first || st.st_mtime != last || st.st_mtim.tv_nsec != lastn)) {
            last = st.st_mtime; lastn = st.st_mtim.tv_nsec; first = 0;
            apply(argv[1]);
            wl_display_roundtrip(dpy);
            if (blocked) { fprintf(stderr, "another colour-matrix program (hyprsunset) is running\n"); return 3; }
        }
        wl_display_flush(dpy);
        struct pollfd p = { wl_display_get_fd(dpy), POLLIN, 0 };
        if (poll(&p, 1, 100) > 0) wl_display_dispatch(dpy);
    }
    return 0;
}
