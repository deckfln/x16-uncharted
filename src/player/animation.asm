.scope Animation

.struct Frame
	move_pixel_x	.byte
	move_pixel_y	.byte
	ticks			.byte
	frameID			.byte
.endstruct

.enum Direction
	RIGHT = 1
	LEFT = 2
	UP = 4
	DOWN = 8
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
	bne :+
	jmp end_anim
:
	dec anim_len

	ldx direction

	ldy #00
@x:
	lda (anim_table),y				; move X
	cpx #Direction::LEFT
	beq @backward
	cpx #Direction::RIGHT
	beq @forward
	bra @y
@forward:
	clc
	adc player0 + Entity::levelx
	sta player0 + Entity::levelx
	bcc :+
	inc player0 + Entity::levelx + 1
:
	bra @y
@backward:
	sec
	sta tmp_player
	lda player0 + Entity::levelx
	sbc tmp_player
	sta player0 + Entity::levelx
	bcs :+
	dec player0 + Entity::levelx + 1
:
@y:
	iny
	lda (anim_table),y				; move X
	cpx #Direction::DOWN
	beq @downward
	cpx #Direction::UP
	beq @upward
	bra @next
@downward:
	clc
	adc player0 + Entity::levely
	sta player0 + Entity::levely
	bcc :+
	inc player0 + Entity::levely + 1
:
	bra @next
	bra @next
@upward:
	sec
	sta tmp_player
	lda player0 + Entity::levely
	sbc tmp_player
	sta player0 + Entity::levely
	bcs :+
	dec player0 + Entity::levely + 1
:
@next:
	iny
	lda (anim_table),y				; # of frames to wait
	sta player0 + PLAYER::animation_tick
	iny
	lda (anim_table),y				; frame to display
	bit #$80						; use the frameID as -is or mirror
	beq @straight
@reverse:
	and #$7f						; remove the flag
	sta player0 + PLAYER::frame
	lda #SPRITE_FLIP_H
	jsr Player::set_flip
	bra @set
@straight:
	lda #SPRITE_FLIP_NONE
	jsr Player::set_flip
	sta player0 + PLAYER::frame
@set:
	jsr Player::set_bitmap			; register all the changes
	jsr Entities::position_x_changed
@next_frame:
	clc								
	lda anim_table
	adc #.sizeof(Frame)
	sta anim_table
	bcc :+
	inc anim_table+1
:	
	rts
end_anim:
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
;		A = low bytes of animation table
;		Y = high bytes of animation table
;	
Set:
	sta anim_table
	sty anim_table + 1

	ldy #00
	lda (anim_table),y
	sta anim_len			; load len of the animation
	inc anim_table			; and move to the start
	bne :+
	inc anim_table+1
:
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
	rts

.endscope