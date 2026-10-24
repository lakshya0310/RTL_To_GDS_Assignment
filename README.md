# 4-bit array multiplier: RTL to GDSII

Name: Sai Ritvik Uppuganti   Roll number: 2025122012
Name: Lakshya Jindal   Roll number: 2023112017

Tools:
- IIC-OSIC-TOOLS (Docker)
- iverilog 14.0 (devel)
- Yosys 0.69 (git 9f75ca1f9)
- OpenSTA 3.1.0
- Liberty file: sky130_fd_sc_hd__tt_025C_1v80.lib

## Part A: RTL Design and Verification (run from repo root, inside the container)
```
iverilog -g2012 -o sim tb/tb_mult.v rtl/full_adder.v rtl/mult_array.v
vvp sim
gtkwave mult.vcd
```
Result: `PASS: 256 vectors checked, 0 errors`.

Error test (Task 6): `sum` in `rtl/full_adder.v` was temporarily changed to `a ^ b`, the same three commands were run to get the FAIL line, and the change was then undone.
Result: `FAIL: 256 vectors checked, 95 errors`.

## Part B: Logic Synthesis
```
yosys -c synth/synth.tcl | tee synth/yosys.log
```
Outputs: `synth/mult_array_stat.rpt` and `synth/mult_array_netlist.v`.

Predictions (before running synthesis):
- flops: 16 (dfrtp_1), flop area: 400.384 um^2
- logic cells: more than 28, because each full adder needs at least 2 cells
- most common gate: AND/NAND, since each full adder has 3 and there are 16 more partial product ANDs

Results:

| Item | Value |
|---|---|
| Total cells | 68 |
| Flops (dfrtp_1) | 16 |
| Logic cells (total - flops) | 52 |
| Total area | 758.2272 um^2 |
| Flop area | 400.384 um^2 |
| Flop share | 52.805 % |
| Top 3 cell types by count | dfrtp_1 (16), nand2_1 (13), a21oi_1 (4) |

Notes:
- The log says `mapped 16 $_DFF_PN0_ cells to dfrtp_1`.
- Logic cells are 52 against 28, which is 24 more. ABC only uses single-output cells, so each full adder needs at least 2.
- The most common gate is nand2_1 (13). All XOR types add up to 8.
- ABC skips multi-output cells, so there are zero fa cells.
- `$scopeinfo` is not a real cell. There is one per adder in the generic stats and zero in the final netlist.
- The 16 flops are 16 of the 68 cells but 52.81 % of the area. A dfrtp_1 is 25.024 um^2 (20 sites), while a nand2_1 is 3.754 um^2 (3 sites).
- Site check: one site is 0.46 x 2.72 = 1.2512 um^2. For nand2_1, 48.797 / 13 = 3.7536 and 3.7536 / 1.2512 = 3.0.

Gate-level simulation:

```
CELLS=$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/verilog
iverilog -g2012 -DFUNCTIONAL -DUNIT_DELAY=#1 -o gls tb/tb_mult.v $CELLS/primitives.v $CELLS/sky130_fd_sc_hd.v synth/mult_array_netlist.v
vvp gls
```
Result: PASS: 256 vectors checked, 0 errors

### Part C: Timing Analysis

**Commands used:**
`sta sta/sta.tcl` (Report from this kept for final deliverable)
`T=5.0 sta sta/sta.tcl`
`T=2.75 sta sta/sta.tcl`

| Metric | Value |
| :--- | :--- |
| Worst slack at 10 ns | 7.25 ns |
| T-min | 2.75 ns |
| F-max | 363.64 MHz |
| Slack at T-min (2.75 ns) | 0.00 ns |
| Start point | `_104_` |
| End point | `_102_` |
| Number of cells on path | 8 |
| Latency (2 × T-min) | 5.50 ns |
| Throughput | 363.64 million results/sec |


## Part D: Physical Design (RTL to GDSII)

### Run History & Clock Period Tuning (Task 1)
The guide requires setup__ws >= 0 (setup__ws is the worst slack over all corners), so every attempt is recorded below, each 0.5 ns longer than the last, until it was met:
1. `RUN_2026-10-20_19-43-23` (CLOCK_PERIOD = 3.5 ns): setup__ws = -1.8011 ns | nom_tt_ws = 0.6167 ns
2. `RUN_2026-10-20_19-53-01` (CLOCK_PERIOD = 4.0 ns): setup__ws = -1.3195 ns | nom_tt_ws = 1.1132 ns
3. `RUN_2026-10-20_19-58-42` (CLOCK_PERIOD = 4.5 ns): setup__ws = -0.8192 ns | nom_tt_ws = 1.6134 ns
4. `RUN_2026-10-20_20-04-21` (CLOCK_PERIOD = 5.0 ns): setup__ws = -0.3192 ns | nom_tt_ws = 2.1134 ns
5. `RUN_2026-10-20_20-10-04` (CLOCK_PERIOD = 5.5 ns): setup__ws = -0.0712 ns | nom_tt_ws = 2.4658 ns
6. `RUN_2026-10-20_20-17-27` (CLOCK_PERIOD = 6.0 ns): setup__ws = -0.0443 ns | nom_tt_ws = 2.7877 ns (still negative in the slow corner, so not accepted)
7. `RERUN_6p5_b` (CLOCK_PERIOD = 6.5 ns): setup__ws = -0.0347 ns | nom_tt_ws = 3.3395 ns (1 setup violation, slow corner)
8. `RERUN_7p0` (CLOCK_PERIOD = 7.0 ns): setup__ws = +0.4653 ns | nom_tt_ws = 3.8395 ns (Final Passing Run: 0 setup violations, 0 hold violations, 0 DRC, 0 LVS)

Note: a first 6.5 ns attempt (`RERUN_6p5`) stopped at the KLayout XOR step because `klayout` was not on the PATH; it was repeated as `RERUN_6p5_b` and is not counted as a timing attempt.

Runs 7 and 8 produce the same layout (1883 instances, 2333 um wirelength) and differ only in the clock period, so their slacks differ by exactly 0.5 ns. Run 6 gave a different layout (4821 instances, 3017 um wirelength), and its metrics.json and GDS were replaced by those of run 8.

**Commands used (in order):**
```bash
cd pnr
librelane --pdk-root "$PDK_ROOT" config.json                       # runs 1 to 6, CLOCK_PERIOD edited by hand each time
librelane --manual-pdk --pdk-root "$PDK_ROOT" --pdk sky130A --run-tag RERUN_6p5_b config.json   # run 7
librelane --manual-pdk --pdk-root "$PDK_ROOT" --pdk sky130A --run-tag RERUN_7p0 config.json     # run 8

# Copy final deliverables (from the passing run)
cp runs/RERUN_7p0/final/metrics.json ./metrics.json
cp runs/RERUN_7p0/final/gds/mult_array.gds ./mult_array.gds

# View layout in KLayout
klayout mult_array.gds
```

## Extras (kept outside this repository)
Optional extra analyses were run with scripts and reports kept in a folder named `extras`, next to this repository and not inside it, so that the repository keeps the required file architecture. They were synthesis without `-flatten` and extra timing reports (hold, detailed path, input paths and output paths). Both are run from the repository root:
```
yosys -c ../extras/synth/synth_noflat.tcl
sta ../extras/sta/sta_extras.tcl
```
