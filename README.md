# MACforge-ASIC: N x N weight-stationary systolic array (SystemVerilog)

Parameterized int8 matrix-multiply array computing `C = A * W`, written for an
ASIC flow (no vendor primitives, plain synthesizable RTL).

## Architecture
- **PE** (`rtl/pe.sv`): holds one weight; each cycle `psum_out <= psum_in + a_in*w`, `a_out <= a_in`.
- **Array** (`rtl/systolic_array.sv`): N x N PEs. Activations flow west->east, partial sums north->south.
- **Input skew:** row k delayed k cycles so each wavefront meets the right partial sum.
- **Output deskew:** column j delayed N-1-j cycles so a full result row appears at once.
- **Valid pipeline:** `c_valid` follows `a_valid` with the same latency.
- **Accumulator width:** `2*DATA_W + clog2(N)` bits = exact no-overflow bound (19 b for int8, N=8).
- **Idle gating:** inputs are zeroed when `a_valid=0` to reduce toggling.

### Interface
| Port | Meaning |
|---|---|
| `w_load_en, w_load_row, w_load_data[N]` | Write row `w_load_row` of W (N weights/cycle). Load only while idle. |
| `a_valid, a_in[N]` | One row vector of A per cycle. |
| `c_valid, c_out[N]` | One row vector of C per cycle. `c_out[j] = sum_k A[k]*W[k][j]`. |

### Timing
- Latency: **2N-1 cycles** from `a_valid` to `c_valid`.
- Throughput: 1 row vector/cycle, back-to-back.
- Compute: N^2 MACs/cycle at steady state.

## Run simulation
```
make sim N=8        # Verilator
make sim_iv N=4     # Icarus Verilog
make sweep          # N = 1,2,3,4,8,16
```
Testbench (`tb/tb_systolic_array.sv`) checks every output row against an inline
integer golden model. Tests: identity weights, all -128 (worst-case overflow),
random back-to-back, random with 50% bubbles + garbage on invalid inputs,
corner values, and repeated weight reloads.

Verified: Verilator, N = 1, 2, 3, 4, 8, 16 pass; Icarus N=4 passes. Deliberately
breaking the output deskew or making the multiply unsigned makes the TB fail,
so the checks are not vacuous.

## ASIC flow (Cadence)
`scripts/genus/synth.tcl`, `scripts/innovus/pnr.tcl`, `constraints/systolic_array.sdc`
are **untested templates**: they were written without Cadence access. Expect to
fix library paths, power-grid layers, and some command names for your
tool version and PDK. Set N/DATA_W via the defaults in `rtl/systolic_array.sv`.

## Results (fill in)
| N | Period (ns) | WNS (ns) | Area (um^2) | Power (mW) | Utilization | Notes |
|---|---|---|---|---|---|---|
| 4 | | | | | | |
| 8 | | | | | | |

## Ideas to extend (interview material)
- Pipeline the multiplier (needs skew/latency rework) and plot Fmax vs. area.
- Remove reset from datapath flops; measure area savings.
- Narrow psum width per row (partial sums need fewer bits near the top).
- Output-stationary variant; compare area/utilization.
- Weight double-buffering to overlap load with compute.
- Clock gating of idle PEs; compare power.
- Add scan/DFT and report coverage.
