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
addrSaveR0L = PLAYER_ZP + 1
addrSaveR0H = addrSaveR0L + 1

; variable for move_up/down for ladders
laddersNeeded = PLAYER_ZP
tileStart = PLAYER_ZP + 1
laddersFound = PLAYER_ZP + 2
tilesHeight = PLAYER_ZP + 3

PNG_SPRITES_LINES = 8
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
	STATUS_SWIMING
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
	grab_left_right .byte	; grabbed object is on the lef tor on the right
	vera_bitmaps    .res 	(2 * 3 * 8)	; 9 words to store vera bitmaps address
.endstruct

player0 = $0500
player0_end = player0 + .sizeof(PLAYER)

; Virtual functions table
fnJump_table = player0 + .sizeof(PLAYER)
fnGrab_table = fnJump_table + 2
fnAnimate_table = fnGrab_table + 2

.macro m_status value
	lda #(value)
	sta player0 + PLAYER::entity + Entity::status
.endmacro

.scope Player

bCollisionID = PLAYER_ZP

.macro SET_SPRITE id, frameval
	lda #id
	sta player0 + PLAYER::frameID
	lda #frameval
	sta player0 + PLAYER::frame
	jsr Player::set_bitmap
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
	PULL = PUSH + PNG_SPRITES_COLUMNS
	SWIM = PULL + PNG_SPRITES_COLUMNS
	SWIM_OUT_WATER = SWIM + PNG_SPRITES_COLUMNS
.endenum

.enum Grab
	NONE = 0
	LEFT = 1
	RIGHT = 2
.endenum

WIDTH = 16
HEIGHT = 32

;************************************************
; local variables
;

ladders: .byte 0
test_right_left: .byte 0

.include "player/climb.asm"

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
	stz player0 + PLAYER::entity + Entity::id

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
	lda #00
	ldy #PLAYER::grab_left_right
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

	; register virtual function bind/unbind
	lda #<Player::unbind
	sta Entities::fnUnbind_table
	lda #>Player::unbind
	sta Entities::fnUnbind_table+1

	; register virtual function physics
	lda #<Player::physics
	sta Entities::fnPhysics_table
	lda #>Player::physics
	sta Entities::fnPhysics_table+1

	; register virtual function move_right/left
	lda #<move_right
	sta Entities::fnMoveRight_table
	lda #>move_right
	sta Entities::fnMoveRight_table+1
	lda #<move_left
	sta Entities::fnMoveLeft_table
	lda #>move_left
	sta Entities::fnMoveLeft_table+1

	; register virtual function move_up/down
	lda #<Player::move_up
	sta Entities::fnMoveUp_table
	lda #>Player::move_up
	sta Entities::fnMoveUp_table+1
	lda #<Player::move_down
	sta Entities::fnMoveDown_table
	lda #>Player::move_down
	sta Entities::fnMoveDown_table+1

	; register virtual function jump
	lda #<Player::jump
	sta fnJump_table
	lda #>Player::jump
	sta fnJump_table+1

	; register virtual function grab
	lda #<Player::grab_object
	sta fnGrab_table
	lda #>Player::grab_object
	sta fnGrab_table+1

	; register virtual function animate
	lda #<Player::animate
	sta fnAnimate_table
	lda #>Player::animate
	sta fnAnimate_table+1

	; load sprites data at the end of the tiles
	VLOAD_FILE fssprite, (fsspriteend-fssprite), (::VRAM_tiles + tiles * tile_size)

	lda player0 + PLAYER::vera_bitmaps
	sta r0L
	lda player0 + PLAYER::vera_bitmaps+1
	sta r0H

	ldy #Entity::spriteID
	lda (r3),y
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

	ldy #Entity::spriteID
	lda (r3),y
	tay
	jsr Sprite::set_aabb			; collision box (8,0) -> (24, 32)

	; turn sprite 0 on
	ldy #Entity::spriteID
	lda (r3),y
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
	jsr Player::set_bitmap
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
	.byte	00	;	STATUS_PUSHING
	.byte	00	;	STATUS_SWMING

;************************************************
; Try to move player to the right, walk up if facing a slope
;	
move_right:
	; only move if the status is compatible
	ldy player0 + PLAYER::entity + Entity::status
	lda ignore_move_request, y
	beq @walk_push_pull_right		; if 0 => can move
	rts								; else block the move

@walk_push_pull_right:
	ldx player0 + PLAYER::entity + Entity::connectedID
	cpx #$ff
	beq @walk_right				; entityID cannot be 0

	; if the player is pushing right an object located on its right, move the object first
	lda player0 + PLAYER::grab_left_right
	cmp #Grab::RIGHT
	bne @walk_right
	jsr Entities::fn_move_right
	beq @walk_right				; cannot move the grabbed object => refuse to move
	rts

@walk_right:
	ldx #00
	jsr Entities::save_position
	jsr Entities::move_right_entry
	beq @set_sprite
	rts							; blocked by tile, border or sprite

@no_collision:
@set_sprite:
	; pick the correct sprite animation based on move or push or pull
	lda player0 + PLAYER::grab_left_right
	cmp #Grab::NONE
	beq @set_walk_right
	cmp #Grab::LEFT
	beq @set_pull_right

@set_push_right:
	lda player0 + PLAYER::frameID
	cmp #Player::Sprites::PUSH
	beq @pull_object					; already push animation

	lda r0L								; set_bitmap overwrite r0, so we need to save
	sta addrSaveR0L
	lda r0H
	sta addrSaveR0H

	lda #Player::Sprites::PUSH
	sta player0 + PLAYER::frameID
	jsr Player::set_bitmap

	lda addrSaveR0L								; set_bitmap overwrite r0, so we need to restore
	sta r0L
	lda addrSaveR0H
	sta r0H

	bra @pull_object

@set_pull_right:
	lda player0 + PLAYER::frameID
	cmp #Player::Sprites::PULL
	beq @pull_object					; already push animation

	lda r0L								; set_bitmap overwrite r0, so we need to save
	sta addrSaveR0L
	lda r0H
	sta addrSaveR0H

	lda #Player::Sprites::PULL
	sta player0 + PLAYER::frameID
	jsr Player::set_bitmap

	lda addrSaveR0L								; set_bitmap overwrite r0, so we need to restore
	sta r0L
	lda addrSaveR0H
	sta r0H

	bra @pull_object

@set_walk_right:
	lda #SPRITE_FLIP_H
	sta player0 + PLAYER::flip
	ldy player0 + PLAYER::entity + Entity::spriteID
	jsr Sprite::set_flip				; force sprite to look right

	; sprite is already the good one
	lda player0 + PLAYER::entity + Entity::status
	cmp #STATUS_WALKING
	beq @pull_object
	cmp #STATUS_PUSHING
	beq @pull_object

	; force the sprite and status to walking (will keep the pushing status if needed)
	m_status STATUS_WALKING

	;change player sprite
	lda #Player::Sprites::LEFT
	cmp player0 + PLAYER::frameID
	beq @pull_object

	lda r0L								; set_bitmap overwrite r0, so we need to save
	sta addrSaveR0L
	lda r0H
	sta addrSaveR0H

	lda #Player::Sprites::LEFT
	sta player0 + PLAYER::frameID
	jsr Player::set_bitmap

	lda addrSaveR0L								; set_bitmap overwrite r0, so we need to restore
	sta r0L
	lda addrSaveR0H
	sta r0H

@pull_object:
	; if the player is pulling right an object located on its left, move the object last
	lda player0 + PLAYER::grab_left_right
	cmp #Grab::LEFT
	bne @check_slope
	ldx player0 + PLAYER::entity + Entity::connectedID
	jsr Entities::fn_move_right
	beq @validate_object_move

	; object is blocked when being pulled (player on slope, object cannot be moved on slope)
	; restore player position and exit
	ldx #00
	jmp Entities::restore_position

@validate_object_move:
	lda #<player0						; restore 'this'
	sta r3L
	lda #>player0
	sta r3H
	lda player0 + PLAYER::entity + Entity::collision_addr	; restore collision address
	sta r0L
	lda player0 + PLAYER::entity + Entity::collision_addr + 1
	sta r0H

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
	bne @return1						; do not change Y if the tile below the player is a solid one
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

;************************************************
; try to move the player to the left
;	
move_left:
	; only move if the status is compatible
	ldy player0 + PLAYER::entity + Entity::status
	lda ignore_move_request, y
	beq @walk_push_pull_left		; if 0 => can move
	rts								; else block the move

@walk_push_pull_left:
	ldx player0 + PLAYER::entity + Entity::connectedID
	cpx #$ff
	beq @walk_left				; entityID cannot be 0

	; if the player is pushing left an object located on its left, move the object first
	lda player0 + PLAYER::grab_left_right
	cmp #Grab::LEFT
	bne @walk_left
	jsr Entities::fn_move_left
	beq @walk_left				; cannot move the grabbed object => refuse to move
	rts

@walk_left:
	; try move from the parent class Entity
	ldx #00
	jsr Entities::save_position
	jsr Entities::move_left_entry	; return r3 = 'this'
	beq @set_sprite
	rts								; blocked by tile, border or sprite

@no_collision:
@set_sprite:
	; pick the correct sprite animation based on move or push or pull
	lda player0 + PLAYER::grab_left_right
	cmp #Grab::NONE
	beq @set_walk_left
	cmp #Grab::RIGHT
	beq @set_pull_left

@set_push_left:
	lda player0 + PLAYER::frameID
	cmp #Player::Sprites::PUSH
	beq @pull_object					; already push animation

	lda r0L								; set_bitmap overwrite r0, so we need to save
	sta addrSaveR0L
	lda r0H
	sta addrSaveR0H

	lda #Player::Sprites::PUSH
	sta player0 + PLAYER::frameID
	jsr Player::set_bitmap

	lda addrSaveR0L								; set_bitmap overwrite r0, so we need to restore
	sta r0L
	lda addrSaveR0H
	sta r0H

	bra @pull_object

@set_pull_left:
	lda player0 + PLAYER::frameID
	cmp #Player::Sprites::PULL
	beq @pull_object					; already push animation

	lda r0L								; set_bitmap overwrite r0, so we need to save
	sta addrSaveR0L
	lda r0H
	sta addrSaveR0H

	lda #Player::Sprites::PULL
	sta player0 + PLAYER::frameID
	jsr Sprite::set_bitmap

	lda addrSaveR0L								; set_bitmap overwrite r0, so we need to restore
	sta r0L
	lda addrSaveR0H
	sta r0H

	bra @pull_object

@set_walk_left:
	lda #SPRITE_FLIP_NONE
	sta player0 + PLAYER::flip
	ldy player0 + PLAYER::entity + Entity::spriteID
	jsr Sprite::set_flip				; force sprite to loop right

	m_status STATUS_WALKING

	lda #Player::Sprites::LEFT
	cmp player0 + PLAYER::frameID
	beq @pull_object

	lda r0L								; set_bitmap overwrite r0, so we need to save
	sta addrSaveR0L
	lda r0H
	sta addrSaveR0H

	;change player sprite
	lda #Player::Sprites::LEFT
	sta player0 + PLAYER::frameID
	jsr Sprite::set_bitmap

	lda addrSaveR0L								; set_bitmap overwrite r0, so we need to restore
	sta r0L
	lda addrSaveR0H
	sta r0H

@pull_object:
	; if the player is pulling left an object located on its right, move the object last
	lda player0 + PLAYER::grab_left_right
	cmp #Grab::RIGHT
	bne @check_slope
	ldx player0 + PLAYER::entity + Entity::connectedID
	jsr Entities::fn_move_left
	beq @validate_object_move

	; object is blocked when being pulled (player on slope, object cannot be moved on slope)
	; restore player position and exit
	ldx #00
	jmp Entities::restore_position

@validate_object_move:
	lda #<player0						; restore 'this'
	sta r3L
	lda #>player0
	sta r3H
	lda player0 + PLAYER::entity + Entity::collision_addr	; restore collision address
	sta r0L
	lda player0 + PLAYER::entity + Entity::collision_addr + 1
	sta r0H

@check_slope:
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

;************************************************
; try to move the player down (crouch, hide, move down a ladder)
;	input: r3 = player address
;	
move_down:
	lda player0 + PLAYER::entity + Entity::status
	cmp #STATUS_FALLING
	bne @try_move_down				; cannot move when falling
	rts
@try_move_down:
	jsr Entities::get_collision_map
	lda player0 + Entity::levelx
	and #$0f
	beq @oncolum
	cmp #$0c
	bcc :+
@onnextcolum:
	ldy #(LEVEL_TILES_WIDTH * 2 + 1)	; x%16 >= 12 : test 1 tile on column + 1
	bra @start_test
:
	cmp #04
	bcs @drop
@oncolum:	
	ldy #(LEVEL_TILES_WIDTH * 2)	; x%16 <= 4 : test 1 tile on column
	bra @start_test
@drop:
	rts								; in between 2 tiles, cannot test

@start_test:

	; if there the right numbers of ladder tiles at each line of the player
@next_colum:
	sty tileStart
	lda (r0L),y
	cmp #TILE_SOLID_LADER
	beq @climb_down
	rts

@climb_down:
	ldy tileStart
	jsr align_climb
	jsr Entities::position_y_inc	; move down the ladder
	jmp Player::set_climb

;************************************************
; try to move the player up (move up a ladder)
;	input: r3 = player address
;	only climb a ladder if the 16 pixels mid-X are fully enclosed in the ladder
;	modify: r0, r1, r2
;	
move_up:
	lda player0 + PLAYER::entity + Entity::status
	cmp #STATUS_FALLING
	bne @try_move_up				; cannot move when falling
	rts
@try_move_up:
	jsr Entities::get_collision_map

	; check above the player
	sec
	lda r0L
	sbc #LEVEL_TILES_WIDTH
	sta r0L
	lda r0H
	sbc #0
	sta r0H

	lda player0 + Entity::levelx
	and #$0f
	beq @oncolum
	cmp #$0c
	bcc :+
@onnextcolum:
	ldy #1							; x%16 >= 12 : test 1 tile on column + 1
	bra @start_test
:
	cmp #04
	bcs @drop
@oncolum:	
	ldy #00							; x%16 <= 4 : test 1 tile on column
	bra @start_test
@drop:
	rts								; in between 2 tiles, cannot test

@start_test:

	; if there the right numbers of ladder tiles at each line of the player
@next_colum:
	sty tileStart
	lda (r0L),y
	tay
	lda tiles_attributes,y
	bit #TILE_ATTR::GRABBING
	bne @climb_up
	rts

@climb_up:
	ldy tileStart
	jsr align_climb
	jsr Entities::position_y_dec		; move up the ladder
	jmp set_climb

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

	jsr Objects::get_by_spriteID	; find the object that has frameID A
	cpy #$ff
	beq @return						; no object with this ID

	sty bCollisionID
	ldy #Objects::Object::imageID
	lda (r3), y
	bit #Objects::Attribute::GRAB
	beq @return						; object cannot be grabbed

	; call virtual function of the remote object to bind
	lda #<player0
	sta r9L
	lda #>player0
	sta r9H
	jsr Entities::bind

	; bind remote object
	ldy bCollisionID
	sty player0 + PLAYER::entity + Entity::connectedID ; save the EntityID to the grabbed object

	lda player0 + PLAYER::flip
	bne @right1
@left1:
	lda #Grab::LEFT
	sta player0 + PLAYER::grab_left_right
	bra @change_sprite
@right1:
	lda #Grab::RIGHT
	sta player0 + PLAYER::grab_left_right
@change_sprite:
	lda #Player::Sprites::PUSH
	sta player0 + PLAYER::frameID
	stz player0 + PLAYER::frame
	lda #10
	sta player0 + PLAYER::animation_tick	; reset animation tick counter
	lda #01
	sta player0 + PLAYER::frameDirection

	lda #Player::Sprites::PULL
	m_status STATUS_PUSHING

	jsr Player::set_bitmap

@return:
	rts

;************************************************
; release the object the player is moving
;
release_object:
	ldx player0 + PLAYER::entity + Entity::connectedID
	cpx #$ff
	bne :+
	rts
:
	jsr Entities::get_pointer

	ldy #Entity::connectedID				; disconnect the object from the player
	lda #$ff
	sta (r3),y

	lda #$ff
	sta player0 + PLAYER::entity + Entity::connectedID	; disconnect the object from the player

	m_status STATUS_WALKING_IDLE

	lda #Grab::NONE
	sta player0 + PLAYER::grab_left_right

	lda #Player::Sprites::LEFT
	sta player0 + PLAYER::frameID
	stz player0 + PLAYER::frame
	lda #10
	sta player0 + PLAYER::animation_tick	; reset animation tick counter
	lda #01
	sta player0 + PLAYER::frameDirection
	jsr Player::set_bitmap

	rts

;************************************************
; virtual function unbind : also change the status of the object
;   input: r3 = this
;   input: r4L = start of connected object
;
unbind:
	lda #STATUS_WALKING_IDLE
	sta player0 + PLAYER::entity + Entity::status

	lda #Grab::NONE
	sta player0 + PLAYER::grab_left_right

	rts

;************************************************
; virtual function physics
;   input: r3 = this
;
physics:
	; check if we are in water
	ldy #Entity::status
	lda (r3),y
	cmp #STATUS_SWIMING
	beq @water_physics

	jsr Entities::physics		; parent class

	; check if we entered in water
	jsr Entities::get_collision_map
	ldy #00
	lda (r0),y
	cmp #TILE_WATER
	beq :+
	rts

	; activate swim status
:
	jmp set_swim

@water_physics:
	; do nothing
	ldy #Entity::bFlags
	lda (r3),y
	and #(255-EntityFlags::physics)
	sta (r3),y						; disengage physics engine for that entity
	rts

;************************************************
; Virtual function : noaction
;	
noaction:
	rts

;************************************************
; Virtual function : Try to swim player to the right
;	
swim_right:
	ldx #00
	jsr Entities::move_right
	beq @set_sprite
	rts							; blocked by tile, border or sprite

@set_sprite:
	lda #SPRITE_FLIP_H
	sta player0 + PLAYER::flip
	ldy player0 + PLAYER::entity + Entity::spriteID
	jsr Sprite::set_flip				; force sprite to look right
	rts

;************************************************
; Virtual function : Try to swim player to the left
;	
swim_left:
	ldx #00
	jsr Entities::move_left
	beq @set_sprite
	rts							; blocked by tile, border or sprite

@set_sprite:
	lda #SPRITE_FLIP_NONE
	sta player0 + PLAYER::flip
	ldy player0 + PLAYER::entity + Entity::spriteID
	jsr Sprite::set_flip				; force sprite to loop left
	rts

;************************************************
; Virtual function : Try to swim player to the up
;	
swim_up:
	ldx #00
	jsr Entities::save_position_r3		; r3 is already defined
	jsr Entities::move_up

	; check if we are still in the water. 
	jsr Entities::get_collision_map		; r0 is modified by move_up, so reload
	ldy #00
	lda (r0),y							; Top-left corner of the entity
	cmp #TILE_WATER
	bne @block_move_up					; has to be on a water tile
	rts
@block_move_up:
	jsr Entities::restore_position
	rts

;************************************************
; Virtual function : Try to swim player to the down
;	
swim_down:
	jmp Entities::move_down

;************************************************
; Virtual function : block jump when swiming
;	
swim_jump:
	rts

;************************************************
; run animation get out of water
;
swin_animate_out_water:
	lda player0 + Entity::levely
	and #$0f
	beq @stage1
	; move to the same level as the grab tile
	; r3 = *player
	lda #<player0
	sta r3L
	lda #>player0
	sta r3H
	jsr Entities::position_y_dec
	rts
@stage1:
	; register virtual function animate
	lda #<Player::swin_animate_out_water1
	sta fnAnimate_table
	lda #>Player::swin_animate_out_water1
	sta fnAnimate_table+1

	lda #01
	sta player0 + PLAYER::frame
	jsr Player::set_bitmap	

	; reset animation tick counter
	lda #8
	sta player0 + PLAYER::animation_tick	
	rts

swin_animate_out_water1:
	; r3 = *player
	lda #<player0
	sta r3L
	lda #>player0
	sta r3H
	
	jsr Entities::position_y_dec
	jsr Entities::position_y_dec

	lda PLAYER_ZP + 1
	beq @right
@left:
	jsr Entities::position_x_dec
	jsr Entities::position_x_dec
	bra :+
@right:
	jsr Entities::position_x_inc
	jsr Entities::position_x_inc
:
	dec player0 + PLAYER::animation_tick
	beq @stage2
	rts
@stage2:
	; register virtual function animate
	lda #<Player::swin_animate_out_water2
	sta fnAnimate_table
	lda #>Player::swin_animate_out_water2
	sta fnAnimate_table+1

	lda #02
	sta player0 + PLAYER::frame
	jsr Player::set_bitmap	

	; reset animation tick counter
	lda #8
	sta player0 + PLAYER::animation_tick	
	rts

swin_animate_out_water2:
	lda #<player0
	sta r3L
	lda #>player0
	sta r3H
	jsr Entities::position_y_dec
	jsr Entities::position_y_dec
	dec player0 + PLAYER::animation_tick
	beq @stage3
	rts
@stage3:
	jmp Player::set_walk


;************************************************
; Virtual function : block jump when swiming
;	
swim_grab:
	lda player0 + Entity::levelx
	and #$0f
	beq @test_grab_tile
	rts

@test_grab_tile:	
	lda #<player0
	sta r3L
	lda #>player0
	sta r3H
	jsr Entities::get_collision_map

	lda #00
	sta PLAYER_ZP + 1

	lda player0 + PLAYER::flip
	bne @right
@left:
	sec
	lda r0L
	sbc #02
	sta r0L
	lda r0H
	sbc #00
	sta r0H
	inc PLAYER_ZP + 1
@right:
	ldy #01
	lda (r0),y		; test tile on the right
	cmp #TILE_SOLID_GRAB
	beq @get_out_water
	rts

@get_out_water:
	; swap to an animation only mode
	; set virtual functions swim right/meft
	lda #<Player::noaction
	sta Entities::fnMoveRight_table
	lda #>Player::noaction
	sta Entities::fnMoveRight_table+1
	lda #<Player::noaction
	sta Entities::fnMoveLeft_table
	lda #>Player::noaction
	sta Entities::fnMoveLeft_table+1

	; set virtual functions move up/down
	lda #<Player::noaction
	sta Entities::fnMoveUp_table
	sta Entities::fnMoveDown_table
	lda #>Player::noaction
	sta Entities::fnMoveUp_table+1
	sta Entities::fnMoveDown_table+1

	; set virtual functions swim jump
	; set virtual functions swim grab
	lda #<Player::noaction
	sta fnJump_table
	sta fnGrab_table
	lda #>Player::noaction
	sta fnJump_table+1
	sta fnGrab_table+1

	; register virtual function animate
	lda #<Player::swin_animate_out_water
	sta fnAnimate_table
	lda #>Player::swin_animate_out_water
	sta fnAnimate_table+1

	; start out of water animation loop
	lda #Player::Sprites::SWIM_OUT_WATER
	sta player0 + PLAYER::frameID
	lda #00
	sta player0 + PLAYER::frame
	jsr Player::set_bitmap	

	rts

;************************************************
; change to SWIM status
;	
set_swim:
	lda #STATUS_SWIMING
	ldy #Entity::status
	sta (r3),y

	; reset animation frames
	lda #Player::Sprites::SWIM
	sta player0 + PLAYER::frameID
	stz player0 + PLAYER::frame
	jsr Player::set_bitmap

	; reset animation tick counter
	lda #10
	sta player0 + PLAYER::animation_tick	
	lda #01
	sta player0 + PLAYER::frameDirection

	; set virtual functions swim right/meft
	lda #<swim_right
	sta Entities::fnMoveRight_table
	lda #>swim_right
	sta Entities::fnMoveRight_table+1
	lda #<swim_left
	sta Entities::fnMoveLeft_table
	lda #>swim_left
	sta Entities::fnMoveLeft_table+1

	; set virtual functions swim up/down
	lda #<swim_up
	sta Entities::fnMoveUp_table
	lda #>swim_up
	sta Entities::fnMoveUp_table+1
	lda #<swim_down
	sta Entities::fnMoveDown_table
	lda #>swim_down
	sta Entities::fnMoveDown_table+1

	; set virtual functions swim jump
	lda #<swim_jump
	sta fnJump_table
	lda #>swim_jump
	sta fnJump_table+1

	; set virtual functions swim grab
	lda #<swim_grab
	sta fnGrab_table
	lda #>swim_grab
	sta fnGrab_table+1

	rts

;**************************************************
; <<<<<<<<<< 	change to walk status 	>>>>>>>>>>
;**************************************************

;************************************************
; change to WALK status
; input: r3 player address
;	
set_walk:
	lda #STATUS_WALKING
	ldy #Entity::status
	sta (r3),y


	; reset animation frames
	lda #Player::Sprites::LEFT
	sta player0 + PLAYER::frameID
	stz player0 + PLAYER::frame
	jsr Player::set_bitmap

	lda player0 + PLAYER::flip
	ldy player0 + PLAYER::entity + Entity::spriteID
	jsr Sprite::set_flip				; force sprite to loop right

	; reset animation tick counter
	lda #10
	sta player0 + PLAYER::animation_tick	
	lda #01
	sta player0 + PLAYER::frameDirection

	; set virtual functions move right/meft
	lda #<move_right
	sta Entities::fnMoveRight_table
	lda #>move_right
	sta Entities::fnMoveRight_table+1
	lda #<move_left
	sta Entities::fnMoveLeft_table
	lda #>move_left
	sta Entities::fnMoveLeft_table+1

	; set virtual functions move up/down
	lda #<Player::move_up
	sta Entities::fnMoveUp_table
	lda #>Player::move_up
	sta Entities::fnMoveUp_table+1
	lda #<Player::move_down
	sta Entities::fnMoveDown_table
	lda #>Player::move_down
	sta Entities::fnMoveDown_table+1

	; set virtual functions walk jump
	lda #<Player::jump
	sta fnJump_table
	lda #>Player::jump
	sta fnJump_table+1

	; set virtual functions walk grab
	lda #<Player::grab_object
	sta fnGrab_table
	lda #>Player::grab_object
	sta fnGrab_table+1

	; set virtual functions walk animate
	lda #<Player::animate
	sta fnAnimate_table
	lda #>Player::animate
	sta fnAnimate_table+1

	rts


;**************************************************
; <<<<<<<<<<	 	virtual stub	 	>>>>>>>>>>
;**************************************************

;************************************************
; virtual function jump
;   input: R3 = current entity
;
fn_jump:
	jmp (fnJump_table)

;************************************************
; virtual function jump
;   input: R3 = current entity
;
fn_grab:
	jmp (fnGrab_table)

;************************************************
; virtual function animate
;   input: R3 = current entity
;
fn_animate:
	jmp (fnAnimate_table)

.endscope
