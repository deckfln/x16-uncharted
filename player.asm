;-----------------------------------------------------------------------------
;/////////////////////////////////////////////////////////////////////////////
; START player code
;\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------------------------------

PLAYER_SPRITE_ANIMATION = 3
PLAYER_SPRITE_FRONT = 0
PLAYER_SPRITE_LEFT = 3
PLAYER_SPRITE_BACK = 6

.enum
	STATUS_WALKING_IDLE
	STATUS_WALKING
	STATUS_CLIMBING
	STATUS_CLIMBING_IDLE
	STATUS_FALLING
.endenum

.struct PLAYER
	sprite			.byte	; sprite index
	status			.byte	; status of the player : IDLE, WALKING, CLIMBING, FALLING
	animation_tick	.byte
	spriteID 		.byte	; current animation loop start
	spriteAnim 		.byte	; current frame
	spriteAnimDirection .byte ; direction of the animation
	px 				.word	; relative X & Y on screen
	py 				.word
	levelx			.word	; absolute X & Y in the level
	levely			.word	
	flip 			.byte
	tilemap			.word	; cached @ of the tilemap equivalent of the center of the player
	vera_bitmaps    .res 	2*9	; 9 words to store vera bitmaps address
.endstruct

.macro m_status value
	lda #(value)
	sta player0 + PLAYER::status
.endmacro

.scope Player
init:
	stz player0 + PLAYER::sprite
	lda #10
	sta player0 + PLAYER::animation_tick
	lda #STATUS_WALKING_IDLE
	sta player0 + PLAYER::status
	lda #PLAYER_SPRITE_LEFT
	sta player0 + PLAYER::spriteID
	stz player0 + PLAYER::spriteAnim
	lda #1
	sta player0 + PLAYER::spriteAnimDirection
	stz player0 + PLAYER::px
	stz player0 + PLAYER::px+1
	stz player0 + PLAYER::py
	stz player0 + PLAYER::py+1
	stz player0 + PLAYER::levelx
	stz player0 + PLAYER::levelx+1
	stz player0 + PLAYER::levely
	stz player0 + PLAYER::levely+1
	stz player0 + PLAYER::flip

	; load sprites data at the end of the tiles
	VLOAD_FILE fssprite, (fsspriteend-fssprite), (VRAM_tiles + tiles * tile_size)

	lda player0 + PLAYER::vera_bitmaps
	sta r0L
	lda player0 + PLAYER::vera_bitmaps+1
	sta r0H

	ldy #0
	jsr Sprite::load

	; turn sprite 0 on
	ldy #0
	ldx #SPRITE_ZDEPTH_TOP
	jsr Sprite::display

	; register the vera simplified memory 12:5
	ldx #0
	ldy #9
	LOAD_r1 (VRAM_tiles + tiles * tile_size)

@loop:
	; load full VERA memory (12:0) into R0
	lda r1L
	sta r0L
	lda r1H
	sta r0H		

	; convert full addr to vera mode (bit shiting >> 5)
	lda r0H
	lsr
	ror r0L
	lsr
	ror r0L
	lsr
	ror r0L
	lsr
	ror r0L						; bit shift 4x 16 bits vera memory
	lsr
	ror r0L						; bit shift 4x 16 bits vera memory

	; store 12:5 into our cache
	sta player0 + PLAYER::vera_bitmaps, x
	inx
	lda r0L
	sta player0 + PLAYER::vera_bitmaps, x
	inx

	; increase the vram (+4 r1H = +1024 r1)
	clc
	lda r1H
	adc #4
	sta r1H

	dey
	bne @loop

	; set first bitmap
	jsr set_bitmap
	rts

;
; force the current player sprite at its position
;	
position_set:
	ldy #0
	LOAD_r0 (player0 + PLAYER::px)
	jsr Sprite::position			; set position of the sprite
	rts
	
;
; change the player bitmap
;	
set_bitmap:
	clc
	lda player0 + PLAYER::spriteAnim
	adc player0 + PLAYER::spriteID
	asl						; convert sprite index to work position
	tax

	; extract the vera bitmap address in vera format (12:5 bits)
	lda player0 + PLAYER::vera_bitmaps, x
	sta r0H
	lda player0 + PLAYER::vera_bitmaps + 1, x
	sta r0L

	ldy #0
	jsr Sprite::set_bitmap
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
	; move the absolute position levelx + 1
	lda player0 + PLAYER::levely
	bne @decLOW
	ldx player0 + PLAYER::levely + 1
	beq @no_move						; we are at Y == 0
@decLOW:
	dec
	sta player0 + PLAYER::levely
	cmp #$ff
	bne @dec_screen_y
@decHi:
	dex
	stx player0 + PLAYER::levely + 1

@dec_screen_y:
	; distance from layer border to sprite absolute position
	sec
	lda player0 + PLAYER::levely 
	sbc veral1vscrolllo
	sta r0L
	lda player0 + PLAYER::levely + 1
	sbc veral1vscrollhi
	sta r0H

	bne @move_sprite_lower				; > 256, we are far off from the border, so move the sprite

	lda r0L
	bmi @move_sprite_lower					; > 127, move the sprites
	cmp #32
	bcs @move_sprite_lower					; if > 32, move the sprites
	
@move_layers:
	; keep the sprite onscreen 224, for level 224->416
	ldx #Layers::VSCROLL
	jsr Layers::scroll_dec
	beq @move_sprite_lower
	ldx #Layers::VSCROLL
	jsr Layers::scroll_l0
	rts

@move_sprite_lower:
	lda player0 + PLAYER::py
	ldx player0 + PLAYER::py + 1
	dec
	cmp #$ff
	bne @move_sprite
	dex

@move_sprite:
	sta player0 + PLAYER::py
	stx player0 + PLAYER::py + 1
	jsr Player::position_set

@no_move:
	rts

;
; hide the current sprite
;
hide1:
	stp
	clc
	lda player0 + PLAYER::spriteAnim
	adc player0 + PLAYER::spriteID
	tay		; sprite index
	ldx #SPRITE_ZDEPTH_DISABLED
	jsr Sprite::display			; turn current sprite off
	rts
	
;
; Animate the player if needed
;		
animate:
	lda player0 + PLAYER::status
	cmp #STATUS_WALKING_IDLE
	beq @end
	cmp #STATUS_FALLING
	beq @end
	cmp #STATUS_CLIMBING_IDLE
	beq @end
	
	dec player0 + PLAYER::animation_tick
	bne @end

	lda #10
	sta player0 + PLAYER::animation_tick	; reset animation tick counter
	
	clc
	lda player0 + PLAYER::spriteAnim
	adc player0 + PLAYER::spriteAnimDirection
	beq @set_sprite_anim_increase					; reached 0
	cmp #3
	beq @set_sprite_anim_decrease
	bra @set_sprite_on
@set_sprite_anim_increase:
	lda #01
	sta player0 + PLAYER::spriteAnimDirection
	lda #0
	bra @set_sprite_on
@set_sprite_anim_decrease:
	lda #$ff
	sta player0 + PLAYER::spriteAnimDirection
	lda #2
@set_sprite_on:
	sta player0 + PLAYER::spriteAnim	; turn next sprite on
	jsr Player::set_bitmap
	jsr Player::position_set
@end:
	rts
	
;
; position of the player on the layer1 tilemap
;
get_tilemap_position:
	clc
	lda player0 + PLAYER::levely		; sprite screen position 
	sta r0L
	lda player0 + PLAYER::levely + 1
	sta r0H							; r0 = sprite absolute position Y in the level
	
	lda r0L
	;adc #16							; half height of the player
	and #%11110000
	sta r0L
	lda r0H
	;adc #0							; # add the carry
	sta r0H
	lda r0L
	asl
	rol r0H	
	sta r0L 						; r0 = first tile of the tilemap in the row
									; spriteY / 16 (convert to tile Y) * 32 (number of tiles per row in the tile map)

	lda player0 + PLAYER::levelx		; sprite screen position 
	sta r1L
	lda player0 + PLAYER::levelx + 1
	sta r1H							; r1 = sprite absolute position X in the level
	
	clc
	lda r1L
	adc #(LEVEL_TILES_WIDTH / 2)	; helf width of the player
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
; force player status to be idle
;	
set_idle:
	lda player0 + PLAYER::status
	cmp #STATUS_WALKING
	beq @set_idle_walking
	cmp #STATUS_FALLING
	beq @set_idle_walking
	cmp #STATUS_CLIMBING
	beq @set_idle_climbing
	
	rts							; keep the current value
	
@set_idle_walking:
	m_status STATUS_WALKING_IDLE
	rts

@set_idle_climbing:
	m_status STATUS_CLIMBING_IDLE
	rts
	
;
; check if the player sits on a solid tile
;
physics:
	jsr get_tilemap_position

	; test tile below
	ldy #64						; test the tile BELOW the player
	lda (r0L),y					; tile value at the position
	bne @sit_on_solid			; solid tile, keep the player there
	
	; let the player fall
	lda #STATUS_FALLING
	sta player0 + PLAYER::status
	
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
; check collision down
;
check_collision_down:
	lda player0 + PLAYER::tilemap
	sta r0L
	lda player0 + PLAYER::tilemap + 1
	sta r0H
	lda (r0L),y
	rts

;
; check collision up
;
check_collision_up:
	;sec
	lda player0 + PLAYER::tilemap
	;sbc #32
	sta r0L
	lda player0 + PLAYER::tilemap + 1
	;sbc #0
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
	lda player0 + PLAYER::status
	cmp #STATUS_FALLING
	beq @return						; cannot move when falling
	
	jsr Player::check_collision_right
	beq @move

	cmp #TILE_SOLID_LADER
	bne @return						; LADDERS can be traversed

@move:
	lda player0 + PLAYER::status
	cmp #STATUS_CLIMBING
	beq @keep_climbing_sprite
	cmp #STATUS_CLIMBING_IDLE
	beq @keep_climbing_sprite
	
@set_walking_sprite:
	lda #SPRITE_FLIP_H
	sta player0 + PLAYER::flip
	ldy #0
	jsr Sprite::set_flip				; force sprite to look right

	m_status STATUS_WALKING

	;change player sprite
	lda #PLAYER_SPRITE_LEFT
	cmp player0 + PLAYER::spriteID
	beq @move_x
	
	lda #PLAYER_SPRITE_LEFT
	sta player0 + PLAYER::spriteID
	jsr set_bitmap

@keep_climbing_sprite:
@move_x:
	jsr Player::position_x_inc		; move the player in the level, and the screen layers and sprite
	jsr position_set

@return:
	rts

;
; try to move the player to the left
;	
move_left:
	lda player0 + PLAYER::status
	cmp #STATUS_FALLING
	beq @return						; cannot move when falling

	jsr Player::check_collision_left
	beq @move

	cmp #TILE_SOLID_LADER
	bne @return						; LADDERS can be traversed

@move:
	lda player0 + PLAYER::status
	cmp #STATUS_CLIMBING
	beq @keep_climbing_sprite
	cmp #STATUS_CLIMBING_IDLE
	beq @keep_climbing_sprite
	
@set_walking_sprite:
	lda #SPRITE_FLIP_NONE
	sta player0 + PLAYER::flip
	ldy #0
	jsr Sprite::set_flip				; force sprite to loop right

	m_status STATUS_WALKING

	lda #PLAYER_SPRITE_LEFT
	cmp player0 + PLAYER::spriteID
	beq @move_x
	
	;change player sprite
	lda #PLAYER_SPRITE_LEFT
	sta player0 + PLAYER::spriteID
	jsr set_bitmap
	
@keep_climbing_sprite:
@move_x:
	jsr Player::position_x_dec
	jsr position_set
	
@return:
	rts
	
;
; try to move the player down (crouch, hide, move down a ladder)
;	
move_down:
	lda player0 + PLAYER::status
	cmp #STATUS_FALLING
	beq @return						; cannot move when falling
	
	ldy #(LEVEL_TILES_WIDTH * 2)
	jsr Player::check_collision_down
	cmp #TILE_SOLID_LADER
	bne @return						; solid collision below, block move

	jsr Player::position_y_inc		; move down the ladder

	m_status STATUS_CLIMBING

	lda #PLAYER_SPRITE_BACK
	cmp player0 + PLAYER::spriteID
	beq @return
	
	;change player sprite
	lda #PLAYER_SPRITE_BACK
	sta player0 + PLAYER::spriteID
	jsr set_bitmap
	jsr position_set
	
@return:
	rts

;
; try to move the player up (move up a ladder)
;	
move_up:
	lda player0 + PLAYER::status
	cmp #STATUS_FALLING
	beq @return						; cannot move when falling
	
	ldy #0
	jsr Player::check_collision_up	; test at head
	cmp #TILE_SOLID_LADER
	beq @climb						; solid collision below, block move

	ldy #LEVEL_TILES_WIDTH
	jsr Player::check_collision_up	; test at hip
	cmp #TILE_SOLID_LADER
	beq @climb						; solid collision below, block move
	
	lda player0 + PLAYER::levely	; if player is not on a multiple of 16 (tile size)
	and #%00001111
	beq @return	
	
	; the player covers 3 vertical tiles
	ldy #(LEVEL_TILES_WIDTH * 2)
	jsr Player::check_collision_up	; test at feet
	cmp #TILE_SOLID_LADER
	bne @return						; solid collision below, block move

@climb:
	jsr Player::position_y_dec		; move down the ladder

	m_status STATUS_CLIMBING

	lda #PLAYER_SPRITE_BACK
	cmp player0 + PLAYER::spriteID
	beq @return
	
	;change player sprite
	lda #PLAYER_SPRITE_BACK
	sta player0 + PLAYER::spriteID
	jsr set_bitmap
	jsr position_set
	
@return:
	rts

.endscope