.scope Transitions

.enum Direction
    UP = 1
    DOWN = 2
    LEFT = 4
    RIGHT = 8
.endenum

.struct Transition
	control1	.byte	; id of the entity
	control2	.byte	; classID
    direction   .byte
    action      .byte
    animate     .addr
.endstruct

;*****************
; from LADDER to WALK
; input X = direction
;
from_ladder_2_walk:
    stx Animation::direction
	jmp Entities::align_on_y_tile

;*****************
; from LADDER to WALK
; input X = direction
;       Y = target tile
;  number of frames
;   delta_x
;   ticks to display
;   framde number
;
from_ledge2hang_right: .byte 3,0,8,28,8,8,27,8,8,29
from_ledge2hang_left: .byte 3,0,8,29,8,8,27,8,8,28

;*******
;
from_ledge_2_hang:
    cpx #Animation::Direction::LEFT
    beq @left
@right:
    lda #<from_ledge2hang_right
    ldy #>from_ledge2hang_right
    bra @set
@left:
    lda #<from_ledge2hang_left
    ldy #>from_ledge2hang_left
@set:
	jmp Animation::Set

;******
;
from_hang_2_hang:
    cpx #Animation::Direction::LEFT
    beq @left
@right:
    lda #<from_ledge2hang_right
    ldy #>from_ledge2hang_right
    bra @set
@left:
    lda #<from_ledge2hang_left
    ldy #>from_ledge2hang_left
@set:
    ldx #TILE::HANG_FROM
	jmp Animation::Set

;*****************
; table of transition
;
pl: .byte TILE::SOLID_LADER,    TILE::LEDGE,        Direction::LEFT | Direction::RIGHT, 1, 0
    .byte TILE::LEDGE,          TILE::HANG_FROM,    Direction::LEFT | Direction::RIGHT, 8, 0
    .byte TILE::SOLID_LADER,    TILE::HANG_FROM,    Direction::LEFT | Direction::RIGHT, 8, 0
    .byte TILE::ROPE,           TILE::LEDGE,        Direction::LEFT | Direction::RIGHT, 1, 0
    .byte TILE::ROPE,           TILE::HANG_FROM,    Direction::LEFT | Direction::RIGHT, 8, 0
    .byte TILE::ROPE,           TILE::SOLID_GROUND_GET_DOWN, Direction::UP | Direction::DOWN, 8, 0
    .byte TILE::SOLID_LADER,    TILE::SOLID_GROUND_GET_DOWN, Direction::UP | Direction::DOWN, 8, <from_ladder_2_walk, >from_ladder_2_walk
    .byte TILE::LEDGE,          TILE::HANG_FROM,    Direction::LEFT | Direction::RIGHT, 8, <from_ledge_2_hang, >from_hang_2_hang
    .byte TILE::HANG_FROM,      TILE::HANG_FROM,    Direction::LEFT | Direction::RIGHT, 8, <from_ledge_2_hang, >from_hang_2_hang

pl_end:

;******************
;* input: A = controler 1
;*        X = controler 2
;* output : r1 = address of the struct
;*          A = 00 : found
;*          A = 01 : not found
get:
    sta r2L
    stx r2H

    lda #<pl
    sta r1L
    lda #>pl
    sta r1H

    ldx #((pl_end - pl) / .sizeof(Transition))
@loop:
    ldy #00
    lda (r1),y
    cmp r2L
    beq @ok1
    iny
    lda (r1), y
    cmp r2L
    beq @ok2
    bra @next
@ok1:
    iny
    lda (r1),y
    cmp r2H
    beq @ok
    bra @next
@ok2:
    dey
    lda (r1),y
    cmp r2H
    beq @ok
@next:
    dex
    beq @notfound
    clc
    lda r1L
    adc #.sizeof(Transition)
    sta r1L
    lda r1H
    adc #00
    sta r1H
    bra @loop
@notfound:
    lda #01
    rts
@ok:
    lda #00
    rts

;*****************
; execute an transition between controler
; input : R1 = addr of the transition block
;           X = direction
;           Y = target tile
;
run:
    stx Animation::direction
    sty Animation::target

    ldy #Transition::animate
    lda (r1), y
    sta @go + 1
    iny
    lda (r1), y
    sta @go + 2
@go:
    jmp 0000

.endscope