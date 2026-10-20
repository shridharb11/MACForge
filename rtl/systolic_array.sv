// N x N weight-stationary systolic array computing C = A * W.
//   W : N x N, loaded once (row-addressed), stays inside the PEs.
//   A : stream of N-element row vectors, one per cycle (a_valid qualifies).
//   C : stream of N-element result rows; c_out[j] = sum_k A[k] * W[k][j].
//
// Dataflow: activations flow west->east, partial sums north->south.
// Row k of the array sees its activation delayed by k cycles (input skew).
// Column j emerges delayed by j cycles, so it is delayed by (N-1-j) more
// (output deskew) to present a whole result row in one cycle.
//
// Latency   : a_valid at cycle m  ->  c_valid/c_out at cycle m + 2N - 1.
// Throughput: one row vector per cycle (fully pipelined, back-to-back OK).
// Load weights only while the array is idle (no in-flight rows).
module systolic_array #(
  parameter int N      = 8,
  parameter int DATA_W = 8,
  parameter int ACC_W  = 2*DATA_W + $clog2(N)  // exact worst case for an N-term signed dot product
) (
  input  logic                                  clk,
  input  logic                                  rst_n,

  // weight load: write one row of W per cycle, W[w_load_row][0..N-1]
  input  logic                                  w_load_en,
  input  logic [(N>1 ? $clog2(N) : 1)-1:0]      w_load_row,
  input  logic [N-1:0][DATA_W-1:0]              w_load_data,

  // activation input (one row vector of A per cycle)
  input  logic                                  a_valid,
  input  logic [N-1:0][DATA_W-1:0]              a_in,

  // result output (one row vector of C per cycle)
  output logic                                  c_valid,
  output logic [N-1:0][ACC_W-1:0]               c_out
);
  localparam int ROW_W = (N > 1) ? $clog2(N) : 1;
  localparam int LAT   = 2*N - 1;

  // a_w[k][j]  : activation entering PE(k,j);  a_w[k][N] leaves the array (unused)
  // ps_v[k][j] : partial sum entering PE(k,j); ps_v[N][j] is the array output
  logic signed [DATA_W-1:0] a_w  [N][N+1];
  logic signed [ACC_W-1:0]  ps_v [N+1][N];

  // ---------------- input skew (row k delayed k cycles) ----------------
  for (genvar k = 0; k < N; k++) begin : g_in_skew
    logic signed [DATA_W-1:0] a_gated;
    // gate to zero when invalid: cuts switching activity, keeps bubbles harmless
    assign a_gated = a_valid ? a_in[k] : '0;

    if (k == 0) begin : g_nodelay
      assign a_w[k][0] = a_gated;
    end else begin : g_delay
      logic signed [DATA_W-1:0] sr [k];
      always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
          for (int s = 0; s < k; s++) sr[s] <= '0;
        end else begin
          sr[0] <= a_gated;
          for (int s = 1; s < k; s++) sr[s] <= sr[s-1];
        end
      end
      assign a_w[k][0] = sr[k-1];
    end
  end

  // ---------------- PE grid ----------------
  for (genvar j = 0; j < N; j++) begin : g_top
    assign ps_v[0][j] = '0;
  end

  for (genvar k = 0; k < N; k++) begin : g_row
    for (genvar j = 0; j < N; j++) begin : g_col
      pe #(.DATA_W(DATA_W), .ACC_W(ACC_W)) u_pe (
        .clk      (clk),
        .rst_n    (rst_n),
        .w_load   (w_load_en && (w_load_row == ROW_W'(k))),
        .w_in     (w_load_data[j]),
        .a_in     (a_w[k][j]),
        .psum_in  (ps_v[k][j]),
        .a_out    (a_w[k][j+1]),
        .psum_out (ps_v[k+1][j])
      );
    end
  end

  // ---------------- output deskew (column j delayed N-1-j cycles) ----------------
  for (genvar j = 0; j < N; j++) begin : g_out_deskew
    localparam int D = N - 1 - j;
    if (D == 0) begin : g_nodelay
      assign c_out[j] = ps_v[N][j];
    end else begin : g_delay
      logic signed [ACC_W-1:0] sr [D];
      always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
          for (int s = 0; s < D; s++) sr[s] <= '0;
        end else begin
          sr[0] <= ps_v[N][j];
          for (int s = 1; s < D; s++) sr[s] <= sr[s-1];
        end
      end
      assign c_out[j] = sr[D-1];
    end
  end

  // ---------------- valid pipeline ----------------
  logic [LAT-1:0] v_pipe;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) v_pipe <= '0;
    else begin
      v_pipe[0] <= a_valid;
      for (int i = 1; i < LAT; i++) v_pipe[i] <= v_pipe[i-1];
    end
  end
  assign c_valid = v_pipe[LAT-1];
endmodule
