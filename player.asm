;-----------------------------------------------------------------------------
;/////////////////////////////////////////////////////////////////////////////
; START player code
;\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------------------------------

.struct PLAYER
	idle			.byte	; bool : player is idle or not
	animation_tick	.byte
	spriteID 		.byte
	px 				.word
	py 				.word
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
	stz player0 + PLAYER::flip
	rts
	
;
; increase player X position
;
position_x_inc:
	lda player0 + PLAYER::px
	ldx player0 + PLAYER::px + 1
	cmp #<(SCREEN_WIDTH - 32)
	bne @incLOW
	cpx #>(SCREEN_WIDTH - 32)
	beq @incend						; we are at the top limit
@incLOW:
	inc 
	sta player0 + PLAYER::px
	bne @incend
@incHi:
	inx
	stx player0 + PLAYER::px + 1
@incend:
	jsr Player::position_set
	rts

;
; decrease player position X unless at 0
;	
position_x_dec:
	lda player0 + PLAYER::px
	cmp #0
	bne @decLOW
	lda player0 + PLAYER::px + 1
	cmp #0
	beq @decend
	dec
	sta player0 + PLAYER::px + 1
	lda #$ff
	sta player0 + PLAYER::px
	bra @decend
@decLOW:
	dec 
	sta player0 + PLAYER::px
@decend:
	jsr Player::position_set
	rts

;
; increase player Y position
;
position_y_inc:
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
; force the current player sprite at its position
;	
position_set:
	ldx player0 + PLAYER::spriteID
	LOAD_r0 (player0 + PLAYER::px)
	jsr Sprite::position			; set position of the sprite
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
	lda player0 + PLAYER::px
	beq @cont
@cont:
	inc player0 + PLAYER::py
	bne @move
	inc player0 + PLAYER::py + 1
@move:
	jsr position_set
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

	lda player0 + PLAYER::px		; if the player is near the border
	cmp #<(SCREEN_WIDTH-96)
	bne @move_player
	lda player0 + PLAYER::px + 1
	cmp #>(SCREEN_WIDTH-96)
	bne @move_player

	; do not move the player but the layers
@move_layers:	
	VSCROLL_INC Layers::HSCROLL,(32*16-320 - 1)	; 32 tiles * 16 pixels per tiles - 320 screen pixels
	beq @move_player			; can't scroll the map more, so move the player
	
	ldx #Layers::HSCROLL
	jsr Layers::scroll_l0
	rts

@move_player:
	jsr Player::position_x_inc
	
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

	lda player0 + PLAYER::px		; if the player is near the border
	cmp #32
	bne @move_player
	lda player0 + PLAYER::px + 1
	bne @move_player

@move_layers:
	ldx #Layers::HSCROLL
	jsr Layers::scroll_dec
	beq @move_player			; can't scroll the map more, so move the player
	
	ldx #Layers::HSCROLL
	jsr Layers::scroll_l0
	rts
	
@move_player:
	jsr Player::position_x_dec
	
@return:
	rts
.endscope