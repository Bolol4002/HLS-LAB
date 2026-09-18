# Lab 1 — Vector Addition

## Objective

Understand how Bambu transforms a **loop over arrays** into hardware.

Target C function:

```c
void vector_add(int a[8], int b[8], int c[8])
{
    for (int i = 0; i < 8; i++)
    {
        c[i] = a[i] + b[i];
    }
}
```

Lab 1 introduces, for the first time:

* Loops
* Arrays
* Memory accesses
* Loop counters
* Multiple arithmetic operations
* Loop scheduling
* Memory allocation
* Resource sharing / parallelism

The key question:

> How does Bambu transform a loop into hardware?

---

## Files

| File                        | Purpose                                            |
| --------------------------- | -------------------------------------------------- |
| `vector_add.c`              | HLS C source of `vector_add`                       |
| `vector_add.v`              | Bambu-generated Verilog RTL                        |
| `vector_add_tb.v`           | Icarus Verilog testbench                       |
| `vector_add_tb.vvp`         | Compiled simulation binary                     |
| `vector_add_tb.vcd`         | Simulation waveform dump                           |
| `synthesize_Synthesis_vector_add.sh` | Generated synthesis script               |
| `HLS_output/`               | Bambu auxiliary outputs (Vivado flow scripts)      |

---

## HLS Flow

```text
vector_add.c
      │
      ▼
    Bambu
      │
      ▼
  vector_add.v
      │
      ▼
   Icarus
      │
      ▼
  simulation (vector_add_tb.vcd)
      │
      ▼
   compare against C reference
```

Command used:

```bash
bambu --top-fname=vector_add vector_add.c
```

---

## Generated RTL Interface

Unlike Lab 0's combinational adder, `vector_add` operates on arrays, so the
generated core exposes a **generic 2-port, byte-addressed memory interface**:

* **Read:** assert `Mout_oe_ram[i]` with the address on `Mout_addr_ram`;
  data is returned on `M_Rdata_ram` one clock cycle later.
* **Write:** assert `Mout_we_ram[i]` with address/data on `Mout_*_ram`;
  data is committed on the clock edge.

The testbench implements a memory model with exactly these semantics, so the
DUT sees a realistic memory subsystem.

Handshake signals are the same as Lab 0:

```text
start_port
done_port
```

---

## Verification

The testbench:

* Initializes memory with:

  ```text
  a[i] = 0x10 + i*4
  b[i] = 0x200 + i*7
  c    = 0x300 (output base)
  ```

* Applies reset, releases it, then pulses `start_port`.
* Waits for `done_port` (with a timeout guard).
* Checks every `c[i]` against the expected value:

  ```text
  expected[i] = (0x10 + i*4) + (0x200 + i*7)
  ```

Run:

```bash
iverilog -o vector_add_tb.vvp vector_add.v vector_add_tb.v
vvp vector_add_tb.vvp
```

Waveform:

```bash
gtkwave vector_add_tb.vcd
```

---

## What to Look For in the RTL

When inspecting `vector_add.v`:

* **Controller:** how loop iterations are sequenced.
* **Datapath:** how many adder(s) were allocated.
* **Memory:** how the two read ports / one write port are used.
* **Loop counter:** how the induction variable `i` is implemented.
* **Scheduling:** the number of control steps / cycles for the whole loop.

Observe whether Bambu chose:

```text
Resource sharing (one adder reused per iteration)
```

or

```text
Parallelism        (multiple independent adders)
```

This is the central design tradeoff introduced in Lab 1.

---

## Status

| Step                         | Status |
| ---------------------------- | ------ |
| `vector_add.c` created       | [x]    |
| Bambu synthesis              | [x]    |
| RTL generated (`vector_add.v`) | [x]  |
| Testbench written            | [x]    |
| Icarus simulation            | [x]    |
| Waveform generated (`*.vcd`) | [x]    |
| All 8 elements verified      | [x]    |