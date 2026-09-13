main:
    # Startup state and fixed MMIO pointers.
    addi $s0, $0, 40        # cursor x cell
    addi $s1, $0, 30        # cursor y cell
    addi $s2, $0, 2440      # linear cell index
    addi $s3, $0, 0         # last frame toggle
    addi $s4, $0, 8192      # canvas MMIO base
    addi $s5, $0, 0         # pending mouse x delta
    addi $s6, $0, 0         # pending mouse y delta
    addi $s7, $0, 0         # current mouse buttons
    addi $t0, $0, 4099      # mouse packet MMIO
    addi $t1, $0, 4100      # frame toggle MMIO
    addi $t2, $0, 0         # active draw color
    addi $t3, $0, 80        # cells per row
    addi $t8, $0, 4800      # total canvas cells
    addi $t9, $0, 0         # previous mouse buttons
    addi $a3, $0, 4101      # cursor x MMIO, y is 1($a3)
    addi $ra, $0, 4106      # pen size MMIO
    addi $k0, $0, 1         # current pen size
    addi $gp, $0, 59        # largest valid y
    addi $sp, $0, 79        # largest valid x
    addi $fp, $0, 1264      # undo stack top

    sw $s0, 0($a3)
    sw $s1, 1($a3)
    addi $a0, $0, 4105
    sw $t2, 0($a0)
    sw $k0, 0($ra)

loop_wait:
    lw $a0, 0($t0)
    bne $a0, $0, frame_ready
    lw $a0, 0($t1)
    bne $a0, $s3, frame_ready
    j loop_wait

frame_ready:
    lw $a0, 0($t1)
    add $s3, $a0, $0
    addi $gp, $0, 59
    addi $sp, $0, 79
    addi $t7, $0, 4103
    lw $a0, 0($t7)
    bne $a0, $0, do_clear

    addi $a1, $0, 4104
    addi $a2, $0, 4105
    lw $a0, 0($a1)
    addi $v0, $0, 1023
    and $t6, $a0, $v0
    lw $t4, 0($0)
    lw $t5, 1($0)

    addi $v0, $0, 1
    and $v1, $t6, $v0
    bne $v1, $0, white_rise_prev
    j pink_rise
white_rise_prev:
    and $k1, $t4, $v0
    bne $k1, $0, pink_rise
    addi $t5, $t5, 1
    sw $t5, 2($0)

pink_rise:
    addi $v0, $0, 2
    and $v1, $t6, $v0
    bne $v1, $0, pink_rise_prev
    j red_rise
pink_rise_prev:
    and $k1, $t4, $v0
    bne $k1, $0, red_rise
    addi $t5, $t5, 1
    sw $t5, 3($0)

red_rise:
    addi $v0, $0, 4
    and $v1, $t6, $v0
    bne $v1, $0, red_rise_prev
    j orange_rise
red_rise_prev:
    and $k1, $t4, $v0
    bne $k1, $0, orange_rise
    addi $t5, $t5, 1
    sw $t5, 4($0)

orange_rise:
    addi $v0, $0, 8
    and $v1, $t6, $v0
    bne $v1, $0, orange_rise_prev
    j yellow_rise
orange_rise_prev:
    and $k1, $t4, $v0
    bne $k1, $0, yellow_rise
    addi $t5, $t5, 1
    sw $t5, 5($0)

yellow_rise:
    addi $v0, $0, 16
    and $v1, $t6, $v0
    bne $v1, $0, yellow_rise_prev
    j green_rise
yellow_rise_prev:
    and $k1, $t4, $v0
    bne $k1, $0, green_rise
    addi $t5, $t5, 1
    sw $t5, 6($0)

green_rise:
    addi $v0, $0, 32
    and $v1, $t6, $v0
    bne $v1, $0, green_rise_prev
    j blue_rise
green_rise_prev:
    and $k1, $t4, $v0
    bne $k1, $0, blue_rise
    addi $t5, $t5, 1
    sw $t5, 7($0)

blue_rise:
    addi $v0, $0, 64
    and $v1, $t6, $v0
    bne $v1, $0, blue_rise_prev
    j purple_rise
blue_rise_prev:
    and $k1, $t4, $v0
    bne $k1, $0, purple_rise
    addi $t5, $t5, 1
    sw $t5, 8($0)

purple_rise:
    addi $v0, $0, 128
    and $v1, $t6, $v0
    bne $v1, $0, purple_rise_prev
    j brown_rise
purple_rise_prev:
    and $k1, $t4, $v0
    bne $k1, $0, brown_rise
    addi $t5, $t5, 1
    sw $t5, 9($0)

brown_rise:
    addi $v0, $0, 256
    and $v1, $t6, $v0
    bne $v1, $0, brown_rise_prev
    j black_rise
brown_rise_prev:
    and $k1, $t4, $v0
    bne $k1, $0, black_rise
    addi $t5, $t5, 1
    sw $t5, 10($0)

black_rise:
    addi $v0, $0, 512
    and $v1, $t6, $v0
    bne $v1, $0, black_rise_prev
    j choose_color
black_rise_prev:
    and $k1, $t4, $v0
    bne $k1, $0, choose_color
    addi $t5, $t5, 1
    sw $t5, 11($0)

choose_color:
    sw $t6, 0($0)
    sw $t5, 1($0)
    addi $t2, $0, 0
    addi $k1, $0, 0

    addi $v0, $0, 1
    and $v1, $t6, $v0
    bne $v1, $0, white_pick_check
    j pink_pick
white_pick_check:
    lw $v0, 2($0)
    blt $k1, $v0, white_pick_set
    j pink_pick
white_pick_set:
    add $k1, $v0, $0
    addi $t2, $0, 1

pink_pick:
    addi $v0, $0, 2
    and $v1, $t6, $v0
    bne $v1, $0, pink_pick_check
    j red_pick
pink_pick_check:
    lw $v0, 3($0)
    blt $k1, $v0, pink_pick_set
    j red_pick
pink_pick_set:
    add $k1, $v0, $0
    addi $t2, $0, 2

red_pick:
    addi $v0, $0, 4
    and $v1, $t6, $v0
    bne $v1, $0, red_pick_check
    j orange_pick
red_pick_check:
    lw $v0, 4($0)
    blt $k1, $v0, red_pick_set
    j orange_pick
red_pick_set:
    add $k1, $v0, $0
    addi $t2, $0, 3

orange_pick:
    addi $v0, $0, 8
    and $v1, $t6, $v0
    bne $v1, $0, orange_pick_check
    j yellow_pick
orange_pick_check:
    lw $v0, 5($0)
    blt $k1, $v0, orange_pick_set
    j yellow_pick
orange_pick_set:
    add $k1, $v0, $0
    addi $t2, $0, 4

yellow_pick:
    addi $v0, $0, 16
    and $v1, $t6, $v0
    bne $v1, $0, yellow_pick_check
    j green_pick
yellow_pick_check:
    lw $v0, 6($0)
    blt $k1, $v0, yellow_pick_set
    j green_pick
yellow_pick_set:
    add $k1, $v0, $0
    addi $t2, $0, 5

green_pick:
    addi $v0, $0, 32
    and $v1, $t6, $v0
    bne $v1, $0, green_pick_check
    j blue_pick
green_pick_check:
    lw $v0, 7($0)
    blt $k1, $v0, green_pick_set
    j blue_pick
green_pick_set:
    add $k1, $v0, $0
    addi $t2, $0, 6

blue_pick:
    addi $v0, $0, 64
    and $v1, $t6, $v0
    bne $v1, $0, blue_pick_check
    j purple_pick
blue_pick_check:
    lw $v0, 8($0)
    blt $k1, $v0, blue_pick_set
    j purple_pick
blue_pick_set:
    add $k1, $v0, $0
    addi $t2, $0, 7

purple_pick:
    addi $v0, $0, 128
    and $v1, $t6, $v0
    bne $v1, $0, purple_pick_check
    j brown_pick
purple_pick_check:
    lw $v0, 9($0)
    blt $k1, $v0, purple_pick_set
    j brown_pick
purple_pick_set:
    add $k1, $v0, $0
    addi $t2, $0, 8

brown_pick:
    addi $v0, $0, 256
    and $v1, $t6, $v0
    bne $v1, $0, brown_pick_check
    j black_pick
brown_pick_check:
    lw $v0, 10($0)
    blt $k1, $v0, brown_pick_set
    j black_pick
brown_pick_set:
    add $k1, $v0, $0
    addi $t2, $0, 9

black_pick:
    addi $v0, $0, 512
    and $v1, $t6, $v0
    bne $v1, $0, black_pick_check
    j color_ready
black_pick_check:
    lw $v0, 11($0)
    blt $k1, $v0, black_pick_set
    j color_ready
black_pick_set:
    addi $t2, $0, 10

color_ready:
    addi $k0, $0, 1

    addi $v0, $0, 16384
    and $v1, $a0, $v0
    bne $v1, $0, set_size_1

    addi $v0, $0, 8192
    and $v1, $a0, $v0
    bne $v1, $0, set_size_08

    addi $v0, $0, 4096
    and $v1, $a0, $v0
    bne $v1, $0, set_size_06

    addi $v0, $0, 2048
    and $v1, $a0, $v0
    bne $v1, $0, set_size_04

    addi $v0, $0, 1024
    and $v1, $a0, $v0
    bne $v1, $0, set_size_02
    j pen_ready

set_size_02:
    addi $k0, $0, 1
    j pen_ready

set_size_04:
    addi $k0, $0, 2
    j pen_ready

set_size_06:
    addi $k0, $0, 3
    j pen_ready

set_size_08:
    addi $k0, $0, 4
    j pen_ready

set_size_1:
    addi $k0, $0, 5

pen_ready:
    sw $t2, 0($a2)
    sw $k0, 0($ra)

    addi $t4, $0, 0
    addi $t5, $0, 0
    addi $a1, $0, 0
    addi $t7, $0, 0
    addi $v0, $0, -32768
    and $v1, $a0, $v0
    bne $v1, $0, fill_mode_on
    j fill_mode_ready

fill_mode_on:
    addi $t7, $0, 1

fill_mode_ready:

    lw $a0, 0($t0)
    bne $a0, $0, have_mouse
    addi $a0, $0, 4098
    lw $s7, 0($a0)
    j post_mouse

have_mouse:
    addi $a0, $0, 4096
    lw $v0, 0($a0)
    add $s5, $s5, $v0
    addi $a0, $0, 4097
    lw $v1, 0($a0)
    add $s6, $s6, $v1
    addi $a0, $0, 4098
    lw $s7, 0($a0)
    sw $0, 0($t0)

post_mouse:
    addi $v0, $0, 4
    and $v1, $s7, $v0
    bne $v1, $0, do_clear

    addi $v0, $0, 2
    and $v1, $s7, $v0
    bne $v1, $0, maybe_undo
    j maybe_left

maybe_undo:
    and $a0, $t9, $v0
    bne $a0, $0, maybe_left
    addi $a0, $0, 1
    and $a0, $s7, $a0
    bne $a0, $0, maybe_left
    j do_undo

maybe_left:
    addi $v0, $0, 1
    and $v1, $s7, $v0
    bne $v1, $0, left_with_button
    j move_up_check

left_with_button:
    bne $t2, $0, left_with_color
    j move_up_check

left_with_color:
    bne $t7, $0, left_fill_mode
    addi $t5, $0, 1
    and $a0, $t9, $v0
    bne $a0, $0, move_up_check
    addi $a0, $0, 4096
    blt $fp, $a0, start_stroke_ok
    addi $t5, $0, 0
    j move_up_check

start_stroke_ok:
    addi $a0, $0, -1
    sw $a0, 0($fp)
    addi $fp, $fp, 1
    addi $t4, $0, 1
    j move_up_check

left_fill_mode:
    and $a0, $t9, $v0
    bne $a0, $0, move_up_check
    addi $a1, $0, 1

move_up_check:
    addi $a0, $0, 19
    blt $a0, $s6, try_up
    j move_down_check

try_up:
    bne $s1, $0, do_up
    j move_down_check

do_up:
    addi $s1, $s1, -1
    sub $s2, $s2, $t3
    addi $s6, $s6, -20
    addi $t4, $0, 1
    j move_up_check

move_down_check:
    addi $a0, $0, -19
    blt $s6, $a0, try_down
    j move_right_check

try_down:
    blt $s1, $gp, do_down
    j move_right_check

do_down:
    addi $s1, $s1, 1
    add $s2, $s2, $t3
    addi $s6, $s6, 20
    addi $t4, $0, 1
    j move_down_check

move_right_check:
    addi $a0, $0, 19
    blt $a0, $s5, try_right
    j move_left_check

try_right:
    blt $s0, $sp, do_right
    j move_left_check

do_right:
    addi $s0, $s0, 1
    addi $s2, $s2, 1
    addi $s5, $s5, -20
    addi $t4, $0, 1
    j move_right_check

move_left_check:
    addi $a0, $0, -19
    blt $s5, $a0, try_left
    j after_moves

try_left:
    bne $s0, $0, do_left
    j after_moves

do_left:
    addi $s0, $s0, -1
    addi $s2, $s2, -1
    addi $s5, $s5, 20
    addi $t4, $0, 1
    j move_left_check

after_moves:
    add $t9, $s7, $0
    bne $a1, $0, do_fill
    bne $t4, $0, do_paint
    j loop_wait

do_paint:
    sw $s0, 0($a3)
    sw $s1, 1($a3)
    bne $t5, $0, paint_cell
    j loop_wait

paint_cell:
    addi $k1, $k0, -1
    addi $v0, $s1, 0
    sub $v0, $v0, $k1
    addi $v1, $s1, 0
    add $v1, $v1, $k1
    addi $a0, $s2, 0
    sub $a0, $a0, $k1
    addi $a1, $k1, 0

prep_row:
    bne $a1, $0, prep_row_step
    j row_loop

prep_row_step:
    sub $a0, $a0, $t3
    addi $a1, $a1, -1
    j prep_row

row_loop:
    blt $v0, $0, next_row
    addi $a1, $0, 60
    blt $v0, $a1, row_in_range
    j next_row

row_in_range:
    addi $a1, $s0, 0
    sub $a1, $a1, $k1
    addi $a2, $s0, 0
    add $a2, $a2, $k1
    addi $t6, $a0, 0

col_loop:
    blt $a1, $0, skip_cell
    blt $a1, $t3, write_cell
    j skip_cell

write_cell:
    addi $t4, $0, 3
    and $t4, $t6, $t4
    sra $t5, $t6, 2
    addi $t7, $0, 64
    add $t5, $t5, $t7
    lw $gp, 0($t5)
    bne $t4, $0, paint_shift1
    add $t7, $gp, $0
    j paint_have_old

paint_shift1:
    addi $sp, $0, 1
    bne $t4, $sp, paint_shift2
    sra $t7, $gp, 8
    j paint_have_old

paint_shift2:
    addi $sp, $0, 2
    bne $t4, $sp, paint_shift3
    sra $t7, $gp, 16
    j paint_have_old

paint_shift3:
    sra $t7, $gp, 24

paint_have_old:
    addi $sp, $0, 15
    and $t7, $t7, $sp
    bne $t7, $t2, paint_maybe_log
    j skip_cell

paint_maybe_log:
    addi $sp, $0, 4096
    blt $fp, $sp, paint_log_ok
    j skip_cell

paint_log_ok:
    sll $sp, $t7, 13
    add $sp, $sp, $t6
    sw $sp, 0($fp)
    addi $fp, $fp, 1
    bne $t4, $0, paint_store1
    sub $gp, $gp, $t7
    add $gp, $gp, $t2
    sw $gp, 0($t5)
    add $t4, $s4, $t6
    sw $t2, 0($t4)
    j skip_cell

paint_store1:
    addi $sp, $0, 1
    bne $t4, $sp, paint_store2
    sll $sp, $t7, 8
    sub $gp, $gp, $sp
    sll $sp, $t2, 8
    add $gp, $gp, $sp
    sw $gp, 0($t5)
    add $t4, $s4, $t6
    sw $t2, 0($t4)
    j skip_cell

paint_store2:
    addi $sp, $0, 2
    bne $t4, $sp, paint_store3
    sll $sp, $t7, 16
    sub $gp, $gp, $sp
    sll $sp, $t2, 16
    add $gp, $gp, $sp
    sw $gp, 0($t5)
    add $t4, $s4, $t6
    sw $t2, 0($t4)
    j skip_cell

paint_store3:
    sll $sp, $t7, 24
    sub $gp, $gp, $sp
    sll $sp, $t2, 24
    add $gp, $gp, $sp
    sw $gp, 0($t5)
    add $t4, $s4, $t6
    sw $t2, 0($t4)

skip_cell:
    addi $a1, $a1, 1
    addi $t6, $t6, 1
    blt $a2, $a1, next_row
    j col_loop

next_row:
    addi $v0, $v0, 1
    add $a0, $a0, $t3
    blt $v1, $v0, loop_wait
    j row_loop

do_fill:
    sw $s0, 0($a3)
    sw $s1, 1($a3)

    addi $t6, $s2, 0
    addi $gp, $0, 3
    and $gp, $t6, $gp
    sra $sp, $t6, 2
    addi $v0, $0, 64
    add $sp, $sp, $v0
    lw $v0, 0($sp)
    bne $gp, $0, fill_target_shift1
    add $k1, $v0, $0
    j fill_target_have

fill_target_shift1:
    addi $v1, $0, 1
    bne $gp, $v1, fill_target_shift2
    sra $k1, $v0, 8
    j fill_target_have

fill_target_shift2:
    addi $v1, $0, 2
    bne $gp, $v1, fill_target_shift3
    sra $k1, $v0, 16
    j fill_target_have

fill_target_shift3:
    sra $k1, $v0, 24

fill_target_have:
    addi $v1, $0, 15
    and $k1, $k1, $v1
    bne $k1, $t2, fill_can_start
    j loop_wait

fill_can_start:
    add $a2, $k1, $0
    sll $v0, $k1, 8
    add $a2, $a2, $v0
    sll $v0, $a2, 16
    add $a2, $a2, $v0
    addi $a0, $0, 64
    addi $a1, $0, 1264

fill_full_scan:
    lw $v0, 0($a0)
    bne $v0, $a2, fill_stack_start
    addi $a0, $a0, 1
    blt $a0, $a1, fill_full_scan

    addi $v0, $0, 4096
    blt $fp, $v0, fill_full_log_ok
    j loop_wait

fill_full_log_ok:
    addi $v0, $0, -2
    sub $v0, $v0, $k1
    sw $v0, 0($fp)
    addi $fp, $fp, 1

    add $a2, $t2, $0
    sll $v0, $t2, 8
    add $a2, $a2, $v0
    sll $v0, $a2, 16
    add $a2, $a2, $v0
    addi $a0, $0, 64
    addi $a1, $0, 1264

fill_full_shadow:
    sw $a2, 0($a0)
    addi $a0, $a0, 1
    blt $a0, $a1, fill_full_shadow

    addi $a0, $0, 0

fill_full_canvas:
    add $v0, $s4, $a0
    sw $t2, 0($v0)
    addi $a0, $a0, 1
    blt $a0, $t8, fill_full_canvas
    j loop_wait

fill_stack_start:
    addi $v0, $0, 4094
    blt $fp, $v0, fill_record_ok
    j loop_wait

fill_record_ok:
    sll $v0, $s0, 13
    add $v0, $v0, $s2
    sw $v0, 0($fp)
    sll $gp, $k1, 4
    addi $sp, $0, 1024
    add $gp, $gp, $sp
    add $gp, $gp, $t2
    sub $gp, $0, $gp
    sw $gp, 1($fp)
    addi $fp, $fp, 2

    addi $a0, $0, 4096
    addi $v0, $a0, -1
    blt $fp, $v0, fill_push_start
    j loop_wait

fill_push_start:
    addi $a0, $a0, -1
    sll $v0, $s0, 13
    add $v0, $v0, $s2
fill_seed_ready:
    sw $v0, 0($a0)

fill_loop_check:
    addi $v0, $0, 4096
    blt $a0, $v0, fill_pop
    j loop_wait

fill_pop:
    lw $v0, 0($a0)
    addi $a0, $a0, 1
    sra $a2, $v0, 13
    sll $v1, $a2, 13
    sub $a1, $v0, $v1

    addi $t6, $0, 3
    and $t6, $a1, $t6
    sra $sp, $a1, 2
    addi $gp, $0, 64
    add $sp, $sp, $gp
    lw $gp, 0($sp)
    bne $t6, $0, fill_cur_shift1
    add $v1, $gp, $0
    j fill_cur_have

fill_cur_shift1:
    addi $v0, $0, 1
    bne $t6, $v0, fill_cur_shift2
    sra $v1, $gp, 8
    j fill_cur_have

fill_cur_shift2:
    addi $v0, $0, 2
    bne $t6, $v0, fill_cur_shift3
    sra $v1, $gp, 16
    j fill_cur_have

fill_cur_shift3:
    sra $v1, $gp, 24

fill_cur_have:
    addi $v0, $0, 255
    and $v1, $v1, $v0
    addi $v0, $0, 15
    blt $v0, $k1, fill_check_tagged
    addi $v0, $0, 15
    and $v1, $v1, $v0
    bne $v1, $k1, fill_loop_check
    j fill_store_pick

fill_check_tagged:
    bne $v1, $k1, fill_loop_check

fill_store_pick:
    addi $v0, $0, 15
    blt $v0, $k1, fill_store_plain
    addi $v0, $t2, 16
    j fill_store_have_color

fill_store_plain:
    addi $v0, $t2, 0

fill_store_have_color:

    bne $t6, $0, fill_store1
    sub $gp, $gp, $v1
    add $gp, $gp, $v0
    sw $gp, 0($sp)
    add $v0, $s4, $a1
    sw $t2, 0($v0)
    j fill_push_neighbors

fill_store1:
    addi $t7, $0, 1
    bne $t6, $t7, fill_store2
    sll $t7, $v1, 8
    sub $gp, $gp, $t7
    sll $t7, $v0, 8
    add $gp, $gp, $t7
    sw $gp, 0($sp)
    add $v0, $s4, $a1
    sw $t2, 0($v0)
    j fill_push_neighbors

fill_store2:
    addi $t7, $0, 2
    bne $t6, $t7, fill_store3
    sll $t7, $v1, 16
    sub $gp, $gp, $t7
    sll $t7, $v0, 16
    add $gp, $gp, $t7
    sw $gp, 0($sp)
    add $v0, $s4, $a1
    sw $t2, 0($v0)
    j fill_push_neighbors

fill_store3:
    sll $t7, $v1, 24
    sub $gp, $gp, $t7
    sll $t7, $v0, 24
    add $gp, $gp, $t7
    sw $gp, 0($sp)
    add $v0, $s4, $a1
    sw $t2, 0($v0)

fill_push_neighbors:
    bne $a2, $0, fill_try_left
    j fill_check_right

fill_try_left:
    addi $v0, $a0, -1
    blt $fp, $v0, fill_push_left
    j fill_check_right

fill_push_left:
    addi $a0, $a0, -1
    addi $v0, $a2, -1
    sll $v0, $v0, 13
    addi $v1, $a1, -1
    add $v0, $v0, $v1
    sw $v0, 0($a0)

fill_check_right:
    addi $v0, $0, 79
    blt $a2, $v0, fill_try_right
    j fill_check_up

fill_try_right:
    addi $v0, $a0, -1
    blt $fp, $v0, fill_push_right
    j fill_check_up

fill_push_right:
    addi $a0, $a0, -1
    addi $v0, $a2, 1
    sll $v0, $v0, 13
    addi $v1, $a1, 1
    add $v0, $v0, $v1
    sw $v0, 0($a0)

fill_check_up:
    blt $a1, $t3, fill_check_down
    addi $v0, $a0, -1
    blt $fp, $v0, fill_push_up
    j fill_check_down

fill_push_up:
    addi $a0, $a0, -1
    sll $v0, $a2, 13
    sub $v1, $a1, $t3
    add $v0, $v0, $v1
    sw $v0, 0($a0)

fill_check_down:
    addi $v0, $0, 4720
    blt $a1, $v0, fill_try_down
    j fill_loop_check

fill_try_down:
    addi $v0, $a0, -1
    blt $fp, $v0, fill_push_down
    j fill_loop_check

fill_push_down:
    addi $a0, $a0, -1
    sll $v0, $a2, 13
    add $v1, $a1, $t3
    add $v0, $v0, $v1
    sw $v0, 0($a0)
    j fill_loop_check

do_undo:
    addi $a0, $0, 1264
    blt $a0, $fp, undo_pop
    add $t9, $s7, $0
    j loop_wait

undo_pop:
    addi $fp, $fp, -1
    lw $a0, 0($fp)
    addi $v0, $0, -257
    blt $a0, $v0, undo_fill_tag
    addi $v0, $0, -1
    bne $a0, $v0, undo_entry
    add $t9, $s7, $0
    j loop_wait

undo_fill_tag:
    add $t9, $s7, $0
    sub $v0, $0, $a0
    addi $v1, $0, 1024
    sub $v0, $v0, $v1
    sra $t2, $v0, 4
    sll $v1, $t2, 4
    sub $k1, $v0, $v1
    addi $v1, $0, 16
    add $k1, $k1, $v1
    addi $fp, $fp, -1
    lw $v0, 0($fp)
    sw $0, 0($fp)
    addi $a0, $0, 4096
    addi $v1, $a0, -1
    blt $fp, $v1, undo_fill_push
    j loop_wait

undo_fill_push:
    addi $a0, $a0, -1
    j fill_seed_ready

undo_entry:
    addi $v0, $0, -1
    blt $a0, $v0, undo_full_screen
    sra $t4, $a0, 13
    addi $v0, $0, 15
    blt $v0, $t4, undo_pop
    sll $t5, $t4, 13
    sub $t6, $a0, $t5
    addi $t5, $0, 3
    and $t5, $t6, $t5
    sra $t7, $t6, 2
    addi $v0, $0, 64
    add $t7, $t7, $v0
    lw $gp, 0($t7)
    bne $t5, $0, undo_shift1
    add $v0, $gp, $0
    j undo_have_cur

undo_shift1:
    addi $v1, $0, 1
    bne $t5, $v1, undo_shift2
    sra $v0, $gp, 8
    j undo_have_cur

undo_shift2:
    addi $v1, $0, 2
    bne $t5, $v1, undo_shift3
    sra $v0, $gp, 16
    j undo_have_cur

undo_shift3:
    sra $v0, $gp, 24

undo_have_cur:
    addi $v1, $0, 255
    and $v0, $v0, $v1
    bne $t5, $0, undo_store1
    sub $gp, $gp, $v0
    add $gp, $gp, $t4
    sw $gp, 0($t7)
    add $v1, $s4, $t6
    sw $t4, 0($v1)
    j undo_pop

undo_store1:
    addi $v1, $0, 1
    bne $t5, $v1, undo_store2
    sll $v1, $v0, 8
    sub $gp, $gp, $v1
    sll $v1, $t4, 8
    add $gp, $gp, $v1
    sw $gp, 0($t7)
    add $v1, $s4, $t6
    sw $t4, 0($v1)
    j undo_pop

undo_store2:
    addi $v1, $0, 2
    bne $t5, $v1, undo_store3
    sll $v1, $v0, 16
    sub $gp, $gp, $v1
    sll $v1, $t4, 16
    add $gp, $gp, $v1
    sw $gp, 0($t7)
    add $v1, $s4, $t6
    sw $t4, 0($v1)
    j undo_pop

undo_store3:
    sll $v1, $v0, 24
    sub $gp, $gp, $v1
    sll $v1, $t4, 24
    add $gp, $gp, $v1
    sw $gp, 0($t7)
    add $v1, $s4, $t6
    sw $t4, 0($v1)
    j undo_pop

undo_full_screen:
    addi $t4, $0, -2
    sub $t4, $t4, $a0
    add $a2, $t4, $0
    sll $v0, $t4, 8
    add $a2, $a2, $v0
    sll $v0, $a2, 16
    add $a2, $a2, $v0
    addi $a0, $0, 64
    addi $a1, $0, 1264

undo_full_shadow:
    sw $a2, 0($a0)
    addi $a0, $a0, 1
    blt $a0, $a1, undo_full_shadow

    addi $a0, $0, 0

undo_full_canvas:
    add $v0, $s4, $a0
    sw $t4, 0($v0)
    addi $a0, $a0, 1
    blt $a0, $t8, undo_full_canvas
    add $t9, $s7, $0
    j loop_wait

do_clear:
    addi $s0, $0, 40
    addi $s1, $0, 30
    addi $s2, $0, 2440
    addi $s5, $0, 0
    addi $s6, $0, 0
    addi $s7, $0, 0
    addi $t2, $0, 0
    addi $t9, $0, 0
    addi $k0, $0, 1
    addi $fp, $0, 1264
    addi $t7, $0, 4103
    addi $a2, $0, 4105
    sw $s0, 0($a3)
    sw $s1, 1($a3)
    sw $t2, 0($a2)
    sw $k0, 0($ra)
    sw $0, 0($t0)
    addi $a0, $0, 0

clear_loop:
    add $t6, $s4, $a0
    sw $0, 0($t6)
    addi $a0, $a0, 1
    blt $a0, $t8, clear_loop

    addi $a0, $0, 64
    addi $a1, $0, 1264

clear_shadow_loop:
    sw $0, 0($a0)
    addi $a0, $a0, 1
    blt $a0, $a1, clear_shadow_loop

clear_wait:
    lw $a0, 0($t7)
    bne $a0, $0, clear_wait
    addi $a0, $0, 4098
    lw $a1, 0($a0)
    addi $v0, $0, 4
    and $a1, $a1, $v0
    bne $a1, $0, clear_wait
    j loop_wait
