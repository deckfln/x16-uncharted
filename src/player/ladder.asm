;**************************************************
; <<<<<<<<<< 	change to ladder status 	>>>>>>>>>>
;**************************************************

.scope Ladder

;************************************************
; Macro to help the controler identity the component
;
.macro Ladder_check
	bit #TILE_ATTR::LADDER
	beq :+
	jmp Ladder::Set
:
.endmacro

;************************************************
; Try to move player to the right of a ladder
; input: r3 = pointer to player
;	
Right:
	lda player0 + PLAYER::entity + Entity::levelx
	and #$0f
	beq @check_right_tile

@try_right:
	ldx #00							; set entity 0 (player)
	ldy #00							; do not check ground
	jsr Entities::right				; if we are not a tile 0, right was already tested, so we continue
	beq @move_right
	rts
@move_right:
	jsr Entities::position_x_inc
@check_ladders:
	lda player0 + PLAYER::entity + Entity::levelx
	and #$0f
	cmp #$08
	bcs @fall
@return:
	rts

@check_right_tile:
	jsr Entities::get_collision_map
	ldy #01
	lda (r0),y
	cmp #TILE::SOLID_LADER
	beq @try_right
	jmp Climb::check_climb_right


@fall:
	ldy #01
	lda (r0),y
	bne @return
	jsr Entities::Physic::set
	lda #<JUMP_V0X_RIGHT					; jump right
	sta player0 + PLAYER::entity + Entity::vtx
	lda #>JUMP_V0X_RIGHT
	sta player0 + PLAYER::entity + Entity::vtx+1
    lda #0
    sta player0 + PLAYER::flip
	rts

;************************************************
; try to move the player to the left of a ladder
;	
Left:
	lda player0 + PLAYER::entity + Entity::levelx
	and #$0f
	beq @check_left_tile

@mov_left:
	ldx #00							; set entity 0 (player)
	ldy #00							; do not check ground
	jsr Entities::Left				; if we are not a tile 0, right was already tested, so we continue
@check_ladders:
	lda player0 + PLAYER::entity + Entity::levelx
	and #$0f
	cmp #$08
	bcs @fall
@return:
	rts

@check_left_tile:
	jsr Entities::get_collision_map
	dec r0
	bpl :+
	dec r0H
:
	ldy #00
	lda (r0),y
	cmp #TILE::SOLID_LADER
	beq @mov_left
	jmp Climb::check_climb_left

@fall:
	jsr Entities::get_collision_map
	dec player0 + PLAYER::entity + Entity::levelx
	bpl :+
	dec player0 + PLAYER::entity + Entity::levelx + 1
:
	ldy #00
	lda (r0),y
	bne @return
	jsr Entities::Physic::set
	lda #<JUMP_V0X_LEFT					; jump right
	sta player0 + PLAYER::entity + Entity::vtx
	lda #>JUMP_V0X_LEFT
	sta player0 + PLAYER::entity + Entity::vtx+1
    lda #0
    sta player0 + PLAYER::flip
	rts

;************************************************
; try to move the player up a ladder
;	input: r3 = player address
;	only ladder a ladder if the 16 pixels mid-X are fully enclosed in the ladder
;	modify: r0, r1, r2
;	
Up:
	lda player0 + Entity::levely
	and #$0f
	beq @on_tile_border
	; in betwwen 2 tiles, just move up
@on_ladder:		
	lda #STATUS_CLIMBING
	ldy #Entity::status
	sta (r3),y

	jmp Entities::position_y_dec	; move up the ladder

@on_tile_border:
	jsr Entities::get_collision_map
	; check if we just exited a ladder
	ldy #00
	lda (r0), y
	bne @check_above
	ldy #LEVEL_TILES_WIDTH
	lda (r0), y
	bne @check_above
@quit_ladder:
	jmp Player::set_controler

@check_above:	
	sec
	lda r0L
	sbc #LEVEL_TILES_WIDTH
	sta r0L
	lda r0H
	sbc #0
	sta r0H

@test_head:
	ldy #0							; test on colum 0, line 2
	lda (r0L),y
	beq @on_ladder					; no collision upward
	tax
	lda tiles_attributes,x
	bit #TILE_ATTR::SOLID_CEILING
	bne @collision_up				; hit ceiling
	bit #TILE_ATTR::LADDER
	bne @on_ladder
@set_controler:
	stx laddersNeeded
	jsr Entities::position_y_dec	; move just over the ladder
	ldx laddersNeeded
	jmp Player::set_controler		; and let the player find the correct controler
@collision_up:
	rts								

;************************************************
; try to move the player down (crouch, hide, move down a ladder)
;	input: r3 = player address
;	
Down:
	lda player0 + Entity::levely
	and #$0f
	cmp #$0f
	beq @on_tile_border
	; in betwwen 2 tiles, just move down
@on_ladder:	
	lda #STATUS_CLIMBING
	ldy #Entity::status
	sta (r3),y
	jmp Entities::position_y_inc	; move down the ladder

@on_tile_border:
	; on last line of the curren tile
	jsr Entities::position_y_inc	; move down the ladder
	jsr Entities::get_collision_map

@test_below_feet:					; are we reaching a ground
	ldy #LEVEL_TILES_WIDTH*2
	lda (r0L),y
	tax
	lda tiles_attributes,x
	bit #TILE_ATTR::SOLID_GROUND
	bne @change_controler			; reach sold ground, switch to walk

@test_head:
	ldy #00
	lda (r0L),y						; check the tile below
	beq @test_feet
	tax
	lda tiles_attributes,x
	bit #TILE_ATTR::LADDER
	bne @on_ladder					; ladder or rope
	bra @change_controler
@test_feet:
	ldy #LEVEL_TILES_WIDTH
	lda (r0L),y						; check the tile below
	beq @change_controler
	tax
	lda tiles_attributes,x
	bit #TILE_ATTR::LADDER
	bne @on_ladder					; ladder or rope

@change_controler:
	txa
	jmp Player::set_controler

;************************************************
; change to ladder status
;	input: r3
;		A = tile attributes
;		Y = tile value
;	
Set:
	tya
	tax
	lda #STATUS_CLIMBING
	ldy #Entity::status
	sta (r3),y

	cpx #TILE::TOP_LADDER
	beq @ladder_sprite
	cpx #TILE::SOLID_LADER
	beq @ladder_sprite
@rope_sprite:
	lda #Player::Sprites::CLIMB_ROPE
	bra @set_sprite
@ladder_sprite:
	lda #Player::Sprites::CLIMB
@set_sprite:
	; reset animation frames
	sta player0 + PLAYER::frameID
	stz player0 + PLAYER::frame
	jsr Player::set_bitmap

	; align X on the ladder
	jsr Entities::align_on_tile

	; reset animation tick counter
	lda #10
	sta player0 + PLAYER::animation_tick	
	lda #01
	sta player0 + PLAYER::frameDirection

	; set virtual functions move right/meft
	lda #<Ladder::Right
	sta Entities::fnMoveRight_table
	lda #>Ladder::Right
	sta Entities::fnMoveRight_table+1
	lda #<Ladder::Left
	sta Entities::fnMoveLeft_table
	lda #>Ladder::Left
	sta Entities::fnMoveLeft_table+1

	; set virtual functions move up/down
	lda #<Ladder::Up
	sta Entities::fnMoveUp_table
	lda #>Ladder::Up
	sta Entities::fnMoveUp_table+1
	lda #<Ladder::Down
	sta Entities::fnMoveDown_table
	lda #>Ladder::Down
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

.endscope