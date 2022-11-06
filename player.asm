;-----------------------------------------------------------------------------
;/////////////////////////////////////////////////////////////////////////////
; START player code
;\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------------------------------

.struct PLAYER
	idle			.byte	; bool : player is idle or not
	animation_tick	.byte
	spriteID 		.byte
	px 				.word	; relative X & Y on screen
	py 				.word
	levelx			.word	; absolute X & Y in the level
	levely			.word	
	flip 			.byte
	tilemap			.word	; cached @ of the tilemap equivalent of the center of the player
.endstruct

.scope Player
init:
	lda #10
	sta player0 + PLAYER::animation_tick
	sta player0 + PLAYER::idle				; player start idle
	stz player0 + PLAYER::spriteID
	stz player0 + PLAYER::px
	stz player0 + PLAYER::px+1
	stz player0 + PLAYER::py
	stz player0 + PLAYER::py+1
	stz player0 + PLAYER::levelx
	stz player0 + PLAYER::levelx+1
	stz player0 + PLAYER::levely
	stz player0 + PLAYER::levely+1
	stz player0 + PLAYER::flip
	rts

;
; force the current player sprite at its position
;	
position_set:
	ldx player0 + PLAYER::spriteID
	LOAD_r0 (player0 + PLAYER::px)
	jsr Sprite::position			; set position of the sprite
	rts
	
	
;
; increase player X position
;
position_x_inc:
	; move the absolute position levelx + 1
	lda player0 + PLAYER::levelx
	ldx player0 + PLAYER::levelx + 1
	cmp #<(LEVEL_WIDTH - 32)
	bne @incLOW1
	cpx #>(LEVEL_WIDTH - 32)
	beq @no_move						; we are at the level limit
@incLOW1:
	inc 
	sta player0 + PLAYER::levelx
	bne @inc_screen_x
@incHi:
	inx
	stx player0 + PLAYER::levelx + 1
	
@inc_screen_x:
	; distance from layer border to sprite absolute position
	sec
	lda player0 + PLAYER::levelx 
	sbc VERA_L1_hscrolllo
	sta r0L
	lda player0 + PLAYER::levelx + 1
	sbc VERA_L1_hscrollhi
	sta r0H

	bne @move_sprite_upper
	lda r0L
	cmp #<(SCREEN_WIDTH	- 96)
	bcc @move_sprite
	
@move_layers:	
	; keep the sprite onscreen 224, for level 224->416
	VSCROLL_INC Layers::HSCROLL,(32*16-320 - 1)	; 32 tiles * 16 pixels per tiles - 320 screen pixels
	beq @move_sprite_upper
	ldx #Layers::HSCROLL
	jsr Layers::scroll_l0
	rts

@move_sprite_upper:
	lda player0 + PLAYER::px
	ldx player0 + PLAYER::px + 1
	inc
	bne @move_sprite
	inx
	
@move_sprite:
	sta player0 + PLAYER::px
	stx player0 + PLAYER::px + 1
	jsr Player::position_set
	rts
		
@no_move:
	rts
;
; decrease player position X unless at 0
;	
position_x_dec:
	; move the absolute position levelx + 1
	lda player0 + PLAYER::levelx
	bne @decLOW
	ldx player0 + PLAYER::levelx + 1
	beq @no_move						; we are at Y == 0
@decLOW:
	dec
	sta player0 + PLAYER::levelx
	cmp #$ff
	bne @dec_screen_x
@decHi:
	dex
	stx player0 + PLAYER::levelx + 1

@dec_screen_x:
	; distance from layer border to sprite absolute position
	sec
	lda player0 + PLAYER::levelx 
	sbc VERA_L1_hscrolllo
	sta r0L
	lda player0 + PLAYER::levelx + 1
	sbc VERA_L1_hscrollhi
	sta r0H

	bne @move_sprite_lower				; > 256, we are far off from the border, so move the sprite

	lda r0L
	bmi @move_sprite_lower					; > 127, move the sprites
	cmp #64
	bcs @move_sprite_lower					; if > 64, move the sprites
	
@move_layers:
	; keep the sprite onscreen 224, for level 224->416
	ldx #Layers::HSCROLL
	jsr Layers::scroll_dec
	beq @move_sprite_lower
	ldx #Layers::HSCROLL
	jsr Layers::scroll_l0
	rts

@move_sprite_lower:
	lda player0 + PLAYER::px
	ldx player0 + PLAYER::px + 1
	dec
	cmp #$ff
	bne @move_sprite
	dex

@move_sprite:
	sta player0 + PLAYER::px
	stx player0 + PLAYER::px + 1
	jsr Player::position_set

@no_move:
	rts

;
; increase player Y position
;
position_y_inc:
	; move the absolute position levelx + 1
	lda player0 + PLAYER::levely
	ldx player0 + PLAYER::levely + 1
	cmp #<(LEVEL_HEIGHT - 32)
	bne @incLOW1
	cpx #>(LEVEL_HEIGHT - 32)
	beq @no_move						; we are at the level limit
@incLOW1:
	inc 
	sta player0 + PLAYER::levely
	bne @inc_screen_y
@incHi:
	inx
	stx player0 + PLAYER::levely + 1

@inc_screen_y:
	; distance from layer border to sprite absolute position
	sec
	lda player0 + PLAYER::levely
	sbc veral1vscrolllo
	sta r0L
	lda player0 + PLAYER::levely + 1
	sbc veral1vscrollhi
	sta r0H

	bne @move_sprite_upper
	lda r0L
	cmp #<(SCREEN_HEIGHT - 64)
	bcc @move_sprite
	
@move_layers:	
	; keep the sprite onscreen 224, for level 224->416
	VSCROLL_INC Layers::VSCROLL,(32*16-240 - 1)	; 32 tiles * 16 pixels per tiles - 240 screen pixels
	beq @move_sprite_upper
	ldx #Layers::VSCROLL
	jsr Layers::scroll_l0
	rts

@move_sprite_upper:
	lda player0 + PLAYER::py
	ldx player0 + PLAYER::py + 1
	inc
	bne @move_sprite
	inx
	
@move_sprite:
	sta player0 + PLAYER::py
	stx player0 + PLAYER::py + 1
	jsr Player::position_set
	rts
		
@no_move:
	rts

;;
	lda player0 + PLAYER::py
	cmp #(SCREEN_HEIGHT-32)
	beq @moveleftP0
	inc
	sta player0 + PLAYER::py
	bne @moveleftP0
	inc player0 + PLAYER::py + 1
@moveleftP0:
	jsr Player::position_set
	rts

;
; decrease player position X unless at 0
;	
position_y_dec:
	lda player0 + PLAYER::py
	cmp #0
	bne @decLOW
	lda player0 + PLAYER::py + 1
	cmp #0
	beq @decend
	dec
	sta player0 + PLAYER::py + 1
	lda #$ff
	sta player0 + PLAYER::py
	bra @decend
@decLOW:
	dec 
	sta player0 + PLAYER::py
@decend:
	jsr Player::position_set
	rts

;
; change the player sprite hv flip
;	
display:
	ldx player0 + PLAYER::spriteID
	lda #SPRITE_ZDEPTH_TOP
	and #SPRITE_FLIP_CLEAR
	ora player0 + PLAYER::flip
	tay							; but keep the current sprite flip
	jsr Sprite::display
	rts

;
; Animate the player if needed
;		
animate:
	lda player0 + PLAYER::idle
	bne @end
	
	dec player0 + PLAYER::animation_tick
	bne @end

	lda #10
	sta player0 + PLAYER::animation_tick	; reset animation tick counter
	
	ldx player0 + PLAYER::spriteID
	ldy #SPRITE_ZDEPTH_DISABLED
	jsr Sprite::display			; turn current sprite off
	
	ldx player0 + PLAYER::spriteID
	inx
	cpx #3
	bne @set_sprite_on
	ldx #0
@set_sprite_on:
	stx player0 + PLAYER::spriteID	; turn next sprite on
	jsr Player::display
	jsr Player::position_set
@end:
	rts
	
;
; change the idle status
;
set_idle:
	sta player0 + PLAYER::idle
	rts

;
; position of the player on the layer1 tilemap
;
get_tilemap_position:
	clc
	lda player0 + PLAYER::py		; sprite screen position 
	adc veral1vscrolllo				; + layer1 scrolling
	sta r0L
	lda player0 + PLAYER::py + 1
	adc veral1vscrollhi
	sta r0H							; r0 = sprite absolute position Y in the level
	
	lda r0L
	adc #16							; half height of the player
	and #%11110000
	sta r0L
	lda r0H
	adc #0							; # add the carry
	sta r0H
	lda r0L
	asl
	rol r0H	
	sta r0L 						; r0 = first tile of the tilemap in the row
									; spriteY / 16 (convert to tile Y) * 32 (number of tiles per row in the tile map)

	lda player0 + PLAYER::px		; sprite screen position 
	adc VERA_L1_hscrolllo			; + layer1 scrolling
	sta r1L
	lda player0 + PLAYER::px + 1
	adc VERA_L1_hscrollhi				
	sta r1H							; r1 = sprite absolute position X in the level
	
	lda r1L
	adc #16							; helf width of the player
	sta r1L
	lda r1H
	adc #0
	lsr			
	ror r1L
	lsr
	ror r1L
	lsr
	ror r1L
	lsr
	ror r1L	
	sta r1H 					; r1 = tile X in the row 
								; sprite X /16 (convert to tile X)
	
	clc
	lda r0L
	adc r1L
	sta r0L
	lda r0H
	adc r1H
	sta r0H						; r0 = tile position in the tilemap
	
	clc
	lda r0H
	adc #>HIMEM
	sta r0H						; r0 = tile position in the memory tilemap
	rts
	
;
; check if the player sits on a solid tile
;
physics:
	jsr get_tilemap_position

	; test tile below
	ldy #32						; test the tile BELOW the player
	lda (r0L),y					; tile value at the position
	bne @sit_on_solid			; solid tile, keep the player there
	
	; let the player fall
	jsr position_y_inc
	
@sit_on_solid:

	SAVE_r0 player0 + PLAYER::tilemap	; cache the tilemap @
	rts

;
; check collision on the right
;
check_collision_right:
	ldy #1						; test the tile on the right of the player
	lda player0 + PLAYER::tilemap
	sta r0L
	lda player0 + PLAYER::tilemap + 1
	sta r0H
	lda (r0L),y
	rts

;
; check collision on the left
;
check_collision_left:
	sec
	lda player0 + PLAYER::tilemap
	sbc #1				; test the tile on the left of the player
	sta r0L
	lda player0 + PLAYER::tilemap + 1
	sbc #0
	sta r0H
	lda (r0L)
	rts

;
; Try to move player to the right
;	
move_right:
	jsr Player::check_collision_right
	bne @return						; collision on the right, block move

	lda #SPRITE_FLIP_H
	sta player0 + PLAYER::flip
	jsr Player::display				; force sprite to loop right
	lda #0
	jsr Player::set_idle			; remove the idle state

	jsr Player::position_x_inc		; move the player in the level, and the screen layers and sprite

@return:
	rts

;
; try to move the player to the left
;	
move_left:
	jsr Player::check_collision_left
	bne @return						; collision on the right, block move

	lda #SPRITE_FLIP_NONE
	sta player0 + PLAYER::flip
	jsr Player::display
	lda #0
	jsr Player::set_idle

	jsr Player::position_x_dec
	
@return:
	rts
.endscope