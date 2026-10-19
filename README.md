# 4-bit array multiplier: RTL to GDSII

Tools: IIC-OSIC-TOOLS (Docker)
iverilog 14.0 (devel)
Yosys 0.69 (git 9f75ca1f9)
OpenSTA 3.1.0
Liberty file: sky130_fd_sc_hd__tt_025C_1v80.lib

## Part B (run from repo root, inside the container)
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
