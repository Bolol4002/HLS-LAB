`timescale 1ns / 1ps

// Testbench for the Bambu-generated vector_add RTL.
// vector_add(int a[8], int b[8], int c[8]):
//   for (i = 0; i < 8; i++) c[i] = a[i] + b[i];
//
// The generated core uses a generic 2-port, byte-addressed memory interface:
//   - Read:  assert Mout_oe_ram[i] with the address on Mout_addr_ram;
//            data is returned on M_Rdata_ram one clock cycle later.
//   - Write: assert Mout_we_ram[i] with address/data on Mout_*_ram;
//            data is committed on the clock edge.
//
// The memory model below implements exactly those semantics.

module vector_add_tb;

  reg         clock = 0;
  reg         reset = 1;
  reg         start_port = 0;
  reg  [31:0] a;
  reg  [31:0] b;
  reg  [31:0] c;

  wire        done_port;
  wire [1:0]  Mout_oe_ram;
  wire [1:0]  Mout_we_ram;
  wire [63:0] Mout_addr_ram;
  wire [63:0] Mout_Wdata_ram;
  wire [11:0] Mout_data_ram_size;

  // ---- memory model ----
  localparam MEM_WORDS = 256;
  reg [31:0]  mem [0:MEM_WORDS-1];

  // Latched byte addresses for the two read ports
  reg [9:0]   laddr0 = 0;
  reg [9:0]   laddr1 = 0;

  // Read request flagged one cycle earlier -> data ready this cycle
  reg [1:0]   oe_delayed = 0;

  wire [63:0] M_Rdata_ram;
  wire [1:0]  M_DataRdy;

  assign M_Rdata_ram = {mem[laddr1[9:2]], mem[laddr0[9:2]]};
  assign M_DataRdy   = oe_delayed;

  // Latch the address of every read request; keep the data stable after it
  // so the datapath can capture it in the following cycle.
  always @(posedge clock) begin
    if (Mout_oe_ram[0]) laddr0 <= Mout_addr_ram[9:0];
    if (Mout_oe_ram[1]) laddr1 <= Mout_addr_ram[41:32];
    oe_delayed <= Mout_oe_ram;
  end

  // Synchronous writes
  always @(posedge clock) begin
    if (Mout_we_ram[0]) mem[Mout_addr_ram[9:2]] <= Mout_Wdata_ram[31:0];
    if (Mout_we_ram[1]) mem[Mout_addr_ram[41:34]] <= Mout_Wdata_ram[63:32];
  end

  // ---- DUT ----
  vector_add dut (
    .clock              (clock),
    .reset              (reset),
    .start_port         (start_port),
    .a                  (a),
    .b                  (b),
    .c                  (c),
    .M_Rdata_ram        (M_Rdata_ram),
    .M_DataRdy          (M_DataRdy),
    .done_port          (done_port),
    .Mout_oe_ram        (Mout_oe_ram),
    .Mout_we_ram        (Mout_we_ram),
    .Mout_addr_ram      (Mout_addr_ram),
    .Mout_Wdata_ram     (Mout_Wdata_ram),
    .Mout_data_ram_size (Mout_data_ram_size)
  );

  // ---- clock ----
  always #5 clock = ~clock;

  // ---- stimulus ----
  integer i;
  integer errors;
  reg [31:0] expected;
  reg        observed_done;

  initial begin
    errors = 0;
    observed_done = 0;

    for (i = 0; i < MEM_WORDS; i = i + 1)
      mem[i] = 0;

    // a[i] = 0x10 + i*4 ; b[i] = 0x200 + i*7 ; c base = 0x300
    for (i = 0; i < 8; i = i + 1) begin
      mem[(32'h100 >> 2) + i] = 32'h10 + i * 4;
      mem[(32'h200 >> 2) + i] = 32'h200 + i * 7;
    end

    a = 32'h100;
    b = 32'h200;
    c = 32'h300;

    $dumpfile("vector_add_tb.vcd");
    $dumpvars(0, vector_add_tb);

    // Reset (active low), release, then start
    reset = 0;
    repeat (2) @(posedge clock);
    reset = 1;
    repeat (2) @(posedge clock);

    start_port = 1;
    @(posedge clock);
    start_port = 0;

    // Wait for done or timeout
    for (i = 0; i < 128; i = i + 1) begin
      @(posedge clock);
      if (done_port) begin
        observed_done = 1;
        i = 128; // break
      end
    end

    if (!observed_done) begin
      $display("FAIL: done_port never asserted (timeout)");
      $finish;
    end

    // Verify every c[i]
    for (i = 0; i < 8; i = i + 1) begin
      expected = (32'h10 + i * 4) + (32'h200 + i * 7);
      if (mem[(32'h300 >> 2) + i] !== expected) begin
        $display("MISMATCH c[%0d]: got=%0d (0x%h) expected=%0d (0x%h)",
                 i, mem[(32'h300 >> 2) + i], mem[(32'h300 >> 2) + i], expected, expected);
        errors = errors + 1;
      end else begin
        $display("OK c[%0d] = %0d", i, mem[(32'h300 >> 2) + i]);
      end
    end

    if (errors == 0)
      $display("PASS: vector_add computed all 8 elements correctly");
    else
      $display("FAIL: %0d mismatches", errors);

    $finish;
  end

endmodule