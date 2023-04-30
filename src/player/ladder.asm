;**************************************************
; <<<<<<<<<< 	change to ladder status 	>>>>>>>>>>
;**************************************************

;************************************************
; Try to move player to the right of a ladder
; input: r3 = pointer to player
;	
ladder_right:
	lda player0 + PLAYER::entity + Entity::levelx
	and #$0f
	beq @check_right_tile

@mov_right:
	ldx #00
	ldy #00							; do not check ground
	jsr Entities::move_right
	beq @check_ladders
	rts								; blocked by tile, border or sprite
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
	beq @mov_right
	jmp Climb::check_climb_right


@fall:
	ldy #01
	lda (r0),y
	bne @return
	jsr Entities::kick_fall
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
ladder_left:
	lda player0 + PLAYER::entity + Entity::levelx
	and #$0f
	beq @check_left_tile

@mov_left:
	ldx #00
	ldy #00							; do not check ground
	jsr Entities::move_left
	beq @check_ladders
	rts								; blocked by tile, border or sprite
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
	jsr Entities::kick_fall
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
ladder_up:
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
	sec
	lda r0L
	sbc #LEVEL_TILES_WIDTH
	sta r0L
	lda r0H
	sbc #0
	sta r0H

	ldy #0							; test on colum 0, line 2
@test_head:
	lda (r0L),y
	beq @test_feet					; no collision upward
	cmp #TILE::LEDGE
	beq @on_ledge
	tay
	lda tiles_attributes,y
	bit #TILE_ATTR::SOLID_CEILING
	beq @on_ladder					; did not reach ceiling, move up
	rts								; else block move

@test_feet:
	ldy #(LEVEL_TILES_WIDTH*2)
	lda (r0L),y
	beq @no_ladder					; empty tile, drop
	tay
	lda tiles_attributes,y
	bit #TILE_ATTR::GRABBING
	bne @on_ladder					; ensure player feet is still on ladder
@no_ladder:
	jmp set_walk					; else move to walk status

@on_ledge:
	;jsr Entities::position_y_dec
	ldx #03							; move vertical down (+)
	jmp Climb::climb_start_animation

;************************************************
; try to move the player down (crouch, hide, move down a ladder)
;	input: r3 = player address
;	
ladder_down:
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
	jsr Entities::get_collision_map

@test_ladder:
	ldy #LEVEL_TILES_WIDTH
	lda (r0L),y						; check the tile below
	cmp #TILE::LEDGE				; rock to grab, set to climb
	beq @on_ledge
	cmp #TILE::SOLID_LADER			; ladder, continue down
	beq @on_ladder
	cmp #TILE::ROPE
	beq @on_ladder
	cmp #TILE::HANG_FROM
	bne @test_below_feet
@on_ledge:
	jsr Entities::position_y_inc
	jmp Climb::set_climb

@test_below_feet:
	ldy #LEVEL_TILES_WIDTH*3
	lda (r0L),y
	beq @fall					; nothing on feet level => test bellow the player
	tax
	lda tiles_attributes,x
	bit #TILE_ATTR::GRABBING
	bne @on_ladder					; ensure player is still holding a ladder
	bit #TILE_ATTR::SOLID_GROUND
	bne @set_walk					; reach sold ground, switch to walk

@fall:
	jsr Entities::position_y_inc	; move down the ladder, and switch to physics
	jsr set_walk
	jmp Entities::kick_fall

@set_walk:
	jsr Entities::position_y_inc	; move down the ladder, and switch to walk
	ldx #01							; move vertical down (+)
	jmp Climb::climb_start_animation

;************************************************
; change to ladder status
;	input: r3
;		A = tile value
;	
set_ladder:
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

	; reset animation tick counter
	lda #10
	sta player0 + PLAYER::animation_tick	
	lda #01
	sta player0 + PLAYER::frameDirection

	; set virtual functions move right/meft
	lda #<ladder_right
	sta Entities::fnMoveRight_table
	lda #>ladder_right
	sta Entities::fnMoveRight_table+1
	lda #<ladder_left
	sta Entities::fnMoveLeft_table
	lda #>ladder_left
	sta Entities::fnMoveLeft_table+1

	; set virtual functions move up/down
	lda #<Player::ladder_up
	sta Entities::fnMoveUp_table
	lda #>Player::ladder_up
	sta Entities::fnMoveUp_table+1
	lda #<Player::ladder_down
	sta Entities::fnMoveDown_table
	lda #>Player::ladder_down
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