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
	bne :+							; nothing on the right, stick to the ladder
	rts
:
	cmp #TILE::HANG_FROM
	beq @hang_right					; move to a ladder on the right
@set_controler:
	ldx #TILE::HANG_FROM
	jsr Transitions::get			; check how to move to the next tile
	bne @set_controler1
	ldy #Transitions::Transition::action
	lda (r1),y
	cmp #01							
	bne	:+
	brk								; move pixel by pixel to the next hang ???
:
	ldx #Animation::Direction::RIGHT
	ldy #02
	lda (r0),y
	tay
	jmp Transitions::run			; execute the transition to the next tile

@set_controler1:
	ldy #02
	lda (r0),y
	tax
	jmp Player::set_controler		; let the entity decide what to do

@hang_right:
	ldx #Animation::Direction::RIGHT
    stx Animation::direction
	ldy #02
	lda (r0),y
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
	bne :+							; nothing on the left, stick to the positon
	rts
:
	cmp #TILE::HANG_FROM
	beq @hang_left					; move the a ladder on the left
	ldx #TILE::HANG_FROM
	jsr Transitions::get			; check how to move to the next tile
	bne @set_controler
	ldy #Transitions::Transition::action
	lda (r1),y
	cmp #01
	bne :+
	brk								; move pixel by pixel to the next slide ??
:
	ldx #Animation::Direction::LEFT
	lda (r0)
	tay
	jmp Transitions::run			; execute the transition to the next

@set_controler:	
	tax
	jmp Player::set_controler		; let the entity decide what to do

@hang_left:
	ldx #Animation::Direction::LEFT
    stx Animation::direction
	lda (r0)
    sta Animation::target

	jmp Transitions::from_hang_2_hang	; execute the transition to the next tile

;************************************************
;	
Up:
	brk
Down:
	brk
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

	; set virtual functions move right/meft
	lda #<Hang::Right
	sta Entities::fnMoveRight_table
	lda #>Hang::Right
	sta Entities::fnMoveRight_table+1
	lda #<Hang::Left
	sta Entities::fnMoveLeft_table
	lda #>Hang::Left
	sta Entities::fnMoveLeft_table+1

	; set virtual functions move up/down
	lda #<Hang::Up
	sta Entities::fnMoveUp_table
	lda #>Hang::Up
	sta Entities::fnMoveUp_table+1
	lda #<Hang::Down
	sta Entities::fnMoveDown_table
	lda #>Hang::Down
	sta Entities::fnMoveDown_table+1

	; set virtual functions walk jump
	lda #<Hang::Jump
	sta fnJump_table
	lda #>Hang::Jump
	sta fnJump_table+1

	rts

	.endscope