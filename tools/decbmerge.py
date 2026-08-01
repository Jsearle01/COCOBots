#!/usr/bin/env python3
"""
decbmerge.py — read, report on, and concatenate DECB (Disk Extended Color BASIC)
binary files.

A DECB "machine language" file is a sequence of segments followed by one end block:

    segment:    $00  len(2, big-endian)  load(2, big-endian)  <len bytes of data>
    end block:  $FF  $0000               exec(2, big-endian)

Merging is therefore just: keep every segment from every input, drop their end
blocks, and append a single end block carrying the chosen exec address. DECB's
LOADM walks the segments in order and writes each to its own load address, so the
merged file loads the game, the tileset and one level in a single LOADM.

Usage:
    decbmerge.py report  <file> [...]
    decbmerge.py merge   --out OUT --exec ADDR <file> [...]
    decbmerge.py compare <file-a> <file-b>

Addresses accept 0x1234, $1234 or decimal. Note that lwasm's --define does NOT
(idioms §25) — that is a different parser; this one is ours.
"""

import sys
import argparse


class DecbError(Exception):
    pass


def parse_addr(text):
    """Accept $1234, 0x1234 or decimal. Unlike lwasm -D, $ works here."""
    text = text.strip()
    if text.startswith("$"):
        return int(text[1:], 16)
    if text.lower().startswith("0x"):
        return int(text, 16)
    return int(text, 10)


def read_decb(path):
    """Return (segments, exec_addr). segments is a list of (load_addr, data)."""
    with open(path, "rb") as handle:
        blob = handle.read()

    segments = []
    exec_addr = None
    pos = 0
    while pos < len(blob):
        if pos + 5 > len(blob):
            raise DecbError(
                "%s: truncated block header at offset %d (%d bytes left, need 5)"
                % (path, pos, len(blob) - pos)
            )
        kind = blob[pos]
        length = (blob[pos + 1] << 8) | blob[pos + 2]
        addr = (blob[pos + 3] << 8) | blob[pos + 4]
        pos += 5

        if kind == 0x00:
            if pos + length > len(blob):
                raise DecbError(
                    "%s: segment at $%04X claims %d bytes, only %d remain"
                    % (path, addr, length, len(blob) - pos)
                )
            segments.append((addr, blob[pos:pos + length]))
            pos += length
        elif kind == 0xFF:
            exec_addr = addr
            if pos != len(blob):
                raise DecbError(
                    "%s: %d trailing bytes after the end block"
                    % (path, len(blob) - pos)
                )
            break
        else:
            raise DecbError(
                "%s: unknown block type $%02X at offset %d (expected $00 or $FF)"
                % (path, kind, pos - 5)
            )

    if exec_addr is None:
        raise DecbError("%s: no end block ($FF) — file is incomplete" % path)
    return segments, exec_addr


def write_decb(path, segments, exec_addr):
    out = bytearray()
    for addr, data in segments:
        if len(data) > 0xFFFF:
            raise DecbError("segment at $%04X exceeds 65535 bytes" % addr)
        out.append(0x00)
        out += len(data).to_bytes(2, "big")
        out += addr.to_bytes(2, "big")
        out += data
    out.append(0xFF)
    out += (0).to_bytes(2, "big")
    out += exec_addr.to_bytes(2, "big")
    with open(path, "wb") as handle:
        handle.write(out)
    return len(out)


def find_overlaps(segments):
    """Return a list of (index_a, index_b) whose address ranges intersect."""
    clashes = []
    spans = [(a, a + len(d) - 1, i) for i, (a, d) in enumerate(segments) if d]
    spans.sort()
    for i in range(len(spans)):
        for j in range(i + 1, len(spans)):
            if spans[j][0] > spans[i][1]:
                break
            clashes.append((spans[i][2], spans[j][2]))
    return clashes


# Regions DECB itself is using while, or just after, a LOADM. A segment landing in
# one of these is the class of fault documented in mame-idioms-coco3-port.md §23,
# §28 and §14e — each cost a full dispatch to find on the POP port.
DECB_HAZARDS = [
    (0x0100, 0x01FF, "DECB live IRQ vectors ($010C dispatch) — idioms 14e"),
    (0x02DC, 0x03D5, "BASIC line-input buffer — typing EXEC lands here, idioms 28"),
    (0x0400, 0x05FF, "VDG text screen — DECB prints OK here, idioms 28"),
    (0x0600, 0x09FF, "DBUF0/DBUF1/FAT/FCBs — live during LOADM, idioms 23"),
]


def report(segments, exec_addr, label):
    print("%s" % label)
    print("  %-4s %-7s %-7s %8s  %s" % ("#", "load", "end", "length", "note"))
    total = 0
    for i, (addr, data) in enumerate(segments):
        end = addr + len(data) - 1
        notes = []
        for lo, hi, why in DECB_HAZARDS:
            if addr <= hi and end >= lo:
                notes.append("HAZARD: %s" % why)
        total += len(data)
        print("  %-4d $%04X   $%04X   %8d  %s"
              % (i, addr, end, len(data), "; ".join(notes)))
    print("  exec  $%04X" % exec_addr)
    print("  %d segments, %d bytes of payload" % (len(segments), total))

    lows = [a for a, d in segments if d]
    highs = [a + len(d) - 1 for a, d in segments if d]
    if lows:
        print("  span  $%04X-$%04X" % (min(lows), max(highs)))

    clashes = find_overlaps(segments)
    if clashes:
        for a, b in clashes:
            print("  OVERLAP: segment %d and segment %d" % (a, b))
    else:
        print("  overlaps: none")
    return clashes


def cmd_report(args):
    bad = 0
    for path in args.files:
        segments, exec_addr = read_decb(path)
        if report(segments, exec_addr, path):
            bad = 1
        print("")
    return bad


def cmd_merge(args):
    merged = []
    for spec in args.files:
        segments, own_exec = read_decb(spec)
        print("  + %-28s %d segment(s), exec $%04X"
              % (spec, len(segments), own_exec))
        merged += segments

    exec_addr = parse_addr(args.exec_addr)
    size = write_decb(args.out, merged, exec_addr)
    print("")
    clashes = report(merged, exec_addr, args.out)
    print("  file  %d bytes" % size)
    if clashes:
        print("ERROR: overlapping segments — refusing to call this good.")
        return 1
    return 0


def cmd_compare(args):
    with open(args.a, "rb") as handle:
        blob_a = handle.read()
    with open(args.b, "rb") as handle:
        blob_b = handle.read()

    if blob_a == blob_b:
        print("IDENTICAL: %s == %s (%d bytes)" % (args.a, args.b, len(blob_a)))
        return 0

    print("DIFFER: %s (%d B) vs %s (%d B)"
          % (args.a, len(blob_a), args.b, len(blob_b)))
    limit = min(len(blob_a), len(blob_b))
    shown = 0
    for i in range(limit):
        if blob_a[i] != blob_b[i]:
            print("  offset %d ($%04X): $%02X vs $%02X"
                  % (i, i, blob_a[i], blob_b[i]))
            shown += 1
            if shown >= 20:
                print("  ... (further differences suppressed)")
                break
    if shown == 0:
        print("  common prefix identical; lengths differ by %d bytes"
              % abs(len(blob_a) - len(blob_b)))
    return 1


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[1])
    sub = parser.add_subparsers(dest="command", required=True)

    p_report = sub.add_parser("report", help="print the segment table")
    p_report.add_argument("files", nargs="+")
    p_report.set_defaults(func=cmd_report)

    p_merge = sub.add_parser("merge", help="concatenate segments into one file")
    p_merge.add_argument("--out", required=True)
    p_merge.add_argument("--exec", dest="exec_addr", required=True,
                         help="exec address, e.g. 0x0E01")
    p_merge.add_argument("files", nargs="+")
    p_merge.set_defaults(func=cmd_merge)

    p_cmp = sub.add_parser("compare", help="byte-compare two files")
    p_cmp.add_argument("a")
    p_cmp.add_argument("b")
    p_cmp.set_defaults(func=cmd_compare)

    args = parser.parse_args()
    try:
        return args.func(args)
    except DecbError as err:
        print("ERROR: %s" % err, file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
