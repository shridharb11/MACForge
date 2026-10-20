// Processing element: weight-stationary MAC.
//   a_out    <= a_in                      (activation moves east)
//   psum_out <= psum_in + a_in * w        (partial sum moves south)
// Weight is held in w_q and only changes when w_load is asserted.
module pe #(
  parameter int DATA_W = 8,
  parameter int ACC_W  = 19
) (
  input  logic                      clk,
  input  logic                      rst_n,
  input  logic                      w_load,
  input  logic signed [DATA_W-1:0]  w_in,
  input  logic signed [DATA_W-1:0]  a_in,
  input  logic signed [ACC_W-1:0]   psum_in,
  output logic signed [DATA_W-1:0]  a_out,
  output logic signed [ACC_W-1:0]   psum_out
);
  logic signed [DATA_W-1:0]   w_q;
  logic signed [2*DATA_W-1:0] prod;

  assign prod = a_in * w_q;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      w_q      <= '0;
      a_out    <= '0;
      psum_out <= '0;
    end else begin
      if (w_load) w_q <= w_in;
      a_out    <= a_in;
      psum_out <= psum_in + ACC_W'(prod);
    end
  end
endmodule
