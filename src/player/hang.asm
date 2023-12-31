;**************************************************
; <<<<<<<<<< 	change to CLIMB status 	>>>>>>>>>>
;**************************************************

.scope Hang

;************************************************
; Macro to help the controler identity the component
;
.macro Hang_check
	cpx #TILE::HANG_FROM
	bne :+
	jmp Hang::Set
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
@align:
	jsr Entities::align_on_x_tile
	rts

@check_right_tile:
	jsr Entities::check_collision_right
	beq :+							; there is a collision on the right, so block the move
	rts
:
	ldy #02							; check_collision_right move the collision map one tile left
	lda (r0),y
	sta Entities::bCurentTile
	bne :+							; nothing on the right, stick to the ladder
	rts
:
	cmp #TILE::HANG_FROM
	beq @hang_right					; move to a ladder on the right
@set_controler:
	ldx #TILE::HANG_FROM
	jsr Transitions::get			; check how to move to the next tile
	beq :+
	rts								; no transition exist
:
	ldy #Transitions::Transition::action
	lda (r1),y
	cmp #01							
	bne	:+
	brk								; move pixel by pixel to the next hang ???
:
	ldx #Animation::Direction::RIGHT
	ldy #02
	ldy Entities::bCurentTile
	jmp Transitions::run			; execute the transition to the next tile

@hang_right:
	ldx #Animation::Direction::RIGHT
    stx Animation::direction
	lda #TILE::HANG_FROM
    sta Animation::target
	jmp Transitions::from_hang_2_hang	; execute the transition to the next tile

;************************************************
; try to move the player to the left of a ledge
;	
Left:
	lda player0 + PLAYER::entity + Entity::levelx
	and #$0f
	beq @check_left_tile
@align:
	jsr Entities::align_on_x_tile
	rts

@check_left_tile:
	jsr Entities::check_collision_left
	beq :+							; there is a collision on the left, so block the move
	rts
:
	lda (r0)						; check_collision_right move the collision map one tile left
	sta Entities::bCurentTile
	bne :+							; nothing on the left, stick to the positon
	rts
:
	cmp #TILE::HANG_FROM
	beq @hang_left					; move the a ladder on the left
	ldx #TILE::HANG_FROM
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
	ldx #Animation::Direction::LEFT
	ldy Entities::bCurentTile
	jmp Transitions::run			; execute the transition to the next

@set_controler:	
	ldx Entities::bCurentTile
	jmp Player::set_controler		; let the entity decide what to do

@hang_left:
	ldx #Animation::Direction::LEFT
    stx Animation::direction
	lda #TILE::HANG_FROM
    sta Animation::target
	jmp Transitions::from_hang_2_hang	; execute the transition to the next tile

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
	cmp #TILE::HANG_FROM
	beq @hang_down					; move the a hang point below
	ldx #TILE::HANG_FROM
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
	ldy Entities::bCurentTile
	jmp Transitions::run			; execute the transition to the next

@set_controler:	
	ldx Entities::bCurentTile
	jmp Player::set_controler		; let the entity decide what to do

@hang_down:
	ldx #Animation::Direction::DOWN
    stx Animation::direction
	lda #TILE::HANG_FROM
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
	cmp #TILE::HANG_FROM
	beq @hang_up					; move the a hang point over
	ldx #TILE::HANG_FROM
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
	ldx #Animation::Direction::UP
	ldy Entities::bCurentTile
	jmp Transitions::run			; execute the transition to the next

@set_controler:	
	ldx Entities::bCurentTile
	jmp Player::set_controler		; let the entity decide what to do

@hang_up:
	ldx #Animation::Direction::UP
    stx Animation::direction
	lda #TILE::HANG_FROM
    sta Animation::target

	jmp Transitions::from_hang_2_hang	; execute the transition to the next tile

Jump:
	brk

;************************************************
; change to HANG status
; input R3
;		X = current tile
;	
Set:
	lda #Player::Sprites::HANG
	sta player0 + PLAYER::frameID
	lda #00
	sta player0 + PLAYER::frame
@set:
	lda #STATUS_CLIMBING
	ldy #Entity::status
	sta (r3),y

	jsr Entities::align_on_y_tile
	jsr Entities::align_on_x_tile

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