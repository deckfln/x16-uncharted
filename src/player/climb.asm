;**************************************************
; <<<<<<<<<< 	change to CLIMB status 	>>>>>>>>>>
;**************************************************

.scope Climb

bClimb_direction = PLAYER_ZP
bClimbFrames = PLAYER_ZP + 1
bClimbHalfFrames = PLAYER_ZP + 2
bCounter = PLAYER_ZP + 2
bForceJump = PLAYER_ZP + 2
wPositionY = PLAYER_ZP + 3

;************************************************
; Macro to help the controler identity the component
;
.macro Climb_check
	cpx #TILE::LEDGE
	bne :+
	jmp Climb::Set
:
.endmacro

;************************************************
; input: r3 = pointer to player
;	
Update:
	lda joystick_data
	bit #Joystick::JOY_RIGHT
	beq @right
	bit #Joystick::JOY_LEFT
	beq @left
	bit #Joystick::JOY_DOWN
	beq @down
	bit #Joystick::JOY_UP
	beq @up
	rts
@right:
	jmp Right
@left:
	jmp Left
@down:
	jmp Down
@up:
	jmp Up

;************************************************
; Try to jump player to an right grab point
; input: r3 = pointer to player
;	
Right:
	lda player0 + PLAYER::entity + Entity::levelx
	and #$0f
	beq @check_right_tile

@try_right:
	ldx #00							; set entity 0 (player)
	ldy #00							; do not check ground
	jsr Entities::try_right			; if we are not a tile 0, right was already tested, so we continue
	beq @check_right_pixel
	rts
@move_right:
	jsr Entities::position_x_inc
@check_right_pixel:
	jsr Player::animate
	jsr Entities::get_collision_head
	lda (r0),y
	cmp #TILE::LEDGE
	bne @change_controler
@return:
	rts
@change_controler:
	tax
	jmp Player::set_controler		; let the entity decide what to do

@check_right_tile:
	jsr Entities::check_collision_right
	bne @return						; there is a collision on the right, so block the move
	ldy #02							; check_collision_right move the collision map one tile left
	lda (r0),y
	sta Entities::bCurentTile
	beq @return						; nothing on the right, stick to the ladder
	cmp #TILE::LEDGE
	beq @move_right					; move to a ladder on the right
@set_controler:
	ldx #TILE::LEDGE
	jsr Transitions::get			; check how to move to the next tile
	beq :+
	rts								; no transition defined
:
	ldy #Transitions::Transition::action
	lda (r1),y
	cmp #01							
	beq	@move_right					; move pixel by pixel to the next slide
	ldx #Animation::Direction::RIGHT
	ldy #02							; check_collision_right move the collision map one tile left
	ldy Entities::bCurentTile
	jmp Transitions::run			; execute the transition to the next tile

;************************************************
; try to move the player to the left of a ledge
;	
Left:
	lda player0 + PLAYER::entity + Entity::levelx
	and #$0f
	beq @check_left_tile

@try_left:	
	ldx #00							; set entity 0 (player)
	ldy #00							; do not check ground
	jsr Entities::Left				; move 1 pixel to the left if possible
	beq @check_left_pixel
	rts
@move_left:
	jsr Entities::position_x_dec
@check_left_pixel:
	jsr Player::animate
	jsr Entities::get_collision_head
	lda (r0),y
	sta Entities::bCurentTile
	cmp #TILE::LEDGE
	bne @change_controler
@return:
	rts
@change_controler:
	tax
	jmp Player::set_controler		; let the entity decide what to do

@check_left_tile:
	jsr Entities::check_collision_left
	bne @return						; there is a collision on the left, so block the move
	lda (r0)						; check_collision_right move the collision map one tile left
	beq @return						; nothing on the left, stick to the ladder
	cmp #TILE::LEDGE
	beq @move_left					; move the a ladder on the left

	ldx #TILE::LEDGE
	jsr Transitions::get			; check how to move to the next tile
	beq :+
	rts								; no transition exist
:
	ldy #Transitions::Transition::action
	lda (r1),y
	cmp #01							
	beq	@move_left					; move pixel by pixel to the next slide
	ldx #Animation::Direction::LEFT
	ldy Entities::bCurentTile
	jmp Transitions::run			; execute the transition to the next

;************************************************
;	Move the player to a lower hang point or ledge
;
Down:
	jsr Entities::check_collision_down
	beq @move_down
	rts
@move_down:
	jsr Entities::get_collision_map
	lda #TILE_WIDTH
	sta laddersNeeded
	ldy #LEVEL_TILES_WIDTH
	lda (r0L),y
	sta Entities::bCurentTile
	bne :+
	rts								; nothing on hang level => do nothing
:
	cmp #TILE::LEDGE
	beq @hang_down					; move the a hang point below
	ldx #TILE::LEDGE
	jsr Transitions::get			; check how to move to the next tile
	beq :+
	rts								; no transition exists
:
	ldy #Transitions::Transition::action
	lda (r1),y
	cmp #01
	bne :+
	brk								; move pixel by pixel to the next slide ??
:
	ldx #Animation::Direction::DOWN
	ldy	Entities::bCurentTile
	jmp Transitions::run			; execute the transition to the next

@hang_down:
	ldx #Animation::Direction::DOWN
    stx Animation::direction
	lda #TILE::LEDGE
    sta Animation::target
	jmp Transitions::from_hang_2_hang	; execute the transition to the next tile

;************************************************
;	
Up:
	jsr Entities::check_collision_up
	beq @move_up
	rts
@move_up:
	jsr Entities::get_collision_map
	sec
	lda r0L
	sbc #LEVEL_TILES_WIDTH
	sta r0L
	lda r0H
	sbc #0
	sta r0H

	lda #00
	sta laddersNeeded
	ldy #00
	lda (r0L),y
	sta Entities::bCurentTile
	bne :+
	rts								; nothing on hang level => do nothing
:
	cmp #TILE::LEDGE
	beq @hang_up					; move the a hang point over
	ldx #TILE::LEDGE
	jsr Transitions::get			; check how to move to the next tile
	beq :+
	rts								; no transition exist
:
	ldy #Transitions::Transition::action
	lda (r1),y
	cmp #01
	bne :+
	brk								; move pixel by pixel to the next slide ??
:
	ldx #Animation::Direction::UP
	ldy #00
	ldy  Entities::bCurentTile
	jmp Transitions::run			; execute the transition to the next

@set_controler:	
	ldx Entities::bCurentTile
	jmp Player::set_controler		; let the entity decide what to do

@hang_up:
	ldx #Animation::Direction::UP
    stx Animation::direction
	lda #TILE::LEDGE
    sta Animation::target
	jmp Transitions::from_hang_2_hang	; execute the transition to the next tile

;************************************************
; check if during physics the player grab a hangi point
;	input: r3 = player address
;	
Grab:
	; only grab when the button is pushed
	lda joystick_data + 1
	bit #Joystick::JOY_A
	bne @real_grab
	rts

@real_grab:
	jsr Entities::get_collision_map
	ldy #00
	lda (r0),y						; check at head level
	tax
	lda tiles_attributes,x
	bit #TILE_ATTR::GRABBING
	bne @change_state
	ldy #LEVEL_TILES_WIDTH			; check at hip level
	lda (r0),y
	tax
	lda tiles_attributes,x
	bit #TILE_ATTR::GRABBING
	bne @change_state_hip
	rts
@change_state_hip:
	; force the position to the head
	clc
	lda player0 + PLAYER::entity + Entity::levely
	adc #TILE_HEIGHT
	sta player0 + PLAYER::entity + Entity::levely
	lda player0 + PLAYER::entity + Entity::levely + 1
	adc #00
	sta player0 + PLAYER::entity + Entity::levely + 1
		
@change_state:
	; disengagne physics
	lda player0 + PLAYER::entity + Entity::bFlags
	and #(255-EntityFlags::physics)
	sta player0 + PLAYER::entity + Entity::bFlags

	lda tiles_attributes,x
	bit #TILE_ATTR::LADDER
	bne @go_ladder
@go_climb:
	jmp Climb::Set
@go_ladder:
	; force player to align with head level
	cpy #00
	beq @set_ladder
	clc
	lda player0 + PLAYER::entity + Entity::levely
	adc #TILE_HEIGHT
	sta player0 + PLAYER::entity + Entity::levely
	lda player0 + PLAYER::entity + Entity::levely + 1
	adc #00
	sta player0 + PLAYER::entity + Entity::levely + 1
	
@set_ladder:
	lda (r0),y
	jmp Player::set_controler

;************************************************
; release the ledge the player it hanging from
;	input: r3 = player address
;	
Release:
	; only release the grab when the button is released
	lda joystick_data + 1
	bit #Joystick::JOY_A
	bne @real_release
	rts

@real_release:
	lda player0 + PLAYER::entity + Entity::bFlags
	ora #EntityFlags::physics
	sta player0 + PLAYER::entity + Entity::bFlags			; engage physics engine for that entity
	stz player0 + PLAYER::entity + Entity::vtx
	lda #00
	jmp Player::set_controler

;************************************************
; jump from the ledge the player it hanging from
;	input: r3 = player address
;			A = direction of the jump
;	
Jump:
	sta bForceJump

	; only release the grab when the button is released
;	lda joystick_data + 1
;	bit #JOY_B
;	bne @real_jump
;	rts

@real_jump:
	jsr Entities::Walk::set
	lda bForceJump
	jmp Player::jump

;************************************************
; change to CLIMB status
; input R3
;		X = current tile
;	
Set:
	cpx #TILE::HANG_FROM
	beq @hang
@ledge:
	lda #Player::Sprites::LEDGE
	sta player0 + PLAYER::frameID
	lda #01
	sta player0 + PLAYER::frame
	bra @set
@hang:
	lda #Player::Sprites::HANG
	sta player0 + PLAYER::frameID
	lda #00
	sta player0 + PLAYER::frame
@set:
	lda #STATUS_CLIMBING
	ldy #Entity::status
	sta (r3),y

	jsr Entities::align_on_y_tile

	; disengage physics engine for that entity
	ldy #Entity::bFlags
	lda (r3),y
	and #(255-EntityFlags::physics)
	sta (r3),y						

	; reset animation frames
	jsr Player::set_bitmap

	; reset animation tick counter
	lda #10
	sta player0 + PLAYER::animation_tick	
	lda #01
	sta player0 + PLAYER::frameDirection

	; set the proper update
	ldy #Entity::update
	lda #<Update
	sta (r3),y
	iny
	lda #>Update
	sta (r3),y

	rts

	.endscope