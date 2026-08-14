#!/usr/bin/env python3
"""
Convert the NIST LWC KAT file into $readmemh-friendly hex files for the
SystemVerilog testbench.

Usage (from ascon_hw_verified/):
    python gen_kat_hex.py

Reads : ../ascon_python/pyascon/LWC_AEAD_KAT_128_128.txt
Writes: kat_meta.hex, kat_ad.hex, kat_pt.hex, kat_ct.hex, kat_tag.hex

File formats -- every record is fixed size, so the testbench can index by
plain arithmetic instead of parsing anything at simulation time:

  kat_meta.hex  1 line per vector, 32-bit word:
                    [31:24] ad_blocks   [23:20] ad_len
                    [19:12] data_blocks [11: 8] data_len
                    [ 7: 0] reserved (0)
  kat_ad.hex    MAXBLK lines per vector, 128-bit each (raw AD, unpadded --
                the hardware pads the final block from ad_len)
  kat_pt.hex    MAXBLK lines per vector, 128-bit each (raw plaintext)
  kat_ct.hex    MAXBLK lines per vector, 128-bit each (expected ciphertext)
  kat_tag.hex   1 line per vector, 128-bit expected tag

So vector i's AD block j lives at kat_ad[i*MAXBLK + j].

Byte order: byte j of a field sits at bits [8j+7:8j], i.e. a block's 128-bit
value is the little-endian integer of its bytes -- the same convention the
RTL uses everywhere.
"""

import os
import sys

RATE = 16          # bytes per block
MAXBLK = 3         # KAT max length is 32 bytes -> 2 full + 1 padding block
TAGLEN = 16

KAT_PATH = os.path.join("..", "ascon_python", "pyascon", "LWC_AEAD_KAT_128_128.txt")


def blk_to_int(b: bytes) -> int:
    """16 bytes (or fewer) -> the 128-bit value the RTL expects."""
    return int.from_bytes(b.ljust(RATE, b"\x00"), "little")


def parse_kat(path):
    """Yield dicts of {key, nonce, pt, ad, ct} as bytes, in file order."""
    cur = {}
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line:
                if cur:
                    yield cur
                    cur = {}
                continue
            if "=" not in line:
                continue
            name, _, val = line.partition("=")
            cur[name.strip().lower()] = bytes.fromhex(val.strip())
    if cur:
        yield cur


def main():
    if not os.path.exists(KAT_PATH):
        sys.exit(f"KAT file not found: {KAT_PATH}")

    vectors = list(parse_kat(KAT_PATH))
    if not vectors:
        sys.exit("No vectors parsed -- check the KAT file format.")

    # The RTL hardwires one key/nonce per run; the KAT uses the same pair
    # throughout. Verify that assumption rather than silently relying on it.
    key0, nonce0 = vectors[0]["key"], vectors[0]["nonce"]
    for i, v in enumerate(vectors):
        if v["key"] != key0 or v["nonce"] != nonce0:
            sys.exit(f"vector {i}: key/nonce differ from vector 0 -- "
                     "the testbench assumes they are constant.")

    f_meta = open("kat_meta.hex", "w")
    f_ad = open("kat_ad.hex", "w")
    f_pt = open("kat_pt.hex", "w")
    f_ct = open("kat_ct.hex", "w")
    f_tag = open("kat_tag.hex", "w")

    max_pt = max_ad = 0

    for i, v in enumerate(vectors):
        pt = v.get("pt", b"")
        ad = v.get("ad", b"")
        ctt = v.get("ct", b"")            # ciphertext ‖ tag

        if len(ctt) < TAGLEN:
            sys.exit(f"vector {i}: CT field shorter than a tag.")
        ct, tag = ctt[:-TAGLEN], ctt[-TAGLEN:]

        if len(ct) != len(pt):
            sys.exit(f"vector {i}: |CT| {len(ct)} != |PT| {len(pt)}")

        # --- block counts, matching the RTL's expectations ---
        # message: always floor(len/16)+1, never zero (an exact multiple of
        # 16 still needs a whole extra all-padding block)
        data_blocks = len(pt) // RATE + 1
        data_len = len(pt) % RATE

        # AD: zero blocks means "no AD at all" and skips the loop entirely
        if len(ad) == 0:
            ad_blocks, ad_len = 0, 0
        else:
            ad_blocks = len(ad) // RATE + 1
            ad_len = len(ad) % RATE

        if data_blocks > MAXBLK or ad_blocks > MAXBLK:
            sys.exit(f"vector {i}: needs more than MAXBLK={MAXBLK} blocks; "
                     "raise MAXBLK here and in the testbench.")

        max_pt = max(max_pt, len(pt))
        max_ad = max(max_ad, len(ad))

        meta = ((ad_blocks & 0xFF) << 24 | (ad_len & 0xF) << 20 |
                (data_blocks & 0xFF) << 12 | (data_len & 0xF) << 8)
        f_meta.write(f"{meta:08x}\n")
        f_tag.write(f"{blk_to_int(tag):032x}\n")

        # zero-pad every field out to MAXBLK lines so records stay fixed size
        for j in range(MAXBLK):
            f_ad.write(f"{blk_to_int(ad[j*RATE:(j+1)*RATE]):032x}\n")
            f_pt.write(f"{blk_to_int(pt[j*RATE:(j+1)*RATE]):032x}\n")
            f_ct.write(f"{blk_to_int(ct[j*RATE:(j+1)*RATE]):032x}\n")

    for f in (f_meta, f_ad, f_pt, f_ct, f_tag):
        f.close()

    print(f"vectors written : {len(vectors)}")
    print(f"key             : {key0.hex().upper()}")
    print(f"nonce           : {nonce0.hex().upper()}")
    print(f"max PT / AD     : {max_pt} / {max_ad} bytes  (MAXBLK={MAXBLK})")
    print()
    print("Put this in the testbench:")
    print(f"    localparam int NVEC   = {len(vectors)};")
    print(f"    localparam int MAXBLK = {MAXBLK};")
    print(f"    localparam logic [127:0] KAT_KEY   = 128'h{blk_to_int(key0):032x};")
    print(f"    localparam logic [127:0] KAT_NONCE = 128'h{blk_to_int(nonce0):032x};")


if __name__ == "__main__":
    main()
