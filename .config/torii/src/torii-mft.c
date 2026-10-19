/* torii-mft DEVICE MOUNTPOINT > scan.json
 *
 * Disk usage of an NTFS volume in seconds, the way WizTree and FreeCommander do it: instead of walking the directories (a seek for
 * every folder, hopeless on a spinning disk) it reads the Master File Table, the one table where NTFS keeps every file's name,
 * parent and size, in one sequential pass. The result is written in the JSON format gdu reads:  gdu -f scan.json
 * Needs read access to the block device (run it with sudo). Nothing is written to the disk.
 *
 * Sizes: asize = the size of the data, dsize = what it takes on the disk (compressed/sparse files: the stored size).
 * Only the unnamed data stream counts (alternate streams are small); a file with several hard links is counted once.
 * Build: cc -O2 -o torii-mft torii-mft.c
 */
#define _GNU_SOURCE
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#define F_USED 1
#define F_DIR 2
#define F_NAME 4
#define F_DOSNAME 8

static uint16_t u16(const uint8_t *p) { uint16_t v; memcpy(&v, p, 2); return v; }
static uint32_t u32(const uint8_t *p) { uint32_t v; memcpy(&v, p, 4); return v; }
static uint64_t u64(const uint8_t *p) { uint64_t v; memcpy(&v, p, 8); return v; }

static uint32_t *parent, *nameoff, *head, *nxt;
static uint64_t *asz, *dsz;
static uint8_t *flags;
static char *names; static size_t names_len, names_cap;
static uint64_t nrec;

static void die(const char *m) { fprintf(stderr, "torii-mft: %s\n", m); exit(1); }

static uint32_t add_name(const uint8_t *u, int n) {      /* UTF-16LE -> UTF-8, NUL terminated, JSON-escaped later */
    if (names_len + (size_t)n * 4 + 1 > names_cap) { names_cap = (names_cap + n * 4 + 1) * 2; names = realloc(names, names_cap); if (!names) die("out of memory"); }
    uint32_t at = names_len;
    for (int i = 0; i < n; i++) {
        uint32_t c = u16(u + i * 2);
        if (c >= 0xD800 && c < 0xDC00 && i + 1 < n) { uint32_t d = u16(u + (i + 1) * 2); if (d >= 0xDC00 && d < 0xE000) { c = 0x10000 + ((c - 0xD800) << 10) + (d - 0xDC00); i++; } }
        if (c >= 0xD800 && c < 0xE000) c = 0xFFFD;      /* a lone surrogate: NTFS allows it, UTF-8 and JSON do not */
        if (c < 0x80) names[names_len++] = c;
        else if (c < 0x800) { names[names_len++] = 0xC0 | (c >> 6); names[names_len++] = 0x80 | (c & 63); }
        else if (c < 0x10000) { names[names_len++] = 0xE0 | (c >> 12); names[names_len++] = 0x80 | ((c >> 6) & 63); names[names_len++] = 0x80 | (c & 63); }
        else { names[names_len++] = 0xF0 | (c >> 18); names[names_len++] = 0x80 | ((c >> 12) & 63); names[names_len++] = 0x80 | ((c >> 6) & 63); names[names_len++] = 0x80 | (c & 63); }
    }
    names[names_len++] = 0;
    return at;
}

static int fixup(uint8_t *r, int rs) {
    if (memcmp(r, "FILE", 4)) return 0;
    int uo = u16(r + 4), uc = u16(r + 6);
    if (uc < 2 || uo + uc * 2 > rs || (uc - 1) * 512 > rs) return 0;
    for (int i = 1; i < uc; i++) {
        int pos = i * 512 - 2;
        if (u16(r + pos) != u16(r + uo)) return 0;
        memcpy(r + pos, r + uo + i * 2, 2);
    }
    return 1;
}

static void parse(uint8_t *r, int rs, uint64_t no) {
    if (!fixup(r, rs)) return;
    unsigned fl = u16(r + 0x16);
    if (!(fl & 1)) return;
    uint64_t base = u64(r + 0x20) & 0xFFFFFFFFFFFFULL;
    uint64_t tgt = base ? base : no;
    if (tgt >= nrec) return;
    if (!base) flags[no] |= F_USED | (fl & 2 ? F_DIR : 0);
    int p = u16(r + 0x14);
    while (p + 16 <= rs) {
        uint32_t type = u32(r + p), len = u32(r + p + 4);
        if (type == 0xFFFFFFFFu || len < 16 || p + (int)len > rs) break;
        int nonres = r[p + 8], nl = r[p + 9];
        if (type == 0x30 && !nonres) {   /* also in an extension record: a crowded record moves its names out */
            int off = u16(r + p + 0x14);
            const uint8_t *fn = r + p + off;
            if (p + off + 0x42 <= rs) {
                int fnl = fn[0x40], ns = fn[0x41];
                if (p + off + 0x42 + fnl * 2 <= rs) {
                    int dos = ns == 2;
                    /* first real name wins; a DOS 8.3 name only when there is nothing else */
                    if (!(flags[tgt] & F_NAME) || ((flags[tgt] & F_DOSNAME) && !dos)) {
                        parent[tgt] = u64(fn) & 0xFFFFFFFFFFFFULL;
                        nameoff[tgt] = add_name(fn + 0x42, fnl);
                        flags[tgt] = (flags[tgt] & ~F_DOSNAME) | F_NAME | (dos ? F_DOSNAME : 0);
                        if (!(flags[tgt] & 0x10) && !asz[tgt]) { asz[tgt] = u64(fn + 0x30); dsz[tgt] = u64(fn + 0x28); }   /* until the data attribute says it better */
                    }
                }
            }
        } else if (type == 0x80 && nl == 0) {
            if (!nonres) {
                uint64_t n = u32(r + p + 0x10);
                asz[tgt] = n; dsz[tgt] = n; flags[tgt] |= 0x10;
            } else if (u64(r + p + 0x10) == 0) {
                unsigned af = u16(r + p + 0x0C);
                asz[tgt] = u64(r + p + 0x30);
                dsz[tgt] = (af & 0x8001) && len >= 0x48 ? u64(r + p + 0x40) : u64(r + p + 0x28);
                flags[tgt] |= 0x10;
            }
        }
        p += len;
    }
}

static void jstr(FILE *o, const char *s) {
    fputc('"', o);
    for (const unsigned char *c = (const unsigned char *)s; *c; c++) {
        if (*c == '"' || *c == '\\') { fputc('\\', o); fputc(*c, o); }
        else if (*c < 0x20) fprintf(o, "\\u%04x", *c);
        else fputc(*c, o);
    }
    fputc('"', o);
}

static void emit(FILE *o, uint32_t i, int depth) {
    if (depth > 4000) return;
    if (flags[i] & F_DIR) {
        fputs("[{\"name\":", o); jstr(o, names + nameoff[i]); fputs("}", o);
        for (uint32_t c = head[i]; c; c = nxt[c]) { fputs(",\n", o); emit(o, c, depth + 1); }
        fputs("]", o);
    } else {
        fputs("{\"name\":", o); jstr(o, names + nameoff[i]);
        fprintf(o, ",\"asize\":%llu,\"dsize\":%llu}", (unsigned long long)asz[i], (unsigned long long)dsz[i]);
    }
}

int main(int argc, char **argv) {
    if (argc != 3) die("usage: torii-mft DEVICE MOUNTPOINT > scan.json");
    int fd = open(argv[1], O_RDONLY);
    if (fd < 0) { perror(argv[1]); return 1; }
    uint8_t boot[512];
    if (pread(fd, boot, 512, 0) != 512 || memcmp(boot + 3, "NTFS    ", 8)) die("not an NTFS volume");
    uint32_t bps = u16(boot + 0x0B), spc = boot[0x0D], cl = bps * spc;
    int8_t cpr = (int8_t)boot[0x40];
    int rs = cpr > 0 ? cpr * cl : 1 << -cpr;
    uint64_t mft = u64(boot + 0x30) * cl;
    if (!cl || rs < 512 || rs > 65536) die("odd boot sector");

    uint8_t *rec = malloc(rs);
    if (pread(fd, rec, rs, mft) != rs) die("cannot read $MFT");
    if (!fixup(rec, rs)) die("$MFT record is damaged");
    /* the runs of $MFT's own data: where the table lies on the disk */
    typedef struct { uint64_t off, len; } run_t;
    run_t *runs = NULL; int nruns = 0; uint64_t mftsize = 0;
    int p = u16(rec + 0x14);
    while (p + 16 <= rs) {
        uint32_t type = u32(rec + p), len = u32(rec + p + 4);
        if (type == 0xFFFFFFFFu || len < 16 || p + (int)len > rs) break;
        if (type == 0x80 && rec[p + 9] == 0 && rec[p + 8]) {
            mftsize = u64(rec + p + 0x30);
            const uint8_t *q = rec + p + u16(rec + p + 0x20), *end = rec + p + len;
            int64_t lcn = 0;
            while (q < end && *q) {
                int ls = *q & 15, os = *q >> 4; q++;
                uint64_t n = 0; for (int i = 0; i < ls; i++) n |= (uint64_t)*q++ << (8 * i);
                int64_t d = 0; for (int i = 0; i < os; i++) d |= (int64_t)*q++ << (8 * i);
                if (os && (d >> (8 * os - 1)) & 1) d -= (int64_t)1 << (8 * os);
                lcn += d;
                runs = realloc(runs, (nruns + 1) * sizeof *runs);
                runs[nruns].off = os ? (uint64_t)lcn * cl : 0; runs[nruns].len = n * cl; nruns++;
            }
        }
        p += len;
    }
    if (!nruns || !mftsize) die("cannot find the $MFT data");
    nrec = mftsize / rs;
    if (nrec > 0x7FFFFFFF) die("MFT too large");
    parent = calloc(nrec, 4); nameoff = calloc(nrec, 4); head = calloc(nrec, 4); nxt = calloc(nrec, 4);
    asz = calloc(nrec, 8); dsz = calloc(nrec, 8); flags = calloc(nrec, 1);
    if (!parent || !nameoff || !head || !nxt || !asz || !dsz || !flags) die("out of memory");

    const size_t chunk = (size_t)rs * 4096;
    uint8_t *buf = malloc(chunk);
    uint64_t no = 0;
    for (int r = 0; r < nruns && no < nrec; r++) {
        uint64_t done = 0;
        while (done < runs[r].len && no < nrec) {
            size_t want = runs[r].len - done < chunk ? runs[r].len - done : chunk;
            ssize_t got = runs[r].off ? pread(fd, buf, want, runs[r].off + done) : 0;
            if (got <= 0) { if (runs[r].off) fprintf(stderr, "torii-mft: read error at %llu\n", (unsigned long long)(runs[r].off + done)); memset(buf, 0, want); got = want; }
            for (size_t o = 0; o + rs <= (size_t)got && no < nrec; o += rs, no++) parse(buf + o, rs, no);
            done += want;
        }
    }
    if (no < nrec) fprintf(stderr, "torii-mft: the table is in more pieces than this reads; %llu of %llu records seen\n", (unsigned long long)no, (unsigned long long)nrec);

    /* children lists; the root directory is record 5, system files (below 24) stay out */
    for (uint64_t i = nrec; i-- > 24;) {
        if ((flags[i] & (F_USED | F_NAME)) != (F_USED | F_NAME)) continue;
        uint64_t pa = parent[i];
        if (pa >= nrec || pa == i || !(flags[pa] & F_DIR)) continue;
        nxt[i] = head[pa]; head[pa] = i;
    }
    if (!(flags[5] & F_DIR)) die("no root directory found");
    nameoff[5] = add_name((const uint8_t *)"\0\0", 0);
    FILE *o = stdout;
    static char obuf[1 << 20]; setvbuf(o, obuf, _IOFBF, sizeof obuf);
    fprintf(o, "[1,2,{\"progname\":\"torii-mft\",\"progver\":\"1\",\"timestamp\":%ld},\n", (long)time(NULL));
    fputs("[{\"name\":", o); jstr(o, argv[2]); fputs("}", o);
    for (uint32_t c = head[5]; c; c = nxt[c]) { fputs(",\n", o); emit(o, c, 1); }
    fputs("]]\n", o);
    return 0;
}
