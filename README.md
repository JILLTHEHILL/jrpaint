# JR Paint

**A mouse-controlled FPGA paint application powered by a custom processor and assembly.**

Created by **Jill Wang and Rachel Yu**. JR Paint runs on a
Nexys A7-100T, using a VGA monitor as the canvas and the board's switches to
select colors, brush sizes, and fill mode.

The processor does the drawing calculations. Verilog and VHDL connect it to the
mouse, memories, display, and audio hardware. There is no desktop application
running the paint logic.

## Features

- Mouse-controlled drawing with a crosshair that scales with the brush size.
- Ten palette colors, with the most recently enabled color switch taking priority.
- Five brush sizes, shown on the seven-segment display.
- Flood fill using an assembly-managed depth-first search stack.
- Right-click undo for drawing strokes and fills, within available memory.
- Canvas clearing from the middle mouse button or the board's center button.
- Recorded color-name audio and an RGB color indicator.

## Controls

| Input | Action |
| --- | --- |
| Mouse movement | Move the cursor |
| Left mouse button, held | Draw with the selected color and brush |
| Right mouse click | Undo the most recent stored operation |
| Middle mouse click or `BTNC` | Clear the canvas to white |
| No color switches enabled | Move the cursor without drawing |
| `SW15` enabled + left click | Fill the connected region under the cursor |

### Color Selection

| Switch | Color | Switch | Color |
| --- | --- | --- | --- |
| `SW0` | White | `SW5` | Green |
| `SW1` | Pink | `SW6` | Blue |
| `SW2` | Red | `SW7` | Purple |
| `SW3` | Orange | `SW8` | Brown |
| `SW4` | Yellow | `SW9` | Black |

When several colors are enabled, the most recently switched-on color wins.
Turning it off returns to the most recently enabled color still on. Changes
detected in the same polling cycle are processed in switch order.

Selecting white paints over existing artwork. Selecting no color disables
painting. Color values come from `colors.mem`; the RGB LED uses the same palette,
but its on/off channels cannot reproduce every shade exactly. It is off for
black and when no color is selected.

### Brush Size

| Switch | Displayed size | Brush footprint in canvas cells |
| --- | --- | --- |
| `SW10` | 0.2 | 1 x 1 |
| `SW11` | 0.4 | 3 x 3 |
| `SW12` | 0.6 | 5 x 5 |
| `SW13` | 0.8 | 7 x 7 |
| `SW14` | 1.0 | 9 x 9 |

The largest enabled size wins; with all size switches off, the default is 0.2.
These are size labels, not physical measurements. Brushes are clipped at the
canvas edges.

## Architecture

```text
Mouse -> PS/2 interface -> Mouse packet decoder -> MMIO registers
Switches / BTNC --------------------------------> MMIO registers
                                                        |
                                           Custom processor + assembly
                                             /                    \
                                     Canvas RAM              Output registers
                                          |                 /       |       \
VGA timing -> Canvas/sprite addressing -> Palette + cursor   LED   Display   Audio ROM
                                          |                                  |
                                      VGA monitor                       PWM audio
```

The canvas stores **80 x 60 four-bit color indices**, displayed as 8 x 8 pixel
cells in a **640 x 480 VGA image**. The cursor is a separate sprite overlay, so
moving it does not modify the artwork. A Clock Wizard converts the board's
100 MHz clock to 25 MHz for the processor and video path.

**Assembly** reads mouse movement and buttons through memory-mapped I/O (MMIO),
updates and clamps the cursor position, handles color-selection order and brush
size, and performs painting, fill, undo, and clear operations. The current color
selection uses per-switch timestamps; fill and undo use stacks in processor RAM.

**Hardware** handles PS/2 serial transfers, mouse packet decoding, memory access,
VGA timing and cursor overlay, palette lookup, seven-segment multiplexing, and
audio playback. The mouse decoder and audio controller are modules inside
`FinalProjectJRPaint.v`, not separate missing files.

## Repository Layout

```text
final_project_vga_files/
  FinalProjectJRPaint.v            Top-level integration, mouse decoder, audio
  VGATimingGenerator.v            VGA timing
  Ps2Interface.vhd                 Bidirectional PS/2 interface
  constraints.xdc                 Board pins and input clock constraint
  finalprojectJRPaint_assembly.s   Paint application source
  finalprojectJRPaint_assembly.mem Assembled instruction ROM
  colors.mem / cursor.mem         Palette and crosshair sprite
  color_audio.mem                 Packed audio samples
  color_audio_table.vh            Audio offsets and lengths
  build_color_audio_mem.py        WAV-to-ROM converter
rachel_processor/
  proc/                           Processor, register file, RAM, ROM, ALU
  assembler-python-version/       Custom ISA assembler
lab9_kit/PWMSerializer.v           Audio PWM serializer
sound_effects/                    Ten recorded source WAV files
vivado/
  create_project.tcl              Recreate the Vivado project
  ip/clk_wiz_0/clk_wiz_0.xci       Original Clock Wizard configuration
```

Only the JR Paint design and its dependencies are included. Older top-level
designs, duplicate processor trees, Vivado run outputs, compiled simulations,
archives, and machine-specific project files are intentionally excluded.

## Build and Run

### Requirements

- Nexys A7-100T (`xc7a100tcsg324-1`). These constraints are board-specific.
- VGA monitor and cable, a compatible mouse on the board's USB HID port, and
  headphones or powered speakers for audio.
- AMD Vivado with Artix-7 support. The original project and Clock Wizard
  configuration were saved with **Vivado 2025.2**; use that version to avoid an
  untested IP migration.
- Python **3.9 or newer**, only if regenerating assembly or audio. The included
  Python tools use the standard library and need no pip packages.

### Create the Vivado Project

From this repository's root, in a terminal with Vivado available:

```sh
vivado -mode batch -source vivado/create_project.tcl
```

Alternatively, close any open project in Vivado, then select **Tools > Run Tcl
Script** and choose `vivado/create_project.tcl`.

The script creates `build/JRPaint/JRPaint.xpr`, imports the Clock Wizard into
that build directory, and adds the required HDL, header, memory files, and
constraints. IP import copies the configuration into the new project rather
than editing the checked-in configuration. See the
[AMD command reference](https://docs.amd.com/r/2020.2-English/ug835-vivado-tcl-commands/import_ip).

Open the generated project, confirm the top is **`FinalProjectJRPaint`**, then
run synthesis, implementation, and bitstream generation. Check timing and design
rule reports before programming the board through Hardware Manager. The project
script does not run these stages automatically.

To revisit an existing build, open its `.xpr` instead of rerunning the script.
Keep all four `.mem` files registered as design sources and the `.vh` file in the
include path. Do not add another `RAM.v`, another processor tree, or an old top
module from the development project.

### Reassemble the Program

The checked-in `.mem` is ready to use. After editing the assembly, regenerate it
with the included custom assembler, **not a standard MIPS assembler**:

```sh
python3 rachel_processor/assembler-python-version/assemble.py final_project_vga_files/finalprojectJRPaint_assembly.s -o final_project_vga_files/finalprojectJRPaint_assembly.mem
```

The output contains 4,096 lines of 32-bit binary instructions, including padding.
Rebuild the bitstream after changing an initialization file.

### Regenerate Audio

Keep the ten color-named WAV files in `sound_effects/`, then run:

```sh
python3 final_project_vga_files/build_color_audio_mem.py
```

This converts uncompressed mono or stereo PCM WAVs into normalized, unsigned
8-bit samples at 8 kHz. It updates both `color_audio.mem` and
`color_audio_table.vh`; keep them together when rebuilding the FPGA design.

## Status and Limits

This is a source-only snapshot of the existing project, not a new hardware
release. HDL, assembly, constraints, assets, and IP configuration are preserved
from the development copy. Packaging does not fix or certify its behavior.

Packaging checks confirmed that reassembling the program and regenerating audio
reproduce the included files byte for byte, and all 60 top-level port bits have
pin and I/O-standard constraints. Verilog elaboration passed with temporary
interface-only placeholders for the Clock Wizard and VHDL PS/2 module; it did
not simulate those components. The project script passed a Tcl dry run from a
relocated folder, not an actual Vivado run.

The latest reported mouse-input and cursor-display issues have not been resolved
or retested as part of this cleanup. A fresh Vivado build and board test are
required; no prebuilt bitstream or claim of timing closure is included.

Undo history and fill workspace are bounded by the 4,096-word processor RAM.
The canvas is cell-based rather than individually addressable at full VGA
resolution. Artwork is volatile and is not saved or exported.

For a board smoke test, check cursor motion with no color selected, drawing with
every color and size, color priority, fill inside and outside an outline, undo,
clear, screen edges, and color-name audio.

## Credits

JR Paint was developed by Jill Wang and Rachel Yu. The project integrates
Rachel's processor, the course-provided custom assembler and Lab 9 PWM
serializer, and Digilent's PS/2 interface. Existing source attribution and
copyright notices are retained; no new blanket license is assigned to inherited
course or vendor code.
