.scope Animation

.struct Frame
	move_pixel	.byte
	ticks		.byte
	frameID		.byte
.endstruct

.enum Direction
	RIGHT = 1
	LEFT = 2
.endenum

;************************************************

PLAYER_ZP = $0050
anim_table = PLAYER_ZP
anim_len = anim_table + 2

target: .byte 0            ; tile value to pass control to at the end of the animation
direction: .byte 0

;************************************************
; change to animation controler
;	input: r3
;		A = tile attributes
;		X = tile value
;	
update:
	lda player0 + PLAYER::animation_tick	
	beq @set_frame
	dec player0 + PLAYER::animation_tick
	rts
@set_frame:
	lda anim_len
	beq @end_anim
	dec anim_len

	ldx direction

	ldy #00
	lda (anim_table),y				; move X
	cpx #Direction::LEFT
	beq @backward
@forward:
	clc
	adc player0 + Entity::levelx
	sta player0 + Entity::levelx
	bcc :+
	inc player0 + Entity::levelx + 1
:
	bra @next
@backward:
	sec
	sta tmp_player
	lda player0 + Entity::levelx
	sbc tmp_player
	sta player0 + Entity::levelx
	bcs :+
	dec player0 + Entity::levelx + 1
:

@next:
	iny
	lda (anim_table),y				; # of frames to wait
	sta player0 + PLAYER::animation_tick
	iny
	lda (anim_table),y				; frame to display
	sta player0 + PLAYER::frame

	jsr Player::set_bitmap			; register all the changes
	jsr Entities::position_x_changed

	ldx direction					; get ready for next frame
	cpx #Direction::RIGHT
	beq @next_frame
@prev_frame:
	sec								
	lda anim_table
	sbc #.sizeof(Frame)
	sta anim_table
	bcs :+
	dec anim_table+1
:	
	rts
@next_frame:
	clc								
	lda anim_table
	adc #.sizeof(Frame)
	sta anim_table
	bcc :+
	inc anim_table+1
:	
	rts
@end_anim:
	ldy #Entity::update				; clean the update feature
	lda #00
	sta (r3),y
	iny
	sta (r3),y

	ldx target
	jmp Player::set_controler		; move to the next controler

;************************************************
; change to animation controler
;	input: r3
;		A = tile attributes
;		X = tile value
;	
Set:
	sta anim_table
	sty anim_table + 1
    stx target

	ldy #00
	lda (anim_table),y
	sta anim_len			; load len of the animation
	inc anim_table			; and move to the start
	bne :+
	inc anim_table+1
:

	lda direction
	cmp #Direction::RIGHT
	beq @next
	cmp #Direction::LEFT
	beq @right_2_left
	brk						; should not be here
@right_2_left:
	ldx anim_len
	dex
@loop:
	clc
	lda anim_table
	adc #.sizeof(Frame)
	sta anim_table
	lda anim_table+1
	adc #00
	sta anim_table+1
	dex
	bne @loop				; move to the last frame

@next:
	stz player0 + PLAYER::frameID

	ldy #Entity::update
	lda #<update
	sta (r3),y
	iny
	lda #>update
	sta (r3),y

	; reset animation tick counter
	lda #00
	sta player0 + PLAYER::animation_tick	
	lda #01
	sta player0 + PLAYER::frameDirection

	; set virtual functions move right/meft
	lda #00
	sta Entities::fnMoveRight_table
	sta Entities::fnMoveRight_table+1
	sta Entities::fnMoveLeft_table
	sta Entities::fnMoveLeft_table+1

	; set virtual functions move up/down
	sta Entities::fnMoveUp_table
	sta Entities::fnMoveUp_table+1
	sta Entities::fnMoveDown_table
	sta Entities::fnMoveDown_table+1

	; set virtual functions walk jump
	sta fnJump_table
	sta fnJump_table+1

	; set virtual functions walk grab
	sta fnGrab_table
	sta fnGrab_table+1

	; set virtual functions walk animate
	sta fnAnimate_table
	sta fnAnimate_table+1

	rts

.endscope