;-----------------------------------------------------------------------------
;/////////////////////////////////////////////////////////////////////////////
; START player code
;\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------------------------------

PLAYER_SPRITE_ANIMATION = 3

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

.enum
	SITTING_NO_SLOP
	SITTING_ON_SLOPE
	SITTING_ABOVE_SLOPE
.endenum

.enum TILE_ATTR
	SOLID_GROUND = 1
	SOLID_WALL = 2
	SOLID_CEILING = 4
	GRABBING = 8			; player can grab the tile (ladder, ledge, rope)
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
	vera_bitmaps    .res 	2*12	; 9 words to store vera bitmaps address
.endstruct

.macro m_status value
	lda #(value)
	sta player0 + PLAYER::status
.endmacro

.scope Player

.macro SET_SPRITE id, frame
	lda #id
	sta player0 + PLAYER::spriteID
	lda #frame
	sta player0 + PLAYER::spriteAnim
	jsr set_bitmap
.endmacro

;************************************************
; player sprites status
;
.enum Sprites
	FRONT = 0
	LEFT = 3
	CLIMB = 6
	HANG = 9
.endenum

;************************************************
; local variables
;

player_on_slop: .byte 0
ladders: .byte 0
test_right_left: .byte 0

;************************************************
; init the player data
;
init:
	stz player0 + PLAYER::sprite
	lda #10
	sta player0 + PLAYER::animation_tick
	lda #STATUS_WALKING_IDLE
	sta player0 + PLAYER::status
	stz player0 + PLAYER::falling_ticks
	stz player0 + PLAYER::falling_ticks + 1
	lda #Player::Sprites::LEFT
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
	ldx #%10100000					; 32x32 sprite
	jsr Sprite::load

	; turn sprite 0 on
	ldy player0 + PLAYER::sprite
	ldx #SPRITE_ZDEPTH_TOP
	jsr Sprite::display

	; register the vera simplified memory 12:5
	ldx #0
	ldy #(3*4)
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
;	modify r0
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
;	modified : r1
;	output : r0
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
	beq @return1
	cmp #STATUS_CLIMBING_IDLE
	beq @return1
	cmp #STATUS_JUMPING
	bne @fall
	jmp @jump
@return1:
	rts

	;
	; deal with gravity driven falling
	; 
@fall:
.ifdef DEBUG
	CHECK_DEBUG
.endif
	jsr check_collision_down
	beq @check_on_slope				; no solid tile below the player, still check if the player is ON a slope
	jmp @sit_on_solid				; solid tile below the player that is not a slope

@check_on_slope:
	jsr check_player_on_slop
	beq @no_collision_down			; not ON a slope, and not ABOVE a solid tile => fall

@on_slope:
	cmp #TILE_SOLD_SLOP_LEFT
	beq @slope_left
@slope_right:
	lda player0 + PLAYER::levelx	; X position defines how far down Y can go
	and #%00001111
	eor #%00001111					; X = 0 => Y can go up to 15
	sta $30
	bra @slope_y
@slope_left:
	lda player0 + PLAYER::levelx	; X position defines how far down Y can go
	and #%00001111
	sta $30
	bra @slope_y
@slope_y:
	lda player0 + PLAYER::levely	
	and #%00001111
	cmp $30
	bmi @no_collision_down
	bra @sit_on_solid

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
;	compute the number of tiles covered by the boundingbox
;	return: r1L : number of tiles height
;			X = r1H : number of tiles width
;			Y = r2L : index of the first tile to test
;
bbox_coverage:
	; X = how many column of tiles to test
	lda player0 + PLAYER::levelx
	and #%00001111
	cmp #8
	beq @one_tile
	bmi @two_tiles_straight				; if X < 8, test as if int
@two_tiles_right:
	ldx #02								; test 2 column ( y % 16 <> 0)
	ldy #01								; starting on row +1
	bra @test_lines
@one_tile:
	ldx #01								; test 1 column ( y % 16  == 8)
	ldy #01								; starting on row +1
	bra @test_lines
@two_tiles_straight:
	ldx #02								; test 2 columns ( y % 16 == 0)
	ldy #00								; test on row  0 ( x % 16 != 0)

@test_lines:
	; X = how many lines of tiles to test
	lda player0 + PLAYER::levely
	and #%00001111
	bne @yfloat				; if player is not on a multiple of 16 (tile size)
@yint:
	lda #02					; test 2 lines ( y % 16 == 0)
	sta r1L
	stx r1H
	sty r2L
	rts
@yfloat:
	lda #03					; test 3 rows ( y % 16 <> 0)
	sta r1L
	stx r1H
	sty r2L
	rts

;************************************************
; check collision on the height
;	A = vaule of the collision
;	ZERO = no collision
;
check_collision_height:
	; only test if we are 'centered'
	lda player0 + PLAYER::levelx
	and #%00001111
	cmp #08
	bne @no_collision

	lda player0 + PLAYER::tilemap
	sta r0L
	lda player0 + PLAYER::tilemap + 1
	sta r0H

	jsr bbox_coverage
	ldx r1L				; tiles height
	tya
	clc
	adc test_right_left
	tay

@test_line:
	lda (r0L),y
	beq @test_next_line

	; some tiles are not real collision 
	sty $30
	tay
	lda tiles_attributes,y
	and #TILE_ATTR::SOLID_WALL
	beq @test_next_line1
	ldy $30
	lda (r0L),y
	rts

@test_next_line1:
	ldy $30

@test_next_line:
	dex
	beq @no_collision
	tya
	clc
	adc #LEVEL_TILES_WIDTH			; test the tile on the right of the player (hip position)
	tay
	bra @test_line					; LADDERS can be traversed

@no_collision:						; force a no collision
	lda #00
@return:
	rts

;************************************************
; check collision on the right
;	return: A = value of the collision
;			ZERO = no collision
;
check_collision_right:
	lda #$01
	sta test_right_left
	jsr check_collision_height
	rts

;************************************************
; check collision on the left
;
check_collision_left:
	lda #$ff
	sta test_right_left
	jsr check_collision_height
	rts

;************************************************
; check collision down
;	collision surface to test is 16 pixels around the mid X
; 	output : Z = no collision
;
check_collision_down:
	lda player0 + PLAYER::levely	; if the player is inbetween 2 tiles there can be no collision
	and #%00001111
	beq @real_test
	lda #00
	rts
@real_test:	
	lda player0 + PLAYER::tilemap
	sta r0L
	lda player0 + PLAYER::tilemap + 1
	sta r0H

	jsr bbox_coverage
	tya 
	clc
	adc #(LEVEL_TILES_WIDTH * 2)	; check below the player
	tay

@test_colum:
	lda (r0L),y
	beq @next_colum							; empty tile, test the next one

	sty $30
	tay
	lda tiles_attributes,y
	and #TILE_ATTR::SOLID_GROUND
	bne @return1							; considere slopes as empty
	ldy $30

@next_colum:
	dex
	beq @return
	iny
	bra @test_colum					
@return1:
	lda #01
@return:
	rts

;************************************************
; check collision up
;	collision surface to test is 16 pixels around the mid X
;	input :
;		r0 : @ of current tile the top-left corner of the player sprite
; 	output : Z = no collision
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
	beq @xint				; if player is not on a multiple of 16 (tile size)
@xfloat:
	cmp #8
	bmi @xint
	ldx #1					; test 1 column ( y % 16 <> 0)
	ldy #1					; starting at colum + 1
	bra @test_colum
@xint:
	ldx #2					; test 2 columns ( y % 16 == 0)
	ldy #0					; starting at colum
	bra @test_y

@test_y:
	; Y = how tile rows to test
	lda player0 + PLAYER::levely
	and #%00001111
	beq @yint				; if player is not on a multiple of 16 (tile size)
@yfloat:
	tya
	adc #(LEVEL_TILES_WIDTH * 2)	; test on (row -1) +1 ( x % 16 != 0) + column
	tay
	bra @test_colum
@yint:

@test_colum:
	lda (r0L),y							; left side
	beq @next_column

	sty $30
	tay
	lda tiles_attributes,y
	and #TILE_ATTR::SOLID_CEILING
	bne @return1
	ldy $30

@next_column:	
	dex
	beq @return
	iny
	bra @test_colum
@return1:
	lda #01
@return:
	rts

;************************************************
; check if the player feet is exactly on a slope tile
;	modify: player_on_slop
;	return: Z = slop
;			Y = feet position tested (vs r0)
;
check_player_on_slop:
	stz player_on_slop				; no slope

	jsr bbox_coverage

	clc
	tya
	ldx r1L							
	dex
:
	adc #LEVEL_TILES_WIDTH
	dex
	bne :-
	tay								; position of the feet tiles

	lda player0 + PLAYER::levelx
	and #%00001111
	cmp #08
	bpl :+
	iny
:

	; check if player feet is ON a slop
	lda (r0),y						; test ON feet level
	cmp #TILE_SOLD_SLOP_LEFT
	beq @on_slope
	cmp #TILE_SOLD_SLOP_RIGHT
	bne @no_slope
@on_slope:
	lda (r0),y						; test ON feet level
	sta player_on_slop
	rts

@no_slope:
	lda #0
	sta player_on_slop
	rts

;************************************************
; check if the player feet is ABOVE a slope tile
;	input: 	Y = feet position tested (vs r0)
;	modify: player_on_slop
;	return: Z = slop
;
is_player_above_slop:
	stz player_on_slop				; no slope

	tya
	clc
	adc #LEVEL_TILES_WIDTH
	tay								; test BELOW feet level
	lda (r0),y						
	cmp #TILE_SOLD_SLOP_LEFT
	beq @above_slope
	cmp #TILE_SOLD_SLOP_RIGHT
	beq @above_slope
@no_slope:
	lda #0
	sta player_on_slop
	rts
@above_slope:
	sta player_on_slop
	rts

;************************************************
; status to ignore while moving
;
ignore_move_request:
	.byte	00	;	STATUS_WALKING_IDLE
	.byte	00	;	STATUS_WALKING
	.byte	02	;	STATUS_CLIMBING
	.byte	02	;	STATUS_CLIMBING_IDLE
	.byte	01	;	STATUS_FALLING
	.byte	01	;	STATUS_JUMPING
	.byte	01	;	STATUS_JUMPING_IDLE

;************************************************
; Try to move player to the right, walk up if facing a slope
;	
move_right:
	ldy player0 + PLAYER::status
	lda ignore_move_request, y
	beq @walk_right					; if 0 => can move
	cmp #02							
	beq @climb_right				; if 2 => has to climb
	bra @return1					; else block the move

@walk_right:
	jsr check_player_on_slop
	bne @no_collision

	jsr is_player_above_slop
	bne @no_collision

	jsr Player::check_collision_right
	bne @return1					; block is collision on the right  and there is no slope on the right

@no_collision:
	lda #01
	sta player0 + PLAYER::delta_x

@set_walking_sprite:
	lda #SPRITE_FLIP_H
	sta player0 + PLAYER::flip
	ldy player0 + PLAYER::sprite
	jsr Sprite::set_flip				; force sprite to look right

	m_status STATUS_WALKING

	;change player sprite
	lda #Player::Sprites::LEFT
	cmp player0 + PLAYER::spriteID
	beq @move_x
	
	lda #Player::Sprites::LEFT
	sta player0 + PLAYER::spriteID
	jsr set_bitmap

@move_x:
	jsr Player::position_x_inc		; move the player in the level, and the screen layers and sprite

	; if sitting on a slop
	lda player_on_slop
	beq @set_position
	cmp #TILE_SOLD_SLOP_RIGHT
	beq @move_y_up
@try_move_y_dow:
	lda player0 + PLAYER::levely
	and #%00001111
	bne @move_y_down
	lda player0 + PLAYER::tilemap
	sta r0L
	lda player0 + PLAYER::tilemap+1
	sta r0H
	lda r2L
	clc
	adc #(LEVEL_TILES_WIDTH * 2 + 1)	; check on the 2nd block
	tay
	lda (r0), y							; check if the tile below as an attribute SOLID_GROUND
	tay
	lda tiles_attributes,y
	and #TILE_ATTR::SOLID_GROUND
	bne @return							; do not change Y if the tile below the player is a solid one
@move_y_down:
	jsr position_y_inc
	bra @set_position
@move_y_up:
	jsr position_y_dec

@set_position:
	jsr position_set
@return1:
	rts

@climb_right:
	jsr Player::check_collision_right
	beq @climb_right_1
	cmp #TILE_SOLID_LADER
	beq @climb_right_1
	rts
@climb_right_1:
	jsr bbox_coverage
@get_tile:
	lda (r0),y
	beq @no_grab					; no tile on right
	sta $31
	sty $30
	tay
	lda tiles_attributes,y
	and #TILE_ATTR::GRABBING
	bne @climb_right_2				; tile on right with a GRAB attribute
	ldy $30
@no_grab:							; test the tile on the right on next line
	iny
	dex
	bne @get_tile
	bra @climb_right_drop			; no grab tile on the right of the player
@climb_right_2:
	lda $31							; tile index with grab attribute
	cmp #TILE_LEDGE
	bne @set_climb_sprite
@set_hang_sprite:
	lda #Player::Sprites::HANG
	bra @next
@set_climb_sprite:
	lda #Player::Sprites::CLIMB
@next:
	sta player0 + PLAYER::spriteID
	jsr set_bitmap
	m_status STATUS_CLIMBING
	jsr Player::position_x_inc		; move the player sprite, if the 
	jsr position_set
	rts
@climb_right_drop:
	m_status STATUS_WALKING
	SET_SPRITE Player::Sprites::LEFT, 1

@return:
	rts

;************************************************
; try to move the player to the left
;	
move_left:
	ldy player0 + PLAYER::status
	lda ignore_move_request, y
	beq @walk_left					; if 0 => can move
	cmp #02							
	beq @climb_left				; if 2 => has to climb
	bra @return					; else block the move

@walk_left:
	jsr check_player_on_slop
	bne @no_collision				; ignore right collision left if on a slope

	jsr is_player_above_slop
	bne @no_collision

	jsr Player::check_collision_left
	bne @return						; block is collision on the right  and there is no slope on the right

@no_collision:
	lda #$ff
	sta player0 + PLAYER::delta_x

@set_walking_sprite:
	lda #SPRITE_FLIP_NONE
	sta player0 + PLAYER::flip
	ldy player0 + PLAYER::sprite
	jsr Sprite::set_flip				; force sprite to loop right

	m_status STATUS_WALKING

	lda #Player::Sprites::LEFT
	cmp player0 + PLAYER::spriteID
	beq @move_x
	
	;change player sprite
	lda #Player::Sprites::LEFT
	sta player0 + PLAYER::spriteID
	jsr set_bitmap
	
@move_x:
	jsr Player::position_x_dec

	lda player_on_slop				; if walking a slop also increase Y
	beq @set_position
	cmp #TILE_SOLD_SLOP_LEFT
	beq @move_y_up
@try_move_y_dow:
	lda player0 + PLAYER::levely
	and #%00001111
	bne @move_y_down
	lda player0 + PLAYER::tilemap
	sta r0L
	lda player0 + PLAYER::tilemap+1
	sta r0H
	lda r2L
	clc
	adc #(LEVEL_TILES_WIDTH * 2)
	tay
	lda (r0), y							; check if the tile below as an attribute TILE_SOLID_GROUND
	tay
	lda tiles_attributes,y
	and #TILE_ATTR::SOLID_GROUND
	bne @return							; do not change Y if the tile below the player is a solid one
@move_y_down:
	jsr position_y_inc
	bra @set_position
@move_y_up:
	jsr position_y_dec

@set_position:
	jsr position_set
	
@return:
	rts

@climb_left:
	jsr Player::check_collision_left
	beq @climb_left_1
	rts								; collision on left, block the move
@climb_left_1:
	jsr bbox_coverage				; what tiles is the player covering
@get_tile:
	lda (r0),y
	beq @no_grab					; no tile on right
	sta $31
	sty $30
	tay
	lda tiles_attributes,y
	and #TILE_ATTR::GRABBING
	bne @climb_left_2				; tile on left with a GRAB attribute
	ldy $30
@no_grab:							; test the tile on the left on next line
	iny
	dex
	bne @get_tile
	bra @climb_left_drop			; no grab tile on the right of the player
@climb_left_2:
	lda $31							; tile index with grab attribute
	cmp #TILE_LEDGE
	bne @set_climb_sprite
@set_hang_sprite:
	lda #Player::Sprites::HANG
	bra @next
@set_climb_sprite:
	lda #Player::Sprites::CLIMB
@next:
	sta player0 + PLAYER::spriteID
	jsr set_bitmap
	m_status STATUS_CLIMBING
	jsr Player::position_x_dec		; move the player sprite, if the 
	jsr position_set
	rts
@climb_left_drop:					; no ladder to stick to
	m_status STATUS_WALKING
	SET_SPRITE Player::Sprites::LEFT, 1
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
	; custom collision down
	lda player0 + PLAYER::tilemap
	sta r0L
	lda player0 + PLAYER::tilemap + 1
	sta r0H

	jsr bbox_coverage
	stx ladders						; width of the player in tiles = number of ladders to find below
	tya 
	clc
	adc #(LEVEL_TILES_WIDTH * 2)	; check below the player
	tay

@test_colum:
	lda (r0L),y
	cmp #TILE_SOLID_LADER
	bne @check_solid_ground
@ladder_down:
	dec ladders
	bra @next_column
@check_solid_ground:
	sty $30
	tay
	lda tiles_attributes,y
	and #TILE_ATTR::SOLID_GROUND
	bne @cannot_move_down
	ldy $30
@next_column:	
	dex 
	beq @end
	iny
	bra @test_colum
@end:

	lda ladders
	beq @move_down						; correct number of ladder tiles below the player

	; if there player is covering ANY ladders (accros the boundingbox)
	ldy r2L
@check_line:							; already climbing down is player grabbing no ladder
	ldx r1H
@check_row:
	lda (r0L),y
	cmp #TILE_SOLID_LADER
	beq @move_down
	iny
	dex
	bne @check_row
	dec r1L
	beq @cannot_move_down

	tya
	clc
	adc #LEVEL_TILES_WIDTH
	sec
	sbc r1H
	tay
	bra @check_line

@move_down:
	jsr Player::position_y_inc		; move down the ladder
	jsr position_set

	m_status STATUS_CLIMBING

	lda #Player::Sprites::CLIMB
	cmp player0 + PLAYER::spriteID
	bne @change_sprite
	rts

@change_sprite:
	;change player sprite
	lda #Player::Sprites::CLIMB
	sta player0 + PLAYER::spriteID
	jsr set_bitmap
	rts

@cannot_move_down:
	lda #STATUS_WALKING_IDLE
	sta player0 + PLAYER::status
	lda #01
	sta player0 + PLAYER::spriteAnim
	jsr set_bitmap
	stz player0 + PLAYER::delta_x
	rts

;************************************************
; try to move the player up (move up a ladder)
;	only climb a ladder if the 16 pixels mid-X are fully enclosed in the ladder
;	modify: r0, r1, r2
;	
move_up:
	lda player0 + PLAYER::status
	cmp #STATUS_FALLING
	bne @try_move_up				; cannot move when falling
	rts
@try_move_up:
	; custom collision up
	jsr bbox_coverage
	stx ladders						; width of the player in tiles = number of ladders to find below

	; check the situation ABOVE the player
	sec
	lda player0 + PLAYER::tilemap
	sbc #LEVEL_TILES_WIDTH
	sta r0L
	lda player0 + PLAYER::tilemap+1
	sbc #0
	sta r0H

	; if there the right numbers of ladder tiles above the player
@test_colum:
	lda (r0L),y
	cmp #TILE_SOLID_LADER
	bne @check_solid_ceiling
	dec ladders
	bra @next_column
@check_solid_ceiling:
	sty $30
	tay
	lda tiles_attributes,y
	and #TILE_ATTR::SOLID_CEILING
	bne @cannot_move_up
	ldy $30
@next_column:
	dex 
	beq @end
	iny
	bra @test_colum
@end:

	lda ladders
	beq @climb_down						; correct number of ladder tiles above the player

	; if there player is covering ANY LADER (accros the boundingbox)
	lda player0 + PLAYER::tilemap
	sta r0L
	lda player0 + PLAYER::tilemap+1
	sta r0H

	ldy r2L
@check_line:							; already climbing up is player grabbing no ladder
	ldx r1H
@check_row:
	lda (r0L),y
	cmp #TILE_SOLID_LADER
	beq @climb_down
	iny
	dex
	bne @check_row
	dec r1L
	beq @cannot_move_up

	tya
	clc
	adc #LEVEL_TILES_WIDTH
	sec
	sbc r1H
	tay
	bra @check_line

@climb_down:
	jsr Player::position_y_dec		; move up the ladder
	jsr position_set

	m_status STATUS_CLIMBING

	lda #Player::Sprites::CLIMB
	cmp player0 + PLAYER::spriteID
	bne @set_sprite
	rts
@set_sprite:						;change player sprite
	lda #Player::Sprites::CLIMB
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
	tax
    ldy player0 + PLAYER::status
	lda ignore_move_request,y
	bne @return
	stx player0 + PLAYER::delta_x

	; ensure there is no ceiling over the player
	jsr check_collision_up
	bne @return

	lda #JUMP_LO_TICKS
	sta player0 + PLAYER::falling_ticks	; decrease  HI every 10 refresh
	lda #JUMP_HI_TICKS
	sta player0 + PLAYER::falling_ticks	+ 1

	m_status STATUS_JUMPING
@return:
	rts

.endscope
