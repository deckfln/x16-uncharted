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
actions = PLAYER_ZP
tileStart = PLAYER_ZP + 1
laddersFound = PLAYER_ZP + 2
tilesHeight = PLAYER_ZP + 3
tmp_player = PLAYER_ZP + 4

PNG_SPRITES_LINES = 11
PNG_SPRITES_COLUMNS = 3
BITMAPS_TABLE = 2 * PNG_SPRITES_COLUMNS * PNG_SPRITES_LINES

.enum
	STATUS_WALKING_IDLE
	STATUS_WALKING
	STATUS_CLIMBING
	STATUS_CLIMBING_IDLE
	STATUS_FALLING
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
	vera_bitmaps    .res 	2 * 3 * 11	; 9 words to store vera bitmaps address
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

; v0.y value when jumping (LOW = decimal part, HI = integer part)
JUMP_V0Y = $0140
JUMP_V0X_RIGHT = $007f
JUMP_V0X_LEFT = $ff80

; player sprites status
.enum Sprites
	FRONT = 0
	LEFT = FRONT + PNG_SPRITES_COLUMNS
	CLIMB = LEFT + PNG_SPRITES_COLUMNS
	HANG = CLIMB + PNG_SPRITES_COLUMNS
	PUSH = HANG + PNG_SPRITES_COLUMNS
	PULL = PUSH + PNG_SPRITES_COLUMNS
	SWIM = PULL + PNG_SPRITES_COLUMNS
	SWIM_OUT_WATER = SWIM + PNG_SPRITES_COLUMNS
	CLIMB_UP = SWIM_OUT_WATER + PNG_SPRITES_COLUMNS
	CLIMB_RIGHT = CLIMB_UP + PNG_SPRITES_COLUMNS
	CLIMB_ROPE = CLIMB_RIGHT + PNG_SPRITES_COLUMNS
.endenum

; player grab object right or left ?
.enum Grab
	NONE = 0
	LEFT = 1
	RIGHT = 2
.endenum

; player active controlers
.enum Control
	Right	= %00000001
	Left	= %00000010
	Up		= %00000100
	Down	= %00001000
	Jump	= %00010000
	Grab	= %00100000
.endenum

WIDTH = 16
HEIGHT = 32

;************************************************
; local variables
;
ladders: .byte 0
test_right_left: .byte 0

.include "player/transitions.asm"

; register the controlers for the player
.include "player/walk.asm"
.include "player/climb.asm"
.include "player/swim.asm"
.include "player/ladder.asm"

;************************************************
; init the Player module
;
initModule:
	rts

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

	; initialize the parent class entity
	jsr Entities::init

	lda #CLASS::PLAYER
	sta player0 + PLAYER::entity + Entity::classID

	lda #$a0
	ldx #$00
	jsr Entities::position_x

	lda #$48
	ldx #$00
	jsr Entities::position_y

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

	jsr Entities::height_tiles
	ldy #Entity::bFeetIndex
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

	lda #<Player::physics
	sta Entities::fnPhysics_table
	lda #>Player::physics
	sta Entities::fnPhysics_table + 1

	; register virtual function move_right/left
	lda #$ff
	jsr Player::restore_action

	; register virtual function animate
	lda #<Player::animate
	sta fnAnimate_table
	lda #>Player::animate
	sta fnAnimate_table+1

	lda #<Player::set_physics
	sta Entities::fnSetPhysics_table,x
	lda #>Player::set_physics
	sta Entities::fnSetPhysics_table+1,x

	; set class attributes
	ldy #Entity::controler_select
	lda #<Player::set_controler
	sta (r3),y
	iny
	lda #>Player::set_controler
	sta (r3),y

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

	; check if the object starts sitting on something
    jsr Entities::Physic::check_solid    

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
; set the proper controler based on the current tile
;   input: R3 = start of the object
;			X = tile to use as base for status
;
;	
set_controler:
	cpx #$ff
	beq @not_found					; no tile, so let the parent entity deal with it
	lda tiles_attributes,x
	; call the player components
	Ladder_check
	Climb_check
	Swim_check
	Walk_check
@not_found:
	jmp Entities::set_controler		 ; time to debug, tile model not found

;**************************************************
; <<<<<<<<<< 			status 			>>>>>>>>>>
; input : A = tile code
;**************************************************

;set_controler:
;	beq @test_ground			; fall
;	cmp #TILE::LEDGE
;	beq @set_climb
;	cmp #TILE::SOLID_LADER
;	beq @set_ladder
;	cmp #TILE::TOP_LADDER
;	beq @set_ladder
;	cmp #TILE::ROPE
;	beq @set_ladder
;	cmp #TILE::TOP_ROPE
;	beq @set_ladder
;	tax
;	lda tiles_attributes,x
;	bit #TILE_ATTR::SOLID_GROUND
;	bne @set_walk
;	brk							; should not get there
;
;@test_ground:
;	ldy #(LEVEL_TILES_WIDTH*2)
;	lda (r0),y
;	bit #TILE_ATTR::SOLID_GROUND
;	bne @set_walk
;	;fall through
;@set_physics:
;	jmp set_physics
;@set_ladder:
;	jmp Ladder::set
;@set_climb:
;	jmp Climb::set
;@set_walk:
;	jmp set_walk

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

set_flip:
	sta player0 + PLAYER::flip
	ldy player0 + PLAYER::entity + Entity::spriteID
	jsr Sprite::set_flip				; force sprite to look right
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
	.byte	00	;	STATUS_PUSHING
	.byte	00	;	STATUS_SWMING

;************************************************
; jump
;	input: A = delta X value
;
jump:
	; r3 = *player
	lda #<player0
	sta r3L
	lda #>player0
	sta r3H
jump_enty:
	stx PLAYER_ZP
	sty PLAYER_ZP+1

	; ensure there is no ceiling over the player
	jsr Entities::check_collision_up
	bne @return

	; set the physic controler
	jsr Entities::Physic::set

	lda #<JUMP_V0Y	; vty = v0.y*t (decimal part) => NON SIGNED ( <> 0.5)
	sta player0 + PLAYER::entity + Entity::vty
	lda #>JUMP_V0Y
	sta player0 + PLAYER::entity + Entity::vty + 1

	; vtx = v0.x*t (decimal part) =>  SIGNED !!! ( $80 <> -0.5 )
	lda PLAYER_ZP
	sta player0 + PLAYER::entity + Entity::vtx
	lda PLAYER_ZP+1
	sta player0 + PLAYER::entity + Entity::vtx + 1

	; deactivate all controls but Grab
	lda #(Control::Right | Control::Left | Control::Up | Control::Down | Control::Jump)
	jsr Player::set_noaction			; only the grab feature is kept when gravity driven

	; restore the jump/fall physics
	lda #<Player::physics
	sta Entities::fnPhysics_table
	lda #>Player::physics
	sta Entities::fnPhysics_table + 1

@return:
	rts

;************************************************
; grab the object if front of the player, if there is an object
;
grab_object:
	lda player0 + PLAYER::entity + Entity::bFlags
	bit #EntityFlags::physics
	beq @check_grab_object
@check_grab_ladder:
	jmp Climb::Grab

@check_grab_object:
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

	jsr Objects::get_by_spriteID	; find the object that has frameID A, on return r3 = remote object
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

	; switch to releae function
	lda #<Player::release_object
	sta fnGrab_table
	lda #>Player::release_object
	sta fnGrab_table + 1
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

player_release:
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

	; restore grab function
	lda #<Player::grab_object
	sta fnGrab_table
	lda #>Player::grab_object
	sta fnGrab_table + 1

	rts

;************************************************
; virtual function unbind : also change the status of the object
;   input: r3 = this
;   input: r4L = start of connected object
;
unbind:
	jmp player_release

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

	jsr Entities::Physic::update		; parent class

	; check if we entered in water
	jsr Entities::get_collision_map
	ldy #00
	lda (r0),y
	cmp #TILE::WATER
	beq @enter_water
	rts

	; activate swim status
@enter_water:
	jmp Swim::Set

@water_physics:
	; do nothing
	;ldy #Entity::bFlags
	;lda (r3),y
	;and #(255-EntityFlags::physics)
	;sta (r3),y						; disengage physics engine for that entity
	lda #00
	ldy #Entity::update
	sta (r3),y
	iny
	sta (r3),y
	rts

set_physics:
	lda #<Player::physics
	sta Entities::fnPhysics_table
	lda #>Player::physics
	sta Entities::fnPhysics_table + 1

	lda #$ff
	jsr Player::restore_action

	lda #STATUS_WALKING_IDLE	
	sta player0 + PLAYER::entity + Entity::status

	;ldy #Entity::bFlags
	;lda (r3),y
	;ora #EntityFlags::physics
	;sta (r3),y						; disengage physics engine for that entity
	lda #00
	ldy #Entity::update
	sta (r3),y
	iny
	sta (r3),y

	rts

;************************************************
; Virtual function : noaction
;	
noaction:
	rts

;**************************************************
; <<<<<<< 	define active keyboard control 	>>>>>>>
;**************************************************

;****************************************
; swap to an animation only mode
;	input : A = bitmap of actions to block
;
set_noaction:
	; set virtual functions right/left
	ldx #<Player::noaction
	ldy #>Player::noaction

	bit #Player::Control::Right
	beq :+
	stx Entities::fnMoveRight_table
	sty Entities::fnMoveRight_table + 1
:
	bit #Player::Control::Left
	beq :+
	stx Entities::fnMoveLeft_table
	sty Entities::fnMoveLeft_table + 1
:
	bit #Player::Control::Up
	beq :+
	stx Entities::fnMoveUp_table
	sty Entities::fnMoveUp_table + 1
:
	bit #Player::Control::Down
	beq :+
	stx Entities::fnMoveDown_table
	sty Entities::fnMoveDown_table + 1
:
	bit #Player::Control::Jump
	beq :+
	ldx #$60					; op code for RTS
	stx controls_jump + 2		; remove the call to the function

	bit #Player::Control::Grab
	beq :+
	stx fnGrab_table
	sty fnGrab_table + 1
:
	rts

;****************************************
; swap back to an animation only mode
;
restore_action:
	bit #Player::Control::Right
	beq :+
	ldx #<Walk::right
	stx Entities::fnMoveRight_table
	ldx #>Walk::right
	stx Entities::fnMoveRight_table + 1
:
	bit #Player::Control::Left
	beq :+
	ldx #<Walk::left
	stx Entities::fnMoveLeft_table
	ldx #>Walk::left
	stx Entities::fnMoveLeft_table+1
:
	bit #Player::Control::Up
	beq :+
	ldx #<Player::Walk::up
	stx Entities::fnMoveUp_table
	ldx #>Player::Walk::up
	stx Entities::fnMoveUp_table+1
:
	bit #Player::Control::Down
	beq :+
	ldx #<Player::Walk::down
	stx Entities::fnMoveDown_table
	ldx #>Player::Walk::down
	stx Entities::fnMoveDown_table+1
:
	bit #Player::Control::Jump
	beq :+
	ldx #$4c					; op code for jmp
	stx controls_jump + 2
	ldx #<Player::jump			; address of the function
	stx controls_jump + 3
	ldx #>Player::jump
	stx controls_jump + 4

	bit #Player::Control::Grab
	beq :+
	ldx #<Player::grab_object
	stx fnJump_table
	ldx #>Player::grab_object
	stx fnJump_table+1
:
	rts

;**************************************************
; <<<<<<<<<<	 	virtual stub	 	>>>>>>>>>>
;**************************************************

;************************************************
; virtual function jump
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
;
fn_animate:
	lda #<player0
	sta r3L
	lda #>player0
	sta r3H
	jmp (fnAnimate_table)

;**************************************************
; <<<<<<<<<< 	manage controls		 	>>>>>>>>>>
;**************************************************

;  .A, byte 0:      | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
;              NES  | A | B |SEL|STA|UP |DN |LT |RT |
;              SNES | B | Y |SEL|STA|UP |DN |LT |RT |
;
;  .X, byte 1:      | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
;              NES  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | X |
;              SNES | A | X | L | R | 1 | 1 | 1 | 1 |
;  .Y, byte 2:
;              $00 = joystick present
;              $FF = joystick not present 

controls:
	lda joystick_data_change + 1
	bit #Joystick::JOY_A
	beq controls_check
controls_grab:
	jsr Player::fn_grab

controls_check:
	ldx #00					; force entityID = player
	lda joystick_data

	bit #(Joystick::JOY_RIGHT|Joystick::JOY_B)
	beq controls_jump_right
	bit #(Joystick::JOY_LEFT|Joystick::JOY_B)
	beq controls_jump_left
	bit #Joystick::JOY_RIGHT
	beq controls_joystick_right
	bit #Joystick::JOY_LEFT
	beq controls_joystick_left
	bit #Joystick::JOY_DOWN
	beq controls_movedown
	bit #Joystick::JOY_UP
	beq controls_moveup
	bit #Joystick::JOY_B
	beq controls_jump

	jsr Player::set_idle

	rts

controls_jump_right:
	ldx #<JUMP_V0X_RIGHT					; jump right
	ldy #>JUMP_V0X_RIGHT
	jsr Player::fn_jump
	rts

controls_jump_left:
	ldx #<JUMP_V0X_LEFT					; jump left
	ldy #>JUMP_V0X_LEFT
	jsr Player::fn_jump
	rts

controls_joystick_left:
	jsr Entities::fn_move_left
	rts

controls_joystick_right:
	jsr Entities::fn_move_right
	rts

controls_moveup:
	jsr Entities::fn_move_up
	rts

controls_movedown:
	jsr Entities::fn_move_down
	rts

controls_jump:
	lda #0				; jump up
	jmp Player::jump

.endscope
