;**************************************************
; <<<<<<<<<< 	change to ladder status 	>>>>>>>>>>
;**************************************************

;************************************************
; Try to move player to the right of a ladder
; input: r3 = pointer to player
;	
ladder_right:
	ldx #00
	jsr Entities::move_right
	beq @check_ladders
	rts								; blocked by tile, border or sprite
@check_ladders:
	jsr Entities::get_collision_map
	ldy #01
	sty tileStart
	stz laddersFound

	lda player0 + PLAYER::entity + Entity::levely
	and #$0f
	beq :+
	ldx #03
	bra @get_tile
:
	ldx #02
@get_tile:
	lda (r0),y
	beq @next_line					; no tile on left
	sta $31
	tay
	lda tiles_attributes,y
	bit #TILE_ATTR::GRABBING
	bne @get_ladder					; collision on left with a GRAB attribute
	rts								; collision on left blocking the move
@get_ladder:
	inc laddersFound
@next_line:
	dex
	beq @last_line
	lda tileStart
	clc
	adc #LEVEL_TILES_WIDTH
	sta tileStart
	tay
	bra @get_tile
@last_line:
	lda laddersFound
	beq @ladder_left_drop

	lda $31							; tile index with grab attribute
	cmp #TILE_LEDGE
	beq @set_climb
    rts
@set_climb:
    jmp Player::set_climb

@ladder_left_drop:					; no ladder to stick to
    lda #0
    sta player0 + PLAYER::flip
	jmp set_walk

;************************************************
; try to move the player to the left of a ladder
;	
ladder_left:
	ldx #00
	jsr Entities::move_left
	beq @check_ladders
	rts								; blocked by tile, border or sprite
@check_ladders:
	jsr Entities::get_collision_map
	ldy #00
	sty tileStart
	stz laddersFound

	lda player0 + PLAYER::entity + Entity::levely
	and #$0f
	beq :+
	ldx #03
	bra @get_tile
:
	ldx #02
@get_tile:
	lda (r0),y
	beq @next_line					; no tile on left
	sta $31
	tay
	lda tiles_attributes,y
	bit #TILE_ATTR::GRABBING
	bne @get_ladder					; collision on left with a GRAB attribute
	rts								; collision on left blocking the move
@get_ladder:
	inc laddersFound
@next_line:
	dex
	beq @last_line
	lda tileStart
	clc
	adc #LEVEL_TILES_WIDTH
	sta tileStart
	tay
	bra @get_tile
@last_line:
	lda laddersFound
	beq @ladder_left_drop

	lda $31							; tile index with grab attribute
	cmp #TILE_LEDGE
	beq @set_climb
    rts
@set_climb:
    jmp set_climb
@ladder_left_drop:					; no ladder to stick to
    lda #0
    sta player0 + PLAYER::flip
	jmp set_walk

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
	; exactly on tile
	jsr Entities::get_collision_map

@test_feet:
	ldy #LEVEL_TILES_WIDTH*3
	lda (r0L),y
	beq @test_hand					; nothing on feet level => 
	tax
	lda tiles_attributes,x
	bit #TILE_ATTR::GRABBING
	bne @on_ladder					; ensure player is still holding a ladder
	bit #TILE_ATTR::SOLID_GROUND
	bne @set_walk					; reach sold ground, switch to walk

@test_hand:
	tya
	sec
	sbc #(LEVEL_TILES_WIDTH *3 )
	tay
	lda (r0L),y
	beq @fall						; empty tile, drop
	tax
	lda tiles_attributes,x
	bit #TILE_ATTR::GRABBING
	bne @on_ladder					; ensure player is still holding a ladder

@fall:
	jsr Entities::position_y_inc	; move down the ladder, and switch to physics
	jmp set_walk

@set_walk:
	jsr Entities::position_y_inc	; move down the ladder, and switch to walk
	jmp set_walk

;************************************************
; change to ladder status
;	
set_ladder:
	lda #STATUS_CLIMBING
	ldy #Entity::status
	sta (r3),y

	; reset animation frames
	lda #Player::Sprites::CLIMB
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