# HLS Image Processing Accelerator

## Overview

This project explores the design and optimization of FPGA-based image-processing accelerators using **High-Level Synthesis (HLS)**.

The long-term target is a hardware accelerator for **Sobel edge detection**, implemented first as a software reference and then progressively transformed into optimized hardware.

The project is intentionally built as a sequence of increasingly complex HLS laboratories rather than jumping directly into the final Sobel implementation.

The learning path is:

```text
C/C++ algorithm
      │
      ▼
   Bambu HLS
      │
      ▼
Generated Verilog RTL
      │
      ├── Icarus / Verilator simulation
      │
      ▼
Verified RTL
      │
      ▼
Optimization
      │
      ▼
FPGA implementation
      │
      ▼
Basys 3
```

The final project will investigate how HLS architectural decisions affect:

* Latency
* Throughput
* Initiation interval (II)
* FPGA resource utilization
* Memory architecture
* Parallelism
* Clock frequency
* End-to-end execution time

---

# 1. Project Motivation

The goal is not simply to convert C code into Verilog.

The project is intended to develop an understanding of **how algorithms become hardware architectures** and how an HLS designer controls that architecture.

The final accelerator should demonstrate concepts such as:

* Hardware datapaths
* Control logic
* Pipelining
* Loop scheduling
* Initiation interval
* Loop unrolling
* Memory access optimization
* Array partitioning
* Streaming architectures
* Line buffers
* Sliding windows
* Task-level dataflow
* Fixed-width arithmetic
* FPGA BRAM/LUT/FF/DSP utilization
* Hardware/software performance comparison

This provides a bridge between:

```text
Software algorithm
        ↓
HLS
        ↓
RTL architecture
        ↓
FPGA architecture
```

---

# 2. Main Research/Engineering Question

The central question of the project is:

> How do HLS architectural optimizations such as loop pipelining, line buffering, array partitioning, and task-level dataflow affect the latency, throughput, and FPGA resource utilization of a Sobel edge-detection accelerator?

The project will therefore contain multiple versions of the same algorithm rather than only one final implementation.

For example:

```text
Sobel CPU
   │
   ├── Naive HLS Sobel
   │
   ├── Pipelined Sobel
   │
   ├── Line-buffered Sobel
   │
   └── Optimized streaming Sobel
```

This makes it possible to measure the effect of each architectural change.

---

# 3. Why Sobel Edge Detection?

Sobel is a good first image-processing accelerator because it is computationally simple while exposing important hardware-design problems.

The algorithm operates on a 3×3 neighborhood of pixels.

For each pixel:

```text
p00 p01 p02
p10 p11 p12
p20 p21 p22
```

two convolutions are performed.

### Horizontal gradient

```text
Gx =

[-1   0  +1]
[-2   0  +2]
[-1   0  +1]
```

### Vertical gradient

```text
Gy =

[-1  -2  -1]
[ 0   0   0]
[+1  +2  +1]
```

The edge magnitude can be approximated using:

```text
Magnitude = |Gx| + |Gy|
```

instead of:

```text
sqrt(Gx² + Gy²)
```

The approximation avoids an expensive square-root operation and is suitable for a first FPGA implementation.

The result is then saturated to an 8-bit output:

```text
if magnitude > 255:
    output = 255
else:
    output = magnitude
```

---

# 4. Expected Sobel Architecture

The eventual streaming architecture will resemble:

```text
             Input Pixels
                  │
                  ▼
          ┌───────────────┐
          │ Line Buffers  │
          └───────┬───────┘
                  │
                  ▼
          ┌───────────────┐
          │ 3×3 Sliding   │
          │    Window     │
          └───────┬───────┘
                  │
          ┌───────┴────────┐
          ▼                ▼
      ┌────────┐       ┌────────┐
      │   Gx   │       │   Gy   │
      │ Datapath│      │ Datapath│
      └────┬───┘       └───┬────┘
           │               │
           ▼               ▼
         |Gx|             |Gy|
           │               │
           └───────┬───────┘
                   ▼
              |Gx| + |Gy|
                   │
                   ▼
              Saturation
                   │
                   ▼
              Output Pixel
```

The key hardware challenge is not the Sobel arithmetic itself.

The important challenge is efficiently supplying the 3×3 window to the computation every cycle.

This leads to:

* Line buffers
* Shift registers
* Sliding windows
* BRAM usage
* Memory bandwidth considerations
* Pipeline scheduling

---

# 5. HLS Tool Choice

## Bambu HLS

The primary HLS tool for this project is:

**PandA Bambu HLS**

Bambu was selected because the initial Vitis HLS installation/environment was not working reliably.

Rather than spending the project fighting the toolchain, the project uses Bambu as the HLS compiler.

Bambu performs approximately:

```text
C/C++
   ↓
Analysis
   ↓
Scheduling
   ↓
Allocation
   ↓
Binding
   ↓
Controller/datapath generation
   ↓
Verilog RTL
```

This is genuine HLS: the C program is interpreted as an algorithm that must be scheduled and mapped onto hardware.

---

# 6. Toolchain

The current development environment is a dedicated **Ubuntu 24.04** system.

The primary tools are:

| Tool           | Purpose                                       |
| -------------- | --------------------------------------------- |
| Bambu HLS      | C/C++ → Verilog                               |
| Icarus Verilog | RTL simulation                                |
| Verilator      | RTL simulation/linting                        |
| GCC/G++        | Software compilation/reference implementation |
| Python         | Image generation/analysis/benchmarking        |
| OpenCV         | Software image-processing reference           |
| GTKWave        | Waveform inspection                           |
| Git            | Version control                               |
| Vivado         | Final Basys 3 FPGA implementation             |

The conceptual tool flow is:

```text
C/C++
  │
  ├──────────────► GCC/OpenCV
  │                   │
  │                   ▼
  │              Software Reference
  │
  ▼
Bambu
  │
  ▼
Verilog
  │
  ├──► Icarus
  ├──► Verilator
  └──► GTKWave
          │
          ▼
      Verified RTL
          │
          ▼
       Vivado
          │
          ▼
       Basys 3
```

---

# 7. Bambu Installation

Bambu is installed as an AppImage.

Current location:

```text
~/eda_tools/bambu/bambu-2024.10.AppImage
```

The installed version was verified with:

```bash
./bambu-2024.10.AppImage --version
```

Current version:

```text
PandA 2024.10
Revision c2ba6936ca2ed63137095fea0b630a1c66e20e63-main
```

A system-wide command was configured through:

```bash
/usr/local/bin/bambu
```

so that Bambu can be invoked simply with:

```bash
bambu
```

Verification:

```bash
bambu --version
```

---

# 8. Project Directory

The HLS laboratory work is currently located at:

```text
~/works/hls/
```

The first laboratory is:

```text
~/works/hls/lab0/
```

The eventual project structure is intended to resemble:

```text
hls-image-processing/
│
├── README.md
│
├── software/
│   ├── sobel.cpp
│   ├── sobel.h
│   ├── benchmark.cpp
│   └── Makefile
│
├── python/
│   ├── generate_test_images.py
│   ├── reference.py
│   └── analyze_results.py
│
├── lab0/
│   └── adder/
│
├── lab1/
│   └── vector_add/
│
├── lab2/
│   └── mac/
│
├── lab3/
│   └── fir/
│
├── lab4/
│   └── convolution/
│
├── lab5/
│   └── sobel/
│
├── lab6/
│   └── sobel_pipeline/
│
├── lab7/
│   └── sobel_linebuffer/
│
├── lab8/
│   └── sobel_streaming/
│
├── fpga/
│   ├── vivado/
│   ├── constraints/
│   └── rtl/
│
├── simulation/
│   ├── cocotb/
│   └── waveforms/
│
├── images/
│   ├── input/
│   └── output/
│
├── results/
│   ├── cpu/
│   ├── hls/
│   └── fpga/
│
└── docs/
    ├── architecture.md
    ├── methodology.md
    └── results.md
```

The exact structure can evolve as the project grows.

---

# 9. Learning Strategy

The project deliberately uses a controlled difficulty ladder.

We will **not jump directly to Sobel**.

Each laboratory introduces one or two new hardware concepts.

```text
Lab 0
Adder
  │
  ▼
Lab 1
Vector Addition
  │
  ▼
Lab 2
MAC
  │
  ▼
Lab 3
FIR Filter
  │
  ▼
Lab 4
3×3 Convolution
  │
  ▼
Lab 5
Naive Sobel
  │
  ▼
Lab 6
Pipelined Sobel
  │
  ▼
Lab 7
Line-buffered Sobel
  │
  ▼
Lab 8
Streaming/optimized Sobel
  │
  ▼
Lab 9
FPGA implementation
```

---

# 10. Laboratory Progression

## Lab 0 — Simple Adder

### Objective

Understand the fundamental Bambu flow:

```text
C
 ↓
Bambu
 ↓
Verilog
 ↓
Icarus
 ↓
Simulation
```

### C source

```c
int adder(int a, int b)
{
    return a + b;
}
```

### Bambu command

```bash
bambu --top-fname=adder adder.c
```

### Important generated files

```text
adder.v
HLS_output/
synthesize_Synthesis_adder.sh
```

---

# 11. Lab 0 — What We Learned

The generated RTL contained several important components.

## Functional Unit

Bambu generated a module equivalent to:

```verilog
module ui_plus_expr_FU(in1, in2, out1);

    parameter BITSIZE_in1 = 1;
    parameter BITSIZE_in2 = 1;
    parameter BITSIZE_out1 = 1;

    input [BITSIZE_in1-1:0] in1;
    input [BITSIZE_in2-1:0] in2;
    output [BITSIZE_out1-1:0] out1;

    assign out1 = in1 + in2;

endmodule
```

For the actual adder, the parameters become 32 bits.

Therefore, the C statement:

```c
return a + b;
```

ultimately becomes actual hardware equivalent to:

```verilog
assign out1 = in1 + in2;
```

This is the first direct demonstration that HLS is producing hardware rather than simply compiling C code.

---

# 12. Lab 0 — Datapath

Bambu generated a datapath module containing:

```text
32-bit input a
32-bit input b
      │
      ▼
  32-bit adder
      │
      ▼
32-bit return value
```

There were no datapath registers for this trivial function.

This is consistent with the operation being implementable as a combinational addition.

---

# 13. Lab 0 — Controller

Bambu also generated a controller.

The controller handles:

```text
clock
reset
start_port
done_port
```

The generated controller had a single state:

```text
S_0
```

When:

```text
start_port = 1
```

the controller asserts:

```text
done_port = 1
```

while remaining in the same state.

This demonstrated an important HLS concept:

> HLS separates the computational datapath from the control/scheduling logic.

Even a trivial function therefore results in both:

```text
DATAPATH
+
CONTROLLER
```

---

# 14. Lab 0 — Timing Interpretation

Bambu reported information including:

```text
3 control steps
Estimated maximum frequency ≈ 385 MHz
Minimum/maximum cycles = 1
```

An important lesson was established here:

**Control steps are not automatically equivalent to clock cycles.**

For this function, Bambu determined that the operation can complete in one cycle.

The generated design contained no multi-cycle adder pipeline.

---

# 15. Lab 0 — RTL Verification

The generated Verilog was compiled using Icarus:

```bash
iverilog -o sim adder.v tb_adder.v
```

and executed using:

```bash
vvp sim
```

The first testbench demonstrated:

```text
a = 10
b = 20
result = 30
```

The initial testbench printed:

```text
a =         10, b =         20, result =         30, done = 0
```

The `done = 0` observation was caused by the testbench sampling `done_port` after deasserting `start_port`, rather than by an error in the generated hardware.

A second handshake-aware testbench was created to sample the design while:

```text
start_port = 1
```

and verify:

```text
done_port == 1
return_port == 30
```

The expected successful result is:

```text
START: a=10 b=20 done=1 result=30
PASS: 10 + 20 = 30
```

---

# 16. Lab 0 — Key Takeaways

Lab 0 establishes the following fundamental concepts:

### 1. HLS is not normal compilation

The transformation is:

```text
C algorithm
    ↓
hardware scheduling
    ↓
datapath + controller
    ↓
RTL
```

### 2. Simple C operations can become simple hardware

```c
a + b
```

becomes a hardware adder.

### 3. Bambu generates control logic

The hardware is not only the arithmetic operation.

There is also logic responsible for:

```text
start
done
reset
control state
```

### 4. RTL should be inspected

Generated RTL may be verbose and mechanically structured.

That is acceptable.

The purpose at this stage is to understand:

```text
What hardware did the HLS compiler actually create?
```

### 5. Simulation is mandatory

Every HLS stage should eventually follow:

```text
C reference
     ↓
HLS
     ↓
RTL
     ↓
simulation
     ↓
compare against reference
```

---

# 17. Next Laboratory — Lab 1: Vector Addition

The next laboratory is vector addition.

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

This is significantly more interesting than Lab 0.

It introduces:

* Loops
* Arrays
* Memory accesses
* Loop counters
* Multiple arithmetic operations
* Loop scheduling
* Memory allocation
* Potential resource sharing
* Potential parallelism

The key question becomes:

> How does Bambu transform a loop into hardware?

---

# 18. Lab 1 Learning Objectives

We will investigate:

### Sequential implementation

Potential architecture:

```text
a[0] + b[0]
      ↓
c[0]

a[1] + b[1]
      ↓
c[1]

...
```

One adder may be reused across iterations.

### Parallel implementation

Potential architecture:

```text
a[0] + b[0] → c[0]
a[1] + b[1] → c[1]
a[2] + b[2] → c[2]
...
```

Multiple adders may operate simultaneously.

The tradeoff becomes:

```text
More parallelism
      ↓
More hardware resources
      ↓
Potentially lower latency
```

versus:

```text
Resource sharing
      ↓
Less hardware
      ↓
Potentially higher latency
```

This is one of the central ideas of HLS.

---

# 19. Lab 2 — MAC

The next stage will introduce multiply-accumulate operations.

Conceptually:

```c
sum += a[i] * b[i];
```

This introduces:

* Multipliers
* Adders
* Accumulators
* DSP blocks
* Dependency chains
* Pipelining

This will be particularly relevant to FPGA architectures because multiplications may map to dedicated DSP resources.

---

# 20. Lab 3 — FIR Filter

A finite impulse response filter will introduce:

```text
Input stream
    ↓
Delay elements
    ↓
Multipliers
    ↓
Adders
    ↓
Output
```

This is an excellent bridge between basic HLS and image processing because FIR filters demonstrate:

* Streaming computation
* Sliding windows
* Regular datapaths
* Pipelining
* Data dependencies

---

# 21. Lab 4 — 3×3 Convolution

Before implementing Sobel, a generic 3×3 convolution will be developed.

For example:

```text
input image

p00 p01 p02
p10 p11 p12
p20 p21 p22
```

with:

```text
output =
p00*k00 +
p01*k01 +
p02*k02 +
p10*k10 +
p11*k11 +
p12*k12 +
p20*k20 +
p21*k21 +
p22*k22
```

This introduces the fundamental computational structure behind Sobel.

---

# 22. Lab 5 — Naive Sobel

The first Sobel implementation will prioritize correctness rather than performance.

Likely structure:

```text
for every pixel
    load 3×3 neighborhood
    calculate Gx
    calculate Gy
    calculate magnitude
    write output
```

The objective is to establish a correct hardware reference.

It is not expected to be optimal.

---

# 23. Lab 6 — Pipelined Sobel

The next version will investigate loop pipelining.

The target is approximately:

```text
Initiation Interval (II) = 1
```

Meaning the pipeline should ideally accept/process one new pixel every clock cycle after pipeline fill.

The conceptual difference is:

```text
Non-pipelined:

pixel 0 → finish
pixel 1 → finish
pixel 2 → finish


Pipelined:

cycle:  1   2   3   4   5
pixel0: A   B   C   D
pixel1:     A   B   C   D
pixel2:         A   B   C   D
```

The pipeline can have multiple stages while still accepting a new pixel every cycle.

---

# 24. Lab 7 — Line-Buffered Sobel

A naive implementation may repeatedly access image memory for overlapping 3×3 neighborhoods.

That is inefficient.

For example:

```text
pixel neighborhood 1:

A B C
D E F
G H I
```

and the next neighborhood:

```text
B C D
E F G
H I J
```

Most of the pixels are reused.

A line-buffer architecture exploits this reuse.

Conceptually:

```text
Input stream
     │
     ▼
┌────────────┐
│ Line Buffer │
├────────────┤
│ Line Buffer │
└──────┬─────┘
       ▼
  3×3 registers
       │
       ▼
    Sobel
```

This significantly reduces external memory traffic.

---

# 25. Lab 8 — Streaming/Optimized Sobel

The final HLS architecture will investigate:

* Streaming interfaces
* Line buffers
* Sliding windows
* Array partitioning
* Pipelining
* Resource sharing
* Loop unrolling
* Dataflow
* Memory architecture

The target architecture is approximately:

```text
Input stream
     │
     ▼
Line buffers
     │
     ▼
Sliding window
     │
     ▼
Sobel pipeline
     │
     ▼
Output stream
```

with the goal of sustaining approximately:

```text
1 pixel / clock
```

after pipeline startup.

---

# 26. FPGA Implementation

The target FPGA board is the **Basys 3**.

The Basys 3 uses an:

```text
Xilinx Artix-7
XC7A35T
```

The board will be used after the HLS design is thoroughly verified in simulation.

The FPGA implementation will initially avoid unnecessary complexity.

A sensible progression is:

```text
Static image
    ↓
BRAM
    ↓
Sobel accelerator
    ↓
BRAM output
```

Only after that works should the project investigate:

```text
UART
VGA
camera
real-time video
```

The purpose is to avoid making the project an I/O debugging exercise before the accelerator itself is proven.

---

# 27. Performance Evaluation

The final project should compare several implementations.

Potential comparison:

| Implementation          | Latency | Throughput | Resources |
| ----------------------- | ------: | ---------: | --------: |
| CPU/OpenCV              |       — |          — |       CPU |
| Naive HLS               |     TBD |        TBD |       TBD |
| Pipelined HLS           |     TBD |        TBD |       TBD |
| Line-buffer HLS         |     TBD |        TBD |       TBD |
| Optimized streaming HLS |     TBD |        TBD |       TBD |
| FPGA implementation     |     TBD |        TBD |       TBD |

The exact measurements will be filled in after implementation.

---

# 28. Important Performance Metrics

## Latency

Number of cycles required for a computation.

For a clock frequency:

```text
f = 100 MHz
```

one clock cycle is:

```text
10 ns
```

Therefore:

```text
100 cycles = 1 µs
```

---

## Initiation Interval

The number of cycles between successive pipeline launches.

For example:

```text
II = 1
```

means:

```text
cycle 1 → pixel 0
cycle 2 → pixel 1
cycle 3 → pixel 2
cycle 4 → pixel 3
```

after pipeline startup.

---

## Throughput

How much work can be completed per unit time.

For an II=1 pixel pipeline operating at 100 MHz:

```text
100 million pixels/second
```

can theoretically be processed after pipeline fill, assuming the rest of the architecture can sustain that rate.

---

## Resource Utilization

Important FPGA resources include:

* LUTs
* Flip-flops
* BRAM
* DSPs
* I/O
* Clock resources

The final design should report resource utilization rather than claiming that one implementation is "better" without measurements.

---

# 29. Arithmetic Considerations

Sobel operates on 8-bit pixels:

```text
0–255
```

However, intermediate values require more bits.

For example:

```text
|Gx| ≈ up to 1020
|Gy| ≈ up to 1020
```

and therefore:

```text
|Gx| + |Gy| ≈ up to 2040
```

The internal arithmetic must therefore use sufficiently wide signed types.

The output is eventually reduced to:

```text
8 bits
```

through saturation.

This is important in HLS because choosing unnecessarily large types can increase hardware resources, while choosing types that are too small can cause overflow.

---

# 30. Important HLS Concepts to Master

By the end of the project, the following concepts should be understood rather than merely used:

### C-to-hardware mapping

```text
C operation → hardware operation
```

### Scheduling

Determining when operations occur.

### Allocation

Determining what hardware resources are required.

### Binding

Mapping operations to specific functional units/resources.

### Controller

Hardware that sequences the computation.

### Datapath

Hardware that performs the computation.

### Pipeline

Overlapping multiple operations.

### Initiation Interval

How frequently new inputs can enter a pipeline.

### Loop unrolling

Executing multiple loop iterations in parallel.

### Array partitioning

Increasing memory parallelism by splitting arrays into independently accessible structures.

### Dataflow

Allowing independent processing stages to operate concurrently.

### Streaming

Processing data continuously rather than repeatedly loading/storing large intermediate datasets.

### Line buffering

Reusing image rows to construct sliding windows efficiently.

---

# 31. Verification Philosophy

Every stage should have a known-good reference.

The general methodology is:

```text
Reference C/Python implementation
             │
             ▼
        Known output
             │
             ▼
       HLS implementation
             │
             ▼
        Generated RTL
             │
             ▼
        RTL simulation
             │
             ▼
      Compare outputs
```

For image processing, the comparison should eventually include:

* Pixel-by-pixel comparison
* Maximum absolute error
* Number of mismatched pixels
* Visual comparison
* Possibly PSNR/SSIM where appropriate

For Sobel, exact pixel matching is preferable because the algorithm is deterministic.

---

# 32. Simulation Strategy

Icarus Verilog is currently being used for basic RTL simulation.

Verilator will also be used where useful.

For more complex designs, cocotb can be introduced:

```text
Python
  │
  ▼
cocotb
  │
  ▼
Verilator/Icarus
  │
  ▼
Generated RTL
```

This will make it easier to:

* Feed image data
* Automate tests
* Compare outputs
* Run many test cases
* Generate performance statistics

---

# 33. Project Development Rules

The project should follow several rules.

### Rule 1 — Correctness before optimization

First make:

```text
correct hardware
```

Then optimize it.

---

### Rule 2 — One architectural change at a time

Do not simultaneously change:

```text
pipeline
+
memory
+
unrolling
+
dataflow
```

without measuring intermediate versions.

Instead:

```text
baseline
  ↓
pipeline
  ↓
measure
  ↓
line buffer
  ↓
measure
  ↓
array partition
  ↓
measure
```

This makes the performance results meaningful.

---

### Rule 3 — Inspect generated RTL

Do not treat Bambu as a black box.

For every major laboratory, inspect:

```text
datapath
controller
memory
functional units
registers
pipeline structure
```

---

### Rule 4 — Keep software and hardware references

The software implementation provides the expected result.

The HLS implementation should be checked against it.

---

### Rule 5 — Record measurements

Each major version should record:

```text
clock frequency
latency
II
LUTs
FFs
BRAM
DSP
image size
execution time
```

---

# 34. Current Status

## Completed

### Environment

* [x] Ubuntu 24.04 development environment
* [x] Bambu HLS installed
* [x] Bambu command configured
* [x] Icarus Verilog installed
* [x] Verilator available

### Lab 0

* [x] Created `adder.c`
* [x] Compiled with Bambu
* [x] Generated Verilog
* [x] Inspected generated RTL
* [x] Identified functional unit
* [x] Identified datapath
* [x] Identified controller
* [x] Identified top-level interface
* [x] Created Verilog testbench
* [x] Simulated with Icarus
* [x] Verified `10 + 20 = 30`
* [x] Understood `start_port` / `done_port` behavior

---

# 35. Current Position

The project is currently here:

```text
Lab 0
Adder
  ✓
  │
  ▼
Lab 1
Vector Addition
  ← NEXT
  │
  ▼
Lab 2
MAC
  │
  ▼
Lab 3
FIR
  │
  ▼
Lab 4
3×3 Convolution
  │
  ▼
Lab 5
Naive Sobel
  │
  ▼
Lab 6
Pipelined Sobel
  │
  ▼
Lab 7
Line-buffer Sobel
  │
  ▼
Lab 8
Streaming/Optimized Sobel
  │
  ▼
Lab 9
Basys 3
```

---

# 36. Final Intended Deliverable

The final repository should demonstrate a complete hardware-acceleration workflow:

```text
Algorithm
   ↓
Software reference
   ↓
HLS implementation
   ↓
Generated RTL
   ↓
RTL verification
   ↓
Architectural optimization
   ↓
FPGA synthesis
   ↓
FPGA implementation
   ↓
Performance/resource analysis
```

The final report should explain not only **what was implemented**, but also:

1. Why the architecture was chosen.
2. What bottleneck existed in the previous implementation.
3. What HLS optimization was introduced.
4. How that optimization changed the generated hardware.
5. How latency changed.
6. How throughput changed.
7. How FPGA resource utilization changed.
8. What tradeoffs were introduced.

The emphasis is therefore on **hardware architecture and measurable optimization**, not simply obtaining a working Sobel image.

---

# 37. Long-Term Extensions

Once the Sobel pipeline is complete, possible extensions include:

### Gaussian Blur

```text
Image
 ↓
3×3/5×5 Gaussian filter
 ↓
Blurred image
```

### RGB → Grayscale

```text
R,G,B
 ↓
weighted conversion
 ↓
Y
```

### RGB → YCbCr

Useful for more advanced image/video pipelines.

### Multiple-stage pipeline

For example:

```text
RGB
 ↓
Grayscale
 ↓
Gaussian Blur
 ↓
Sobel
 ↓
Threshold
 ↓
Output
```

This would allow investigation of HLS task-level dataflow between multiple image-processing stages.

---

# 38. Core Principle

The project is ultimately about learning to answer this question:

> Given an algorithm written in C/C++, what hardware architecture will the HLS compiler generate, why did it generate that architecture, and how can the architecture be changed to achieve a specific latency/throughput/resource goal?

Sobel is the final application.

The real subject of the project is:

```text
HLS
+
Digital Design
+
Computer Architecture
+
FPGA Architecture
+
Performance Optimization
```

---

# 39. Immediate Next Step

Start **Lab 1 — Vector Addition**.

Target:

```c
void vector_add(int a[8], int b[8], int c[8])
{
    for (int i = 0; i < 8; i++)
    {
        c[i] = a[i] + b[i];
    }
}
```

The first objective is **not optimization**.

The objective is to understand how Bambu handles:

```text
loop
arrays
memory
iteration
multiple operations
```

Only after understanding the generated baseline RTL should we begin manipulating its architecture.

