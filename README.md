# Ascon-AEAD128 — SystemVerilog RTL

Hardware implementation of **Ascon-AEAD128**, the authenticated encryption scheme
standardised in **NIST SP 800-232** (final, August 2025). Encryption and decryption,
round-based iterative, verified against all 1089 reference test vectors.

```
1089 / 1089 KAT vectors passing  ·  encrypt + decrypt + tag rejection
2178 / 2178 UVM transactions passing  ·  100% functional coverage
```

## Design

320-bit sponge state, 128-bit rate, `p^12` for initialisation/finalisation and
`p^8` for data processing. One permutation round per clock cycle, one shared
permutation instance across all phases — chosen for area over throughput.

| module | role |
|---|---|
| `s_box.sv` | 5-bit Ascon S-box as a gate network (not a LUT) |
| `p_add_const.sv` | round-constant addition into lane x2 |
| `p_sub.sv` | substitution layer — 64 bit-sliced S-boxes |
| `p_diff.sv` | linear diffusion (rotate + XOR per lane) |
| `p_round.sv` | one combinational round: add → sub → diff |
| `ascon_perm.sv` | iterative controller, `num_rounds` ∈ {6, 8, 12} |
| `ascon_aead.sv` | AEAD FSM: init → AD → data → finalise → tag |

`ascon_perm` derives its round-constant offset internally from `num_rounds`, so a
caller cannot pair a round count with the wrong constants.

## Interface

Ports are named by **role**, not content — the data direction flips between modes.

| signal | dir | `decr_en=0` (encrypt) | `decr_en=1` (decrypt) |
|---|---|---|---|
| `key`, `nonce` | in | 128 bits each | — |
| `data_in` | in | plaintext block | ciphertext block |
| `data_out_block`, `data_out_valid` | out | ciphertext, one per pulse | plaintext, one per pulse |
| `data_blocks`, `data_idx`, `data_len` | in/out/in | block count, requested index, bytes in final block | — |
| `ad_block`, `ad_blocks`, `ad_idx`, `ad_len` | in/in/out/in | associated data, same scheme | — |
| `tag` | out | computed tag | computed tag |
| `tag_in`, `tag_ok` | in/out | unused | received tag / verification result |
| `start`, `busy`, `done` | in/out/out | handshake | — |

Blocks are fetched by index: the core drives `*_idx`, the caller answers
combinationally (`assign ad_block = ad_mem[ad_idx];`). Padding for the final AD
and data blocks is generated in hardware from `ad_len` / `data_len`.

## Verification

Golden values come from the Ascon reference implementation
([pyascon](https://github.com/meichlseder/pyascon)).

| testbench | scope |
|---|---|
| `ascon_aead_nist_tb.sv` | **full sweep** — 1089 KAT vectors × 3 passes |
| `ascon_aead_full_tb.sv` | 8-vector smoke test for fast iteration |
| `p_sub_tb.sv` | substitution layer vs. the spec S-box table |
| `p_add_tb.sv` | round-constant addition, directed |

Each AEAD vector runs three passes:

1. **encrypt** — ciphertext blocks and tag vs. the reference
2. **decrypt** — recovered plaintext vs. the original, `tag_ok == 1`
3. **reject** — one bit flipped in `tag_in`, `tag_ok` must be `0`

Pass 3 is what proves authentication: every other check would still succeed if
`tag_ok` were tied high. Coverage spans plaintext and associated-data lengths of
0–32 bytes, including empty inputs and exact block multiples (which require an
extra all-padding block).

### UVM environment

A second, independent verification environment under `uvm/`, built as a standard
UVM testbench and run under Vivado XSim.

| component | role |
|---|---|
| `ascon_if.sv` | interface with `drv_cb` / `mon_cb` clocking blocks |
| `ascon_sequence_item.sv` | key, nonce, AD, message, mode, and observed results |
| `ascon_driver.sv` | packs bytes into blocks, drives the `start` handshake |
| `ascon_monitor.sv` | pin-only observation — never sees the stimulus object |
| `ascon_scoreboard.sv` | holds the expected half of the KAT database |
| `ascon_subscriber.sv` | functional coverage on message/AD length and mode |
| `ascon_kat_sequence.sv`, `ascon_dec_sequence.sv` | directed KAT stimulus |

The monitor reconstructs each transaction from pins alone and the scoreboard
never sees the stimulus files, so neither side can bias the check.

```sh
cd uvm && ascon_run_uvm.bat
```

Result: **2178 transactions checked, 2178 passed, 0 failed**, functional
coverage **100%** — length bins from empty through 32 bytes, crossed with
associated-data length, in both encrypt and decrypt modes.

## Build

ModelSim / Questa:

```sh
python gen_kat_hex.py          # generate KAT vectors (once)

vlib work
vlog -work work -sv rtl/s_box.sv rtl/p_add_const.sv rtl/p_sub.sv rtl/p_diff.sv \
                    rtl/p_round.sv rtl/ascon_perm.sv rtl/ascon_aead.sv
vlog -work work -sv tb/ascon_aead_nist_tb.sv
vsim -c work.ascon_aead_nist_tb -do "run -all; quit"
```

`gen_kat_hex.py` converts `LWC_AEAD_KAT_128_128.txt` into `$readmemh` files; run
`vsim` from this directory so those paths resolve.

## Synthesis

Vivado 2023.1, target `xc7a35tcpg236-1` (Artix-7), default strategy,
post-synthesis:

| metric | value |
|---|---|
| Slice LUTs | 1686 (8.1%) |
| Slice registers | 1573 (3.8%) |
| Block RAM | 0 |
| DSP | 0 |
| WNS | +4.493 ns |
| Fmax | ≈ 182 MHz |
| Throughput | ≈ 2.1 Gbit/s |

`ascon_perm` dominates at 937 LUTs / 648 FFs, of which `p_sub` is 112 LUTs —
the S-box network is cheap; the round-state registers and the permutation
control account for most of the area. No inferred memories, so the design is
portable to an ASIC flow without technology-specific primitives.

Figures are post-synthesis. The core exposes 944 parallel I/O bits, more than
the package provides, so full implementation requires a bus wrapper — the
next planned step.

## Notes

Targets **Ascon-AEAD128** (SP 800-232, IV `0x00001000808c0001`, rate 128, b=8) —
not the earlier Ascon v1.2 / CAESAR variant (IV `0x80400c0600000000`, rate 64,
b=6). The two are different algorithms and their constants are not interchangeable.

## References

- [NIST SP 800-232](https://csrc.nist.gov/pubs/sp/800/232/final)
- [Ascon homepage](https://ascon.iaik.tugraz.at/)
