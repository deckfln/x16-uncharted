;*************************************************************
; <<<<<<<<<< 	change to Player::Move controler 	>>>>>>>>>>
;*************************************************************

.scope Walk

;************************************************
; Macro to help the controler identity the component
;
.macro Walk_check
	bit #TILE_ATTR::NONE
	beq :+
	jmp Walk::Set
:
.endmacro

;************************************************
; Try to move player to the right, walk up if facing a slope
;	
right:
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
	ldy #01							; check ground	
	jsr Entities::fn_move_right
	beq @walk_right				; cannot move the grabbed object => refuse to move
	rts

@walk_right:
	ldx #00
	jsr Entities::save_position
	ldy #01							; check ground	
	jsr Entities::Walk::right
	beq @no_collision
	rts							; blocked by tile, border or sprite

@no_collision:
	lda player0 + PLAYER::entity + Entity::status
	cmp #STATUS_FALLING
	beq @falling
	cmp #Status::SLIDE_RIGHT
	beq @onslidingslop
	cmp #Status::SLIDE_LEFT
	bne @set_sprite
@onslidingslop:
	lda #%00001111
	jmp Player::set_noaction
@falling:
	lda #<JUMP_V0X_RIGHT					; jump right
	sta player0 + PLAYER::entity + Entity::vtx
	lda #>JUMP_V0X_RIGHT
	sta player0 + PLAYER::entity + Entity::vtx+1
	rts

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
	bne @return1
	ldx player0 + PLAYER::entity + Entity::connectedID
	ldy #01							; check ground	
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

@return1:
	rts

;************************************************
; try to move the player to the left
;	
left:
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
	ldy #01							; check ground	
	jsr Entities::fn_move_left
	beq @walk_left				; cannot move the grabbed object => refuse to move
	rts

@walk_left:
	; try move from the parent class Entity
	ldx #00
	jsr Entities::save_position
	ldy #01							; check ground
	jsr Entities::Walk::left		; return r3 = 'this'
	beq @no_collision
	rts								; blocked by tile, border or sprite

@no_collision:
	lda player0 + PLAYER::entity + Entity::status
	cmp #STATUS_FALLING
	beq @falling
	cmp #Status::SLIDE_RIGHT
	beq @onslidingslop
	cmp #Status::SLIDE_LEFT
	bne @set_sprite
@onslidingslop:
	lda #%00001111
	jmp Player::set_noaction
@falling:
	lda #<JUMP_V0X_LEFT					; jump right
	sta player0 + PLAYER::entity + Entity::vtx
	lda #>JUMP_V0X_LEFT
	sta player0 + PLAYER::entity + Entity::vtx+1
	rts
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
	bne @return
	ldx player0 + PLAYER::entity + Entity::connectedID
	ldy #01							; check ground
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

@return:
	rts

;************************************************
; try to move the player down (crouch, hide, move down a ladder)
;	input: r3 = player address
;	
down:
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
	lda (r0L),y
	jmp Player::set_controler

;************************************************
; try to move the player up (move up a ladder)
;	input: r3 = player address
;	only climb a ladder if the 16 pixels mid-X are fully enclosed in the ladder
;	modify: r0, r1, r2
;	
up:
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
	jmp Player::set_controler

;************************************************
; change to Move status
; input: r3 player address
;	
Set:
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

	; set virtual functions move right/left/up/down
	lda #$ff
	jsr Player::restore_action

	; set virtual functions walk animate
	lda #<Player::animate
	sta fnAnimate_table
	lda #>Player::animate
	sta fnAnimate_table+1

	ldx #<right
	stx Entities::fnMoveRight_table
	ldx #>right
	stx Entities::fnMoveRight_table + 1

	ldx #<left
	stx Entities::fnMoveLeft_table
	ldx #>left
	stx Entities::fnMoveLeft_table+1

	ldx #<up
	stx Entities::fnMoveUp_table
	ldx #>up
	stx Entities::fnMoveUp_table+1

	ldx #<down
	stx Entities::fnMoveDown_table
	ldx #>down
	stx Entities::fnMoveDown_table+1

	ldx #<Player::jump
	stx fnJump_table
	ldx #>Player::jump
	stx fnJump_table+1

	ldx #<Player::grab_object
	stx fnGrab_table
	ldx #>Player::grab_object
	stx fnGrab_table+1

    rts

.endscope