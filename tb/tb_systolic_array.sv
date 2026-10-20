`timescale 1ns/1ps
// Self-checking testbench. Golden model is computed inline (full-precision
// integer matmul) and compared against every c_out row the DUT produces.
module tb_systolic_array;
  parameter int N      = 8;
  parameter int DATA_W = 8;
  localparam int ACC_W   = 2*DATA_W + $clog2(N);
  localparam int ROW_W   = (N > 1) ? $clog2(N) : 1;
  localparam int MAXROWS = 2048;

  logic clk = 1'b0;
  logic rst_n = 1'b0;
  logic w_load_en = 1'b0;
  logic [ROW_W-1:0] w_load_row = '0;
  logic [N-1:0][DATA_W-1:0] w_load_data = '0;
  logic a_valid = 1'b0;
  logic [N-1:0][DATA_W-1:0] a_in = '0;
  logic c_valid;
  logic [N-1:0][ACC_W-1:0] c_out;

  systolic_array #(.N(N), .DATA_W(DATA_W), .ACC_W(ACC_W)) dut (.*);

  always #5 clk = ~clk;

`ifdef DUMP
  initial begin $dumpfile("sim.vcd"); $dumpvars(0, tb_systolic_array); end
`endif

  int W_mat   [N][N];
  int exp_mem [MAXROWS][N];
  int wr_ptr = 0, rd_ptr = 0;
  int errors = 0, checked_rows = 0;

  // ---------------- scoreboard ----------------
  always @(posedge clk) begin
    if (rst_n && c_valid) begin
      if (rd_ptr >= wr_ptr) begin
        errors++;
        $display("[%0t] ERROR: c_valid with no outstanding row", $time);
      end else begin
        for (int j = 0; j < N; j++) begin
          logic signed [ACC_W-1:0] got;
          got = c_out[j];
          if (int'(got) !== exp_mem[rd_ptr][j]) begin
            errors++;
            if (errors < 20)
              $display("[%0t] MISMATCH row %0d col %0d: got %0d exp %0d",
                       $time, rd_ptr, j, int'(got), exp_mem[rd_ptr][j]);
          end
        end
        rd_ptr++;
        checked_rows++;
      end
    end
  end

  // ---------------- helpers ----------------
  // mode 0: full-range random   1: identity (weights only)
  // mode 2: all most-negative   3: corner values {-min, max, -1, 0, 1}
  function automatic int rnd_val(input int mode);
    int c;
    case (mode)
      2:       return -(1 << (DATA_W-1));
      3: begin
           c = $urandom_range(4);
           case (c)
             0: return -(1 << (DATA_W-1));
             1: return  (1 << (DATA_W-1)) - 1;
             2: return -1;
             3: return 0;
             default: return 1;
           endcase
         end
      default: return int'($signed(DATA_W'($urandom)));
    endcase
  endfunction

  task automatic load_weights(input int mode);
    for (int k = 0; k < N; k++)
      for (int j = 0; j < N; j++)
        W_mat[k][j] = (mode == 1) ? ((k == j) ? 1 : 0) : rnd_val(mode);
    for (int k = 0; k < N; k++) begin
      @(posedge clk);
      w_load_en  <= 1'b1;
      w_load_row <= ROW_W'(k);
      for (int j = 0; j < N; j++) w_load_data[j] <= DATA_W'(W_mat[k][j]);
    end
    @(posedge clk);
    w_load_en <= 1'b0;
  endtask

  task automatic stream_rows(input int nrows, input int amode, input int bubble_pct);
    int a_vec [N];
    int issued = 0;
    int acc;
    while (issued < nrows) begin
      @(posedge clk);
      if (int'($urandom_range(99)) >= bubble_pct) begin
        for (int k = 0; k < N; k++) begin
          a_vec[k] = rnd_val(amode);
          a_in[k] <= DATA_W'(a_vec[k]);
        end
        for (int j = 0; j < N; j++) begin
          acc = 0;
          for (int k = 0; k < N; k++) acc += a_vec[k] * W_mat[k][j];
          exp_mem[wr_ptr][j] = acc;
        end
        a_valid <= 1'b1;
        wr_ptr++;
        issued++;
      end else begin
        a_valid <= 1'b0;
        for (int k = 0; k < N; k++) a_in[k] <= DATA_W'($urandom); // garbage while invalid
      end
    end
    @(posedge clk);
    a_valid <= 1'b0;
    repeat (2*N + 4) @(posedge clk);   // drain
  endtask

  task automatic run_test(input string name, input int wmode, input int amode,
                          input int nrows, input int bubble_pct);
    int errs_before = errors;
    wr_ptr = 0; rd_ptr = 0;
    load_weights(wmode);
    stream_rows(nrows, amode, bubble_pct);
    if (rd_ptr != wr_ptr) begin
      errors++;
      $display("ERROR [%s]: expected %0d rows, received %0d", name, wr_ptr, rd_ptr);
    end
    $display("%-28s rows=%4d bubbles=%2d%%  %s", name, nrows, bubble_pct,
             (errors == errs_before) ? "ok" : "FAIL");
  endtask

  // ---------------- main ----------------
  initial begin
    repeat (4) @(posedge clk);
    rst_n <= 1'b1;
    repeat (2) @(posedge clk);

    run_test("identity weights",        1, 0,  64,  0);
    run_test("all -min (overflow case)",2, 2,  64,  0);
    run_test("random back-to-back",     0, 0, 500,  0);
    run_test("random, 50% bubbles",     0, 0, 500, 50);
    run_test("corner values, 30% bub.", 3, 3, 400, 30);
    for (int it = 0; it < 5; it++)
      run_test($sformatf("weight reload #%0d", it), 0, 0, 100, 20);

    $display("----------------------------------------------");
    $display("N=%0d DATA_W=%0d ACC_W=%0d latency=%0d cycles  rows checked: %0d",
             N, DATA_W, ACC_W, 2*N-1, checked_rows);
    if (errors == 0) $display("TB PASS");
    else             $display("TB FAIL (%0d errors)", errors);
    $finish;
  end

  initial begin
    #50_000_000;
    $display("TB FAIL (timeout)");
    $finish;
  end
endmodule
