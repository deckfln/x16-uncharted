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

PLAYER_ZP = $0050

PNG_SPRITES_LINES = 5
PNG_SPRITES_COLUMNS = 3

.enum
	STATUS_WALKING_IDLE
	STATUS_WALKING
	STATUS_CLIMBING
	STATUS_CLIMBING_IDLE
	STATUS_FALLING
	STATUS_JUMPING
	STATUS_JUMPING_IDLE
	STATUS_PUSHING
.endenum

.enum
	SITTING_NO_SLOP
	SITTING_ON_SLOPE
	SITTING_ABOVE_SLOPE
.endenum

.struct PLAYER
	entity			.tag Entity
	animation_tick	.byte
	frameID 		.byte	; current animation loop start
	frame 			.byte	; current frame
	frameDirection 	.byte 	; direction of the animation
	flip 			.byte
	grab_object		.word	; address of the object currently grabbed
	vera_bitmaps    .res 	(2 * 3 * 5)	; 9 words to store vera bitmaps address
.endstruct

.macro m_status value
	lda #(value)
	sta player0 + PLAYER::entity + Entity::status
.endmacro

.scope Player

.macro SET_SPRITE id, frameval
	lda #id
	sta player0 + PLAYER::frameID
	lda #frameval
	sta player0 + PLAYER::frame
	jsr set_bitmap
.endmacro

;************************************************
; player sprites status
;
.enum Sprites
	FRONT = 0
	LEFT = FRONT + PNG_SPRITES_COLUMNS
	CLIMB = LEFT + PNG_SPRITES_COLUMNS
	HANG = CLIMB + PNG_SPRITES_COLUMNS
	PUSH = HANG + PNG_SPRITES_COLUMNS
.endenum

WIDTH = 16
HEIGHT = 32

;************************************************
; local variables
;

ladders: .byte 0
test_right_left: .byte 0

;************************************************
; init the player data
;
init:
	ldx #00
	lda #<player0
	sta r3L
	ldy #>player0
	sty r3H
	jsr Entities::register

	jsr Entities::init

	lda #10
	ldy #PLAYER::animation_tick
	sta (r3), y
	lda #Player::Sprites::LEFT
	ldy #PLAYER::frameID
	sta (r3), y
	lda #00
	ldy #PLAYER::frame
	sta (r3), y
	lda #1
	ldy #PLAYER::frameDirection
	sta (r3), y
	lda #00
	ldy #PLAYER::flip
	sta (r3), y

	; player sprite is 32x32, but collision box is 16x32
	ldy #Entity::bWidth				
	lda #Player::WIDTH
	sta (r3), y
	ldy #Entity::bHeight
	lda #Player::HEIGHT
	sta (r3), y

	; player collision box is shifted by (8,0) pixels compared to sprite top-left corner
	lda #08
	ldy #Entity::bXOffset
	sta (r3), y
	lda #00
	ldy #Entity::bYOffset
	sta (r3), y

	; load sprites data at the end of the tiles
	VLOAD_FILE fssprite, (fsspriteend-fssprite), (::VRAM_tiles + tiles * tile_size)

	lda player0 + PLAYER::vera_bitmaps
	sta r0L
	lda player0 + PLAYER::vera_bitmaps+1
	sta r0H

	lda (r3)
	tay
	lda #%00010000					; collision mask 1
	ldx #%10100000					; 32x32 sprite
	jsr Sprite::load

	lda #08
	sta r0L
	lda #00
	sta r0H
	lda #15
	sta r1L
	lda #31
	sta r1H

	lda (r3)
	tay
	jsr Sprite::set_aabb			; collision box (8,0) -> (24, 32)

	; turn sprite 0 on
	lda (r3)
	tay
	ldx #SPRITE_ZDEPTH_TOP
	jsr Sprite::display

	; register the vera simplified memory 12:5
	ldy #(PNG_SPRITES_COLUMNS * PNG_SPRITES_LINES)
	sty PLAYER_ZP
	ldy #PLAYER::vera_bitmaps
	LOAD_r1 (::VRAM_tiles + tiles * tile_size)

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
	sta (r3), y
	iny
	lda r0L
	sta (r3), y
	iny

	; increase the vram (+4 r1H = +1024 r1)
	clc
	lda r1H
	adc #4
	sta r1H

	dec PLAYER_ZP
	bne @loop

	; set first bitmap
	jsr set_bitmap
	rts
	
;************************************************
; change the player bitmap
;	
set_bitmap:
	clc
	lda player0 + PLAYER::frame
	adc player0 + PLAYER::frameID
	asl						; convert sprite index to work position
	tax

	; extract the vera bitmap address in vera format (12:5 bits)
	lda player0 + PLAYER::vera_bitmaps, x
	sta r0H
	lda player0 + PLAYER::vera_bitmaps + 1, x
	sta r0L

	ldy player0 + PLAYER::entity + Entity::spriteID
	jsr Sprite::set_bitmap
	rts
	
;************************************************
; move layers if the player sprite reached the screen boundaries
;	
check_scroll_layers:
	; distance from layer border to sprite absolute position
	sec
	lda player0 + PLAYER::entity + Entity::levelx 
	sbc Layers::wHScroll
	sta r0L
	lda player0 + PLAYER::entity + Entity::levelx + 1
	sbc Layers::wHScroll + 1
	sta r0H									; r0 = dx = level.x - layer.x

	bne @check_right						; dx > 256, no need to check left
@check_left:
	lda r0L
	cmp #64
	bcs @check_right						; dx > 96 and dx < 256, no need to check left
	; are we on far left of the layer ?
	lda Layers::wHScroll + 1
	bne @scroll_layer_left					; H_SCROLL > 256, scroll layer
	lda Layers::wHScroll
	beq @set_x_0							; H_SCROLL == 0 => NO horizontal scroll
@scroll_layer_left:
	sec
	lda player0 + PLAYER::entity + Entity::levelx 
	sbc #64
	tax
	lda player0 + PLAYER::entity + Entity::levelx + 1
	sbc #00
	tay
	bra @fix_layer_0_x
@set_x_0:
	ldx #00
	ldy #00
@fix_layer_0_x:
	jsr Layers::set_x
	bra @check_top

@check_right:
	lda r0L
	cmp #<(SCREEN_WIDTH - 63 - Player::WIDTH)		; remove the width of the sprite
	bcc @check_top							; dx < 320 - 96, no need to check right
	; are we on far right of the layer ?
	lda Layers::wHScroll
	cmp #(32*16-320 - 1)
	bcs @set_x_max							; H_SCROLL > 192 (512 - 320) => force max

	sec
	lda player0 + PLAYER::entity + Entity::levelx 
	sbc #<(320 - 64 - Player::WIDTH)
	tax
	lda player0 + PLAYER::entity + Entity::levelx + 1
	sbc #>(320 - 64 - Player::WIDTH)
	tay
	bra @fix_layer_0_x
@set_x_max:
	ldx #<(32*16-320)
	ldy #>(32*16-320)
	bra @fix_layer_0_x

@check_top:
	; distance from layer border to sprite absolute position
	sec
	lda player0 + PLAYER::entity + Entity::levely
	sbc Layers::wVScroll
	sta r0L
	lda player0 + PLAYER::entity + Entity::levely + 1
	sbc Layers::wVScroll + 1
	sta r0H									; r0 = dy = level.y - layer.y

	bne @check_bottom						; dy > 256, no need to check top
@check_top_1:
	lda r0L
	cmp #Player::HEIGHT
	bcs @check_bottom						; dy > 96 and dy < 256, check bottom
@move_y:
	; are we on far top of the layer ?
	lda Layers::wVScroll + 1
	bne @scroll_layer_top					; V_SCROLL > 256, scroll layer
	lda Layers::wVScroll
	beq @set_y_0							; V_SCROLL == 0 => NO vertical scroll
@scroll_layer_top:
	sec
	lda player0 + PLAYER::entity + Entity::levely
	sbc #Player::HEIGHT
	tax
	lda player0 + PLAYER::entity + Entity::levely + 1
	sbc #00
	tay
	bra @fix_layer_0_y
@set_y_0:
	ldx #00
	ldy #00
@fix_layer_0_y:
	jsr Layers::set_y
	rts

@check_bottom:
	lda r0L
	cmp #<(240 - Player::HEIGHT * 2)
	bcs @scroll_bottom						
	rts										; dy < 144, no need to check vertical
@scroll_bottom:
	; are we on far bottom of the layer ?
	lda Layers::wVScroll + 1
	beq @scroll_layer_bottom				; V_SCROLL < 256, scroll layer
	lda Layers::wVScroll
	cmp #<(32*16-240 - 1)
	bcs @set_y_max							; V_SCROLL == 512-240 => NO vertical scroll
@scroll_layer_bottom:
	sec
	lda player0 + PLAYER::entity + Entity::levely
	sbc #<(240 - Player::HEIGHT*2)
	tax
	lda player0 + PLAYER::entity + Entity::levely + 1
	sbc #>(240 - Player::HEIGHT*2)
	tay
	bra @fix_layer_0_y
@set_y_max:
	ldx #<(32*16-240)
	ldy #>(32*16-240)
	bra @fix_layer_0_y

;************************************************
; hide the current sprite
;
hide1:
	stp
	clc
	lda player0 + PLAYER::frame
	adc player0 + PLAYER::frameID
	tay		; sprite index
	ldx #SPRITE_ZDEPTH_DISABLED
	jsr Sprite::display			; turn current sprite off
	rts
	
;************************************************
; Animate the player if needed
;		
animate:
	lda player0 + PLAYER::entity + Entity::status
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
	lda player0 + PLAYER::frame
	adc player0 + PLAYER::frameDirection
	beq @set_sprite_anim_increase					; reached 0
	cmp #3
	beq @set_sprite_anim_decrease
	bra @set_sprite_on
@set_sprite_anim_increase:
	lda #01
	sta player0 + PLAYER::frameDirection
	lda #0
	bra @set_sprite_on
@set_sprite_anim_decrease:
	lda #$ff
	sta player0 + PLAYER::frameDirection
	lda #2
@set_sprite_on:
	sta player0 + PLAYER::frame	; turn next sprite on
	jsr Player::set_bitmap
@end:
	rts
	
;************************************************
; force player status to be idle
;	
set_idle:
	lda player0 + PLAYER::entity + Entity::status
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
	; only move if the status is compatible
	ldy player0 + PLAYER::entity + Entity::status
	lda ignore_move_request, y
	beq @walk_right					; if 0 => can move
	cmp #02							
	beq :+							; if 2 => has to climb
	rts								; else block the move
:
	jmp @climb_right

@walk_right:
	ldx #00
	jsr Entities::move_right
	beq @set_walking_sprite
	cmp #$ff
	bne @blocked_not_border
	rts							; reached right border

@blocked_not_border:
	lda player0 + PLAYER::entity + Entity::collision_addr
	sta r0L
	lda player0 + PLAYER::entity + Entity::collision_addr + 1
	sta r0H

	jsr Entities::if_on_slop
	bne @no_collision
	rts							; blocked by tile

@no_collision:
	lda #01
	sta player0 + PLAYER::entity + Entity::delta_x

@set_walking_sprite:
	lda #SPRITE_FLIP_H
	sta player0 + PLAYER::flip
	ldy player0 + PLAYER::entity + Entity::spriteID
	jsr Sprite::set_flip				; force sprite to look right

	m_status STATUS_WALKING

	;change player sprite
	lda #Player::Sprites::LEFT
	cmp player0 + PLAYER::frameID
	beq @check_slope
	
	lda #Player::Sprites::LEFT
	sta player0 + PLAYER::frameID
	jsr set_bitmap

@check_slope:
	; if sitting on a slop
	jsr Entities::if_on_slop
	bne @move_slop

	; TODO ///////////////////////
	jsr Entities::get_collision_map
	jsr Entities::if_above_slop			; check if NOW were are above a slope
	beq @set_position
	; TODO \\\\\\\\\\\\\\\\\\\\\\\\\\

@move_slop:
	cmp #TILE_SOLD_SLOP_RIGHT
	beq @move_y_up
@try_move_y_dow:
	lda player0 + PLAYER::entity + Entity::levely
	and #%00001111
	bne @move_y_down
	lda player0 + PLAYER::entity + Entity::collision_addr
	sta r0L
	lda player0 + PLAYER::entity + Entity::collision_addr + 1
	sta r0H
	lda r2L
	clc
	adc #(LEVEL_TILES_WIDTH * 2 + 1)	; check on the 2nd block
	tay
	lda (r0), y							; check if the tile below as an attribute SOLID_GROUND
	tay
	lda tiles_attributes,y
	bit #TILE_ATTR::SOLID_GROUND
	bne @return							; do not change Y if the tile below the player is a solid one
@move_y_down:
	jsr Entities::position_y_inc
	bra @set_position
@move_y_up:
	lda player0 + PLAYER::entity + Entity::levelx
	and #%00001111
	cmp #08
	bne :+							
	lda player0 + PLAYER::entity + Entity::levely
	and #%00001111
	beq @return1						; if x%8 == 0, y MUST be equal 0, or increase
:
	jsr Entities::position_y_dec

@set_position:
@return1:
	rts

@climb_right:
	jsr Entities::check_collision_right
	beq @climb_right_1
	cmp #TILE_SOLID_LADER
	beq @climb_right_1
	rts
@climb_right_1:
	jsr Entities::bbox_coverage

	ldx #01
	ldy #00
	lda player0 + PLAYER::entity + Entity::levelx
	and #%00001111
	beq @get_tile
	inx								; if x%8 <> 0, test 2 tiles
@get_tile:
	lda (r0),y
	beq @no_grab					; no tile on right
	sta $31
	sty $30
	tay
	lda tiles_attributes,y
	bit #TILE_ATTR::GRABBING
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
	sta player0 + PLAYER::frameID
	jsr set_bitmap
	m_status STATUS_CLIMBING
	jsr Entities::position_x_inc		; move the player sprite, if the 
	;TODO ///////////////////////
	lda player0 + PLAYER::entity + Entity::bFlags
	ora #(EntityFlags::physics)
	sta player0 + PLAYER::entity + Entity::bFlags	; activate physics engine
	;TODO ///////////////////////
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
	; only move if the status is compatible
	ldy player0 + PLAYER::entity + Entity::status
	lda ignore_move_request, y
	beq @walk_left					; if 0 => can move
	cmp #02							
	bne :+							; if 2 => has to climb
	rts								; else block the move
:
	jmp @climb_left				

@walk_left:
	; try move from the parent class Entity
	ldx #00
	jsr Entities::move_left
	beq @set_walking_sprite
	cmp #$ff
	bne @blocked_not_border
	rts								; reached right border

@blocked_not_border:
	lda player0 + PLAYER::entity + Entity::collision_addr
	sta r0L
	lda player0 + PLAYER::entity + Entity::collision_addr + 1
	sta r0H

	jsr Entities::if_on_slop
	bne @no_collision				; ignore right collision left if on a slope
	rts								; blocked by tile

@no_collision:
	lda #$ff
	sta player0 + PLAYER::entity + Entity::delta_x

@set_walking_sprite:
	lda #SPRITE_FLIP_NONE
	sta player0 + PLAYER::flip
	ldy player0 + PLAYER::entity + Entity::spriteID
	jsr Sprite::set_flip				; force sprite to loop right

	m_status STATUS_WALKING

	lda #Player::Sprites::LEFT
	cmp player0 + PLAYER::frameID
	beq @check_slop
	
	;change player sprite
	lda #Player::Sprites::LEFT
	sta player0 + PLAYER::frameID
	jsr set_bitmap
	
@check_slop:
	jsr Entities::if_on_slop
	bne @move_slop

	; TODO ///////////////////////
	jsr Entities::get_collision_map
	jsr Entities::if_above_slop			; check if NOW were are above a slope
	beq @set_position
	; TODO \\\\\\\\\\\\\\\\\\\\\\\\\\

@move_slop:
	cmp #TILE_SOLD_SLOP_LEFT
	beq @move_y_up
@try_move_y_dow:
	lda player0 + PLAYER::entity + Entity::levely
	and #%00001111
	bne @move_y_down
	lda player0 + PLAYER::entity + Entity::collision_addr
	sta r0L
	lda player0 + PLAYER::entity + Entity::collision_addr + 1
	sta r0H
	lda r2L
	clc
	adc #(LEVEL_TILES_WIDTH * 2)
	tay
	lda (r0), y							; check if the tile below as an attribute TILE_SOLID_GROUND
	tay
	lda tiles_attributes,y
	bit #TILE_ATTR::SOLID_GROUND
	bne @set_position					; do not change Y if the tile below the player is a solid one
@move_y_down:
	jsr Entities::position_y_inc
	bra @set_position
@move_y_up:
	lda player0 + PLAYER::entity + Entity::levelx
	and #%00001111
	cmp #08
	bne :+							
	lda player0 + PLAYER::entity + Entity::levely
	and #%00001111
	beq @return							; if x%8 == 0, y MUST be equal 0, or increase
:
	jsr Entities::position_y_dec

@set_position:
@return:
	rts

@climb_left:
	jsr Entities::check_collision_left
	beq @climb_left_1
	rts								; collision on left, block the move
@climb_left_1:
	jsr Entities::bbox_coverage				; what tiles is the player covering

	ldx #01
	ldy #00
	lda player0 + PLAYER::entity + Entity::levelx
	and #%00001111
	beq @get_tile
	inx								; if x%8 <> 0, test 2 tiles
@get_tile:
	lda (r0),y
	beq @no_grab					; no tile on right
	sta $31
	sty $30
	tay
	lda tiles_attributes,y
	bit #TILE_ATTR::GRABBING
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
	sta player0 + PLAYER::frameID
	jsr set_bitmap
	m_status STATUS_CLIMBING
	jsr Entities::position_x_dec		; move the player sprite, if the 
	;TODO ///////////////////////
	lda player0 + PLAYER::entity + Entity::bFlags	; activate physics engine
	ora #(EntityFlags::physics)
	sta player0 + PLAYER::entity + Entity::bFlags	; activate physics engine
	;TODO ///////////////////////
	rts
@climb_left_drop:					; no ladder to stick to
	m_status STATUS_WALKING
	SET_SPRITE Player::Sprites::LEFT, 1
	rts

;************************************************
; try to move the player down (crouch, hide, move down a ladder)
;	
move_down:
	; r3 = *player
	lda #<player0
	sta r3L
	lda #>player0
	sta r3H

	lda player0 + PLAYER::entity + Entity::status
	cmp #STATUS_FALLING
	bne @try_move_down						; cannot move when falling
	rts

@try_move_down:
	; custom collision down
	lda player0 + PLAYER::entity + Entity::collision_addr
	sta r0L
	lda player0 + PLAYER::entity + Entity::collision_addr + 1
	sta r0H

	jsr Entities::bbox_coverage
	stx ladders						; width of the player in tiles = number of ladders to find below
	lda r2L 
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
	bit #TILE_ATTR::SOLID_GROUND
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
	jsr Entities::position_y_inc		; move down the ladder
	;TODO ///////////////////////
	lda player0 + PLAYER::entity + Entity::bFlags	; activate physics engine
	ora #(EntityFlags::physics)
	sta player0 + PLAYER::entity + Entity::bFlags	; activate physics engine
	;TODO ///////////////////////

	m_status STATUS_CLIMBING

	lda #Player::Sprites::CLIMB
	cmp player0 + PLAYER::frameID
	bne @change_sprite
	rts

@change_sprite:
	;change player sprite
	lda #Player::Sprites::CLIMB
	sta player0 + PLAYER::frameID
	jsr set_bitmap
	rts

@cannot_move_down:
	lda #STATUS_WALKING_IDLE
	sta player0 + PLAYER::entity + Entity::status
	lda #01
	sta player0 + PLAYER::frame
	jsr set_bitmap
	stz player0 + PLAYER::entity + Entity::delta_x
	rts

;************************************************
; try to move the player up (move up a ladder)
;	only climb a ladder if the 16 pixels mid-X are fully enclosed in the ladder
;	modify: r0, r1, r2
;	
move_up:
	; r3 = *player
	lda #<player0
	sta r3L
	lda #>player0
	sta r3H

	lda player0 + PLAYER::entity + Entity::status
	cmp #STATUS_FALLING
	bne @try_move_up				; cannot move when falling
	rts
@try_move_up:
	; custom collision up
	jsr Entities::bbox_coverage
	ldy r2L
	stx ladders						; width of the player in tiles = number of ladders to find below

	; check the situation ABOVE the player
	sec
	lda player0 + PLAYER::entity + Entity::collision_addr
	sbc #LEVEL_TILES_WIDTH
	sta r0L
	lda player0 + PLAYER::entity + Entity::collision_addr + 1
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
	bit #TILE_ATTR::SOLID_CEILING
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
	lda player0 + PLAYER::entity + Entity::collision_addr
	sta r0L
	lda player0 + PLAYER::entity + Entity::collision_addr + 1
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
	jsr Entities::position_y_dec		; move up the ladder
	;TODO ///////////////////////
	lda player0 + PLAYER::entity + Entity::bFlags	; activate physics engine
	ora #(EntityFlags::physics)
	sta player0 + PLAYER::entity + Entity::bFlags	; activate physics engine
	;TODO ///////////////////////

	m_status STATUS_CLIMBING

	lda #Player::Sprites::CLIMB
	cmp player0 + PLAYER::frameID
	bne @set_sprite
	rts
@set_sprite:						;change player sprite
	lda #Player::Sprites::CLIMB
	sta player0 + PLAYER::frameID
	jsr set_bitmap
	rts

@cannot_move_up:
	lda #STATUS_WALKING_IDLE
	sta player0 + PLAYER::entity + Entity::status
	rts

;************************************************
; jump
;	input: A = delta X value
;
jump:
	tax

	; r3 = *player
	lda #<player0
	sta r3L
	lda #>player0
	sta r3H

    ldy player0 + PLAYER::entity + Entity::status
	lda ignore_move_request,y
	bne @return
	stx player0 + PLAYER::entity + Entity::delta_x

	; ensure there is no ceiling over the player
	jsr Entities::check_collision_up
	bne @return

	lda #JUMP_LO_TICKS
	sta player0 + PLAYER::entity + Entity::falling_ticks	; decrease  HI every 10 refresh
	lda #JUMP_HI_TICKS
	sta player0 + PLAYER::entity + Entity::falling_ticks	+ 1


	ldy #Entity::bFlags
	lda (r3),y
	ora #EntityFlags::physics
	sta (r3),y						; engage physics engine for that entity

	m_status STATUS_JUMPING
@return:
	rts

;************************************************
; grab the object if front of the player, if there is an object
;
grab_object:
	lda player0 + PLAYER::flip
	bne @right
@left:
	lda #(02 | 08)
	bra @cont
@right:
	lda #(02 | 04)
@cont:
	ldx player0 + PLAYER::entity + Entity::spriteID
	jsr Sprite::precheck_collision	; get the frameID in Y
	bmi @return						; no object

	jsr Objects::get_by_spriteID	; find the object that has frameID Y
	cpy #$ff
	beq @return						; no object with this ID

	tya
	adc #Objects::Object::imageID
	tya
	lda (r3), y
	bit #Objects::Attribute::GRAB
	beq @return						; object cannot be grabbed

	sty PLAYER_ZP					; save the pointer to the grabbed object
	clc
	lda r3L
	adc PLAYER_ZP
	sta player0 + PLAYER::grab_object
	lda r3H
	adc #00
	sta player0 + PLAYER::grab_object + 1

	lda #Player::Sprites::PUSH
	sta player0 + PLAYER::frameID
	stz player0 + PLAYER::frame
	lda #10
	sta player0 + PLAYER::animation_tick	; reset animation tick counter
	lda #01
	sta player0 + PLAYER::frameDirection
	jsr set_bitmap

	m_status STATUS_PUSHING

@return:
	rts

;************************************************
; release the object the player is moving
;
release_object:
	stz player0 + PLAYER::grab_object
	stz player0 + PLAYER::grab_object + 1
	m_status STATUS_WALKING_IDLE

	lda #Player::Sprites::LEFT
	sta player0 + PLAYER::frameID
	stz player0 + PLAYER::frame
	lda #10
	sta player0 + PLAYER::animation_tick	; reset animation tick counter
	lda #01
	sta player0 + PLAYER::frameDirection
	jsr set_bitmap

	rts

.endscope
