;**************************************************
; <<<<<<<<<< 	change to CLIMB status 	>>>>>>>>>>
;**************************************************

;************************************************
; Try to move player to the right of a ladder
; input: r3 = pointer to player
;	
climb_right:
	ldx #00
	jsr Entities::move_right
	beq @continue_climb
	rts								; blocked by tile, border or sprite
@continue_climb:
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
	jsr Player::set_bitmap
	m_status STATUS_CLIMBING
	rts
@climb_right_drop:
    lda #01
    sta player0 + PLAYER::flip
	jmp set_walk

;************************************************
; try to move the player to the left of a ladder
;	
climb_left:
	ldx #00
	jsr Entities::move_left
	beq @continue_climb
	rts								; blocked by tile, border or sprite
@continue_climb:
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
	jsr Player::set_bitmap
	m_status STATUS_CLIMBING
	rts
@climb_left_drop:					; no ladder to stick to
    lda #0
    sta player0 + PLAYER::flip
	jmp set_walk

;************************************************
; try to move the player up a ladder
;	input: r3 = player address
;	only climb a ladder if the 16 pixels mid-X are fully enclosed in the ladder
;	modify: r0, r1, r2
;	
climb_up:
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

	lda player0 + Entity::levelx
	and #$0f
	bne :+
	ldy #0							; test on colum 0, line 2
	bra @test_head
: 
	cmp #04
	bcc :+
	ldy #1							; x%16 <= 4 : test on column 1, line 2
	bra @test_head
:
	ldy #00							; test on colum 0, line 0

@test_head:
	sty addrSaveR0L
	lda (r0L),y
	beq @test_feet					; no collision upward
	tay
	lda tiles_attributes,y
	bit #TILE_ATTR::SOLID_CEILING
	beq @on_ladder					; did not reach ceiling, move up
	rts								; else block move

@test_feet:
	lda addrSaveR0L
	clc
	adc #(LEVEL_TILES_WIDTH*2)
	tay
	lda (r0L),y
	beq @no_ladder					; empty tile, drop
	cmp #TILE_SOLID_LADER
	beq @on_ladder					; ensure player feet is still on ladder
@no_ladder:
	jmp set_walk					; else move to walk status

;************************************************
; try to move the player down (crouch, hide, move down a ladder)
;	input: r3 = player address
;	
climb_down:
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
@test_x:
	lda player0 + Entity::levelx
	and #$0f
	bne :+
	ldy #LEVEL_TILES_WIDTH*3		; test on colum 0, line 2
	bra @test_feet
: 
	cmp #04
	bcc :+
	ldy #(LEVEL_TILES_WIDTH*3 + 1)	; x%16 <= 4 : test on column 1, line 2
	bra @test_feet
:
	ldy #LEVEL_TILES_WIDTH*3		; test on colum 0, line 2

@test_feet:
	lda (r0L),y
	beq @test_hand					; nothing on feet level => 
	cmp #TILE_SOLID_LADER
	beq @on_ladder					; ensure player is still holding a ladder
	tay
	lda tiles_attributes,y
	bit #TILE_ATTR::SOLID_GROUND
	bne @set_walk					; reach sold ground, switch to walk

@test_hand:
	tya
	sec
	sbc #(LEVEL_TILES_WIDTH *3 )
	tay
	lda (r0L),y
	beq @fall						; empty tile, drop
	cmp #TILE_SOLID_LADER
	beq @on_ladder					; ensure player is still holding a ladder

@fall:
	jsr Entities::position_y_inc	; move down the ladder, and switch to physics
	jmp set_walk

@set_walk:
	jsr Entities::position_y_inc	; move down the ladder, and switch to walk
	jmp set_walk

;************************************************
; change to CLIMB status
;	
set_climb:
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
	lda #<climb_right
	sta Entities::fnMoveRight_table
	lda #>climb_right
	sta Entities::fnMoveRight_table+1
	lda #<climb_left
	sta Entities::fnMoveLeft_table
	lda #>climb_left
	sta Entities::fnMoveLeft_table+1

	; set virtual functions move up/down
	lda #<Player::climb_up
	sta Entities::fnMoveUp_table
	lda #>Player::climb_up
	sta Entities::fnMoveUp_table+1
	lda #<Player::climb_down
	sta Entities::fnMoveDown_table
	lda #>Player::climb_down
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