#!/usr/bin/env python3
"""
fb2png.py — decode a CoCo3 GIME framebuffer dump into a native 1:1 PNG.

The port runs 320x200 at 16 colours (4bpp), 160 bytes/row, single buffer
(CLAUDE.md 2G). Each byte holds two pixels, high nibble leftmost; each nibble
is a palette INDEX into $FFB0-$FFBF.

Why decode rather than use MAME's snapshot: mame-idioms-coco3-port.md 11b —
a MAME screen snapshot is not square-pixel, and decoding the framebuffer is
independent of MAME's display path entirely. On this project MAME 0.281's
Lua screen:snapshot() also wrote no file at all, silently.

The palette registers are WRITE-ONLY, so the palette cannot be read back out of
a running machine; it has to be captured from the guest's writes. The harness
taps $FFB0-$FFBF and writes them here as a 16-byte file.

RGB-monitor decode (idioms 18a): the byte is a bitpack R1 G1 B1 R0 G0 B0, two
bits per channel. That is the decode MAME uses with Monitor Type = RGB, which
is the mode CLAUDE.md 4 gates on. Composite decode is a different function of
the same byte and is NOT what this produces.

Usage:
    fb2png.py --fb build/a2c/fb-x.bin --pal build/a2c/palette.bin --out x.png
              [--scale N] [--width 320] [--height 200]
"""

import argparse
import struct
import zlib


def gime_rgb(byte):
    """GIME palette byte -> (r, g, b), RGB-monitor bitpack decode."""
    r = (((byte >> 5) & 1) << 1) | ((byte >> 2) & 1)
    g = (((byte >> 4) & 1) << 1) | ((byte >> 1) & 1)
    b = (((byte >> 3) & 1) << 1) | (byte & 1)
    return r * 85, g * 85, b * 85


def write_png(path, width, height, rows_rgb):
    raw = bytearray()
    for row in rows_rgb:
        raw.append(0)                      # filter type 0 (None)
        raw += row

    def chunk(tag, payload):
        out = struct.pack(">I", len(payload)) + tag + payload
        return out + struct.pack(">I", zlib.crc32(tag + payload) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += chunk(b"IEND", b"")
    with open(path, "wb") as handle:
        handle.write(png)
    return len(png)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--fb", required=True, help="framebuffer dump")
    ap.add_argument("--pal", help="16-byte palette dump; greyscale ramp if absent")
    ap.add_argument("--out", required=True)
    ap.add_argument("--width", type=int, default=320)
    ap.add_argument("--height", type=int, default=200)
    ap.add_argument("--scale", type=int, default=3,
                    help="integer nearest-neighbour upscale (never fractional)")
    args = ap.parse_args()

    with open(args.fb, "rb") as handle:
        fb = handle.read()

    if args.pal:
        with open(args.pal, "rb") as handle:
            pal_bytes = handle.read()[:16]
    else:
        pal_bytes = b""

    if len(pal_bytes) == 16:
        palette = [gime_rgb(b) for b in pal_bytes]
        pal_src = "captured GIME writes"
    else:
        palette = [(i * 17, i * 17, i * 17) for i in range(16)]
        pal_src = "PLACEHOLDER greyscale ramp (no palette captured)"

    stride = args.width // 2                 # 4bpp -> 2 px per byte
    need = stride * args.height
    if len(fb) < need:
        raise SystemExit("framebuffer is %d bytes, need %d for %dx%d"
                         % (len(fb), need, args.width, args.height))

    scale = max(1, args.scale)
    rows = []
    for y in range(args.height):
        line = bytearray()
        base = y * stride
        for x in range(stride):
            byte = fb[base + x]
            for idx in ((byte >> 4) & 0x0F, byte & 0x0F):
                r, g, b = palette[idx]
                line += bytes((r, g, b)) * scale
        for _ in range(scale):
            rows.append(line)

    size = write_png(args.out, args.width * scale, args.height * scale, rows)
    print("%s: %dx%d (scale %d), %d bytes" %
          (args.out, args.width * scale, args.height * scale, scale, size))
    print("  palette: %s" % pal_src)
    print("  indices used: %s" % sorted({
        n for byte in fb[:need] for n in ((byte >> 4) & 0xF, byte & 0xF)
    }))


if __name__ == "__main__":
    main()
