;-----------------------------------------------------------------------------
;/////////////////////////////////////////////////////////////////////////////
; START player code
;\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------------------------------

PLAYER_SPRITE_ANIMATION = 3
PLAYER_SPRITE_FRONT = 0
PLAYER_SPRITE_LEFT = 3
PLAYER_SPRITE_BACK = 6

JUMP_LO_TICKS = 10
JUMP_HI_TICKS = 2
FALL_LO_TICKS = 8
FALL_HI_TICKS = 2

.enum
	STATUS_WALKING_IDLE
	STATUS_WALKING
	STATUS_CLIMBING
	STATUS_CLIMBING_IDLE
	STATUS_FALLING
	STATUS_JUMPING
	STATUS_JUMPING_IDLE
.endenum

.struct PLAYER
	sprite			.byte	; sprite index
	status			.byte	; status of the player : IDLE, WALKING, CLIMBING, FALLING
	falling_ticks	.word	; ticks since the player is fllaing (thing t in gravity) 
	delta_x			.byte	; when driving by phisics, original delta_x value
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

;************************************************
;
;
init:
	stz player0 + PLAYER::sprite
	lda #10
	sta player0 + PLAYER::animation_tick
	lda #STATUS_WALKING_IDLE
	sta player0 + PLAYER::status
	stz player0 + PLAYER::falling_ticks
	stz player0 + PLAYER::falling_ticks + 1
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

	ldy player0 + PLAYER::sprite
	jsr Sprite::load

	; turn sprite 0 on
	ldy player0 + PLAYER::sprite
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

;************************************************
; force the current player sprite at its position
;	
position_set:
	ldy player0 + PLAYER::sprite
	LOAD_r0 (player0 + PLAYER::px)
	jsr Sprite::position			; set position of the sprite
	rts
	
;************************************************
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

	ldy player0 + PLAYER::sprite
	jsr Sprite::set_bitmap
	rts
	
;************************************************
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
	ldx r0H
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

;************************************************
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

;************************************************
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
	ldx r0H
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

;************************************************
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

;************************************************
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
	
;************************************************
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
	
;************************************************
; position of the player on the layer1 tilemap
;
get_tilemap_position:
	clc
	lda player0 + PLAYER::levely		; sprite screen position 
	sta r0L
	lda player0 + PLAYER::levely + 1
	sta r0H							; r0 = sprite absolute position Y in the level
	
	lda r0L
	and #%11110000
	sta r0L
	lda r0H
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

;************************************************
; force player status to be idle
;	
set_idle:
	lda player0 + PLAYER::status
	cmp #STATUS_WALKING
	beq @set_idle_walking
	cmp #STATUS_CLIMBING
	beq @set_idle_climbing
	rts							; keep the current value
@set_idle_jump:
	rts
@set_idle_walking:
	m_status STATUS_WALKING_IDLE
	rts
@set_idle_climbing:
	m_status STATUS_CLIMBING_IDLE
	rts
	
;************************************************
; check if the player sits on a solid tile
;
physics:
	jsr get_tilemap_position
	SAVE_r0 player0 + PLAYER::tilemap	; cache the tilemap @

	lda player0 + PLAYER::status
	cmp #STATUS_CLIMBING
	beq @simple_check
	cmp #STATUS_CLIMBING_IDLE
	beq @simple_check
	cmp #STATUS_JUMPING
	bne @fall
	jmp @jump
@return1:
	rts

@simple_check:
	jsr check_collision_down
	bne @return1				; some tile, keep the player there

	;
	; deal with gravity driven falling
	; 
@fall:
	lda player0 + PLAYER::levely	
	and #%00001111
	bne @no_collision_down			; if player is not on a multiple of 16 (tile size)

	jsr check_collision_down
	bne @sit_on_solid				; solid tile, keep the player there

@no_collision_down:	
	; if the player is already falling, increase t
	lda player0 + PLAYER::status
	cmp #STATUS_FALLING
	beq @increase_ticks

	; let the player fall
	lda #STATUS_FALLING
	sta player0 + PLAYER::status
	lda #FALL_LO_TICKS
	sta player0 + PLAYER::falling_ticks	; reset t
	stz player0 + PLAYER::falling_ticks + 1
@increase_ticks:
	dec player0 + PLAYER::falling_ticks	; increase HI every 10 refresh
	bne @drive_fall
	lda #FALL_LO_TICKS
	sta player0 + PLAYER::falling_ticks	; reset t
	inc player0 + PLAYER::falling_ticks + 1

@drive_fall:
	lda player0 + PLAYER::falling_ticks + 1
	beq @fall_once
	sta r9L
@loop_fall:
	jsr position_y_inc
	jsr get_tilemap_position
	SAVE_r0 player0 + PLAYER::tilemap

	lda player0 + PLAYER::levely	
	and #%00001111
	bne @loop_fall_no_collision		; if player is not on a multiple of 16 (tile size)

	; test reached solid ground
	jsr check_collision_down
	bne @sit_on_solid

@loop_fall_no_collision:
	dec r9L
	bne @loop_fall						; take t in count for gravity

@apply_delta_x:
	lda player0 + PLAYER::delta_x		; apply delatx
	beq @return
	bmi @fall_left
@fall_right:
	jsr check_collision_right
	beq @no_fcollision_right
@fcollision_right:
	stz player0 + PLAYER::delta_x		; cancel deltaX to transform to vertical movement
	rts	
@no_fcollision_right:
	jsr position_x_inc
	rts
@fall_left:
	jsr check_collision_left
	beq @no_fcollision_left
@fcollision_left:
	stz player0 + PLAYER::delta_x		; cancel deltaX to transform to vertical movement
	rts	
@no_fcollision_left:
	jsr position_x_dec
	rts

@fall_once:
	jsr position_y_inc
	bra @apply_delta_x

@sit_on_solid:
	; change the status if falling
	lda player0 + PLAYER::status
	cmp #STATUS_FALLING
	bne @return
	lda #STATUS_WALKING_IDLE
	sta player0 + PLAYER::status
@return:
	rts

	;
	; deal with gravity driven jumping
	; 
@jump:
@decrease_ticks:
	dec player0 + PLAYER::falling_ticks	; decrease  HI every 10 refresh
	bne @drive_jump
	dec player0 + PLAYER::falling_ticks	+ 1
	beq @apex							; reached the apex of the jump

	lda #JUMP_LO_TICKS
	sta player0 + PLAYER::falling_ticks	; reset t

@drive_jump:
	lda player0 + PLAYER::falling_ticks + 1
	sta r9L
@loop_jump:
	jsr position_y_dec
	jsr get_tilemap_position
	SAVE_r0 player0 + PLAYER::tilemap

	lda player0 + PLAYER::levely	
	and #%00001111
	bne @no_collision_up				; if player is not on a multiple of 16 (tile size)

	; test hit a ceiling
	jsr check_collision_up
	bne @collision_up
@no_collision_up:
	dec r9L
	bne @loop_jump						; loop to take t in count for gravity

@collision_up:
	lda player0 + PLAYER::delta_x		; deal with deltax
	beq @return
	bmi @jump_left
@jump_right:
	jsr check_collision_right
	beq @no_collision_right
@collision_right:
	stz player0 + PLAYER::delta_x		; cancel deltaX to transform to vertical movement
	rts	
@no_collision_right:
	jsr position_x_inc
	rts
@jump_left:
	jsr check_collision_left
	beq @no_collision_left
@collision_left:
	stz player0 + PLAYER::delta_x		; cancel deltaX to transform to vertical movement
	rts	
@no_collision_left:
	jsr position_x_dec
	rts

@apex:
	m_status STATUS_JUMPING_IDLE
	rts

;************************************************
; check collision on the right
;	A = vaule of the collision
;	ZERO = no collision
;
check_collision_right:
	lda player0 + PLAYER::tilemap
	sta r0L
	lda player0 + PLAYER::tilemap + 1
	sta r0H

	; X = how many lines of tiles to test
	lda player0 + PLAYER::levely
	and #%00001111
	bne @yfloat				; if player is not on a multiple of 16 (tile size)
@yint:
	ldx #2					; test 2 lines ( y % 16 == 0)
	bra @test_x
@yfloat:
	ldx #3					; test 3 rows ( y % 16 <> 0)

@test_x:
	; Y = chat tile column to test
	ldy #2					; test on column 2 ( x % 16 != 0)
							; test on column 2 ( x % 16 == 0)

@test_line:
	lda (r0L),y
	beq @test_next_line

	; some tiles are not real collision 
	cmp #TILE_SOLID_LADER
	beq @no_collision				; LADDERS can be traversed
	rts

@test_next_line:
	dex
	beq @no_collision
	tya
	clc
	adc #LEVEL_TILES_WIDTH			; test the tile on the right of the player (hip position)
	tay
	bra @test_line					; LADDERS can be traversed

@no_collision:						; force a no collision
	lda #0
	rts
@return:
	rts

;************************************************
; check collision on the left
;
check_collision_left:
	sec
	lda player0 + PLAYER::tilemap
	sbc #1							; test the tile on the left of the player (tilemap = x+16 => tileX+1)
	sta r0L
	lda player0 + PLAYER::tilemap + 1
	sbc #0
	sta r0H

	; X = how many lines of tiles to test
	lda player0 + PLAYER::levely
	and #%00001111
	bne @yfloat				; if player is not on a multiple of 16 (tile size)
@yint:
	ldx #2					; test 2 lines ( y % 16 == 0)
	bra @test_x
@yfloat:
	ldx #3					; test 3 rows ( y % 16 <> 0)

@test_x:
	; Y = chat tile column to test
	lda player0 + PLAYER::levelx
	and #%00001111
	beq @xint				; if player is not on a multiple of 16 (tile size)
@xfloat:
	ldy #1					; test on column 0 ( x % 16 != 0)
	bra @test_line
@xint:
	ldy #0					; test on column -1 ( x % 16 == 0)

@test_line:
	lda (r0L),y
	beq @test_next_line

	; some tiles are not real collision 
	cmp #TILE_SOLID_LADER
	beq @no_collision				; LADDERS can be traversed
	rts

@test_next_line:
	dex	
	beq @no_collision
	tya
	clc
	adc #LEVEL_TILES_WIDTH			; test the tile on the left of the player (hip position)
	tay
	bra @test_line

@no_collision:
	lda #0
	rts


;************************************************
; check collision down
;
check_collision_down:
	lda player0 + PLAYER::tilemap
	sta r0L
	lda player0 + PLAYER::tilemap + 1
	sta r0H

	; X = how many column of tiles to test
	lda player0 + PLAYER::levelx
	and #%00001111
	bne @xfloat				; if player is not on a multiple of 16 (tile size)
@xint:
	ldx #2					; test 2 columns ( y % 16 == 0)
	bra @test_y
@xfloat:
	ldx #3					; test 3 columns ( y % 16 <> 0)

@test_y:
	; Y = how tile rows to test
	ldy #LEVEL_TILES_WIDTH * 2		; test on row +2 ( x % 16 != 0)
									; test on row +2 ( x % 16 == 0)

@test_colum:
	lda (r0L),y
	bne @return
	dex 
	beq @return
	iny
	bra @test_colum					
@return:
	rts

;************************************************
; check collision up
;	output : r0 : @ of tile y-1 of levelY
;
check_collision_up:
	sec
	lda player0 + PLAYER::tilemap
	sbc #LEVEL_TILES_WIDTH
	sta r0L
	lda player0 + PLAYER::tilemap + 1
	sbc #0
	sta r0H

	; X = how many column of tiles to test
	lda player0 + PLAYER::levelx
	and #%00001111
	bne @xfloat				; if player is not on a multiple of 16 (tile size)
@xint:
	ldx #2					; test 2 columns ( y % 16 == 0)
	bra @test_y
@xfloat:
	ldx #3					; test 3 columns ( y % 16 <> 0)

@test_y:
	; Y = how tile rows to test
	lda player0 + PLAYER::levely
	and #%00001111
	beq @yint				; if player is not on a multiple of 16 (tile size)
@yfloat:
	ldy #(LEVEL_TILES_WIDTH * 2)	; test on (row -1) +1 ( x % 16 != 0)
	bra @test_colum
@yint:
	ldy #0						; test on row - 1 ( x % 16 == 0)

@test_colum:
	lda (r0L),y							; left side
	beq @no_collision					
	dex
	beq @no_collision
	iny
	bra @test_colum

@no_collision:
	rts

;************************************************
; Try to move player to the right
;	
move_right:
	lda player0 + PLAYER::status
	cmp #STATUS_FALLING
	beq @return
	cmp #STATUS_JUMPING
	beq @return						; cannot move when falling or jumping
	cmp #STATUS_JUMPING_IDLE
	beq @return						; cannot move when falling or jumping

	jsr Player::check_collision_right
	bne @return
@no_collision:
	lda #1
	sta player0 + PLAYER::delta_x

@move:
	lda player0 + PLAYER::status
	cmp #STATUS_CLIMBING
	beq @keep_climbing_sprite
	cmp #STATUS_CLIMBING_IDLE
	beq @keep_climbing_sprite
	
@set_walking_sprite:
	lda #SPRITE_FLIP_H
	sta player0 + PLAYER::flip
	ldy player0 + PLAYER::sprite
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

;************************************************
; try to move the player to the left
;	
move_left:
	lda player0 + PLAYER::status
	cmp #STATUS_FALLING
	beq @return
	cmp #STATUS_JUMPING
	beq @return						; cannot move when falling or jumping
	cmp #STATUS_JUMPING_IDLE
	beq @return						; cannot move when falling or jumping

	lda player0 + PLAYER::levelx
	and #%00001111
	bne @no_collision				; if player is not on a multiple of 16 (tile size)

	jsr Player::check_collision_left
	bne @return
@no_collision:
	lda #$ff
	sta player0 + PLAYER::delta_x

@move:
	lda player0 + PLAYER::status
	cmp #STATUS_CLIMBING
	beq @keep_climbing_sprite
	cmp #STATUS_CLIMBING_IDLE
	beq @keep_climbing_sprite
	
@set_walking_sprite:
	lda #SPRITE_FLIP_NONE
	sta player0 + PLAYER::flip
	ldy player0 + PLAYER::sprite
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
	
;************************************************
; try to move the player down (crouch, hide, move down a ladder)
;	
move_down:
	lda player0 + PLAYER::status
	cmp #STATUS_FALLING
	bne @try_move_down						; cannot move when falling
	rts

@try_move_down:
	jsr Player::check_collision_down
	cmp #TILE_SOLID_LADER
	bne @cannot_move_down					; solid collision below, block move

	jsr Player::position_y_inc		; move down the ladder
	jsr position_set

	m_status STATUS_CLIMBING

	lda #PLAYER_SPRITE_BACK
	cmp player0 + PLAYER::spriteID
	bne @change_sprite
	rts

@change_sprite:
	;change player sprite
	lda #PLAYER_SPRITE_BACK
	sta player0 + PLAYER::spriteID
	jsr set_bitmap
	rts

@cannot_move_down:
	lda #STATUS_WALKING_IDLE
	sta player0 + PLAYER::status
	rts

;************************************************
; try to move the player up (move up a ladder)
;	
move_up:
	lda player0 + PLAYER::status
	cmp #STATUS_FALLING
	bne @try_move_up				; cannot move when falling
	rts
@try_move_up:
	jsr Player::check_collision_up	; test above the head

	ldy #LEVEL_TILES_WIDTH
	lda (r0L),y
	cmp #TILE_SOLID_LADER
	beq @climb						; solid ladder at the head

	ldy #(LEVEL_TILES_WIDTH*2)
	lda (r0L),y
	cmp #TILE_SOLID_LADER
	beq @climb						; NO solid ladder at the feet

	lda player0 + PLAYER::levely	
	and #%00001111
	beq @cannot_move_up				; if player is not on a multiple of 16 (tile size)

	ldy #(LEVEL_TILES_WIDTH*3)		; player covers 3 tiles
	lda (r0L),y
	cmp #TILE_SOLID_LADER
	bne @cannot_move_up				; NO solid ladder at the feet

@climb:
	jsr Player::position_y_dec		; move up the ladder
	jsr position_set

	m_status STATUS_CLIMBING

	lda #PLAYER_SPRITE_BACK
	cmp player0 + PLAYER::spriteID
	bne @set_sprite
	rts
@set_sprite:						;change player sprite
	lda #PLAYER_SPRITE_BACK
	sta player0 + PLAYER::spriteID
	jsr set_bitmap
	rts

@cannot_move_up:
	lda #STATUS_WALKING_IDLE
	sta player0 + PLAYER::status
	rts

;************************************************
; jump
;	A = delta X value
;
jump:
    ldx player0 + PLAYER::status
	cpx #STATUS_JUMPING
	beq @return							; one trigger the first jump
	cpx #STATUS_FALLING
	beq @return							; one trigger the first jump
	cpx #STATUS_JUMPING_IDLE
	beq @return						; cannot move when falling or jumping

	sta player0 + PLAYER::delta_x

	lda #JUMP_LO_TICKS
	sta player0 + PLAYER::falling_ticks	; decrease  HI every 10 refresh
	lda #JUMP_HI_TICKS
	sta player0 + PLAYER::falling_ticks	+ 1

	m_status STATUS_JUMPING
@return:
	rts

.endscope