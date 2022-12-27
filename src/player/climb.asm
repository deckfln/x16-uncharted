;**************************************************
; <<<<<<<<<< 	change to CLIMB status 	>>>>>>>>>>
;**************************************************

bClimb_direction = PLAYER_ZP
bClimbFrames = PLAYER_ZP + 1
bClimbHalfFrames = PLAYER_ZP + 2
bCounter = PLAYER_ZP + 3
wPositionY = PLAYER_ZP + 4

;************************************************
; start jump animation loop
; input r3 = current object pointer
;		bClimbFrames
;       x = direction : bit #1 = horizontal | vertical, bit #2 = + | -
climb_start_animation:
	stx bClimb_direction
	txa
	bit #01
	bne @vertical
@horizontal:
	lda bClimbFrames
	cmp #(TILE_WIDTH+1)
	bcc @no_jump
@jump:
	lsr
	sta bClimbHalfFrames
	lda #<Player::climb_animate_jump
	ldx #>Player::climb_animate_jump
	bra @set_animate
@no_jump:
	lda #Sprites::CLIMB_RIGHT
	sta player0 + PLAYER::frameID
	stz player0 + PLAYER::frame
	jsr Player::set_bitmap

	lda #$ff
	sta bClimbHalfFrames
	lda #16
	sta bCounter

	lda bClimb_direction
	bit #02
	beq @left
@right:
	lda #SPRITE_FLIP_H
	jsr Player::set_flip
	bra @def
@left:
	lda #SPRITE_FLIP_NONE
	jsr Player::set_flip
@def:

	lda #<Player::climb_animate_slide
	ldx #>Player::climb_animate_slide
	bra @set_animate
@vertical:
	lda #16
	sta bCounter
	lda #Sprites::CLIMB_UP
	sta player0 + PLAYER::frameID
	stz player0 + PLAYER::frame
	jsr Player::set_bitmap
	lda #<Player::climb_animate
	ldx #>Player::climb_animate

@set_animate:
	; register virtual function animate
	sta fnAnimate_table
	stx fnAnimate_table+1

	; save y
	lda player0 + PLAYER::entity + Entity::levely
	sta wPositionY
	lda player0 + PLAYER::entity + Entity::levely + 1
	sta wPositionY + 1

	jsr Player::set_noaction

	rts

;************************************************
; jump animation loop
; input r3

; jump from on ledge to the next one
climb_animate_jump:
	lda bClimb_direction
	bit #02
	bne @left
@right:
	jsr Entities::position_x_inc
	bra @jump
@left:
	jsr Entities::position_x_dec
@jump:	
	dec bClimbFrames				; run a limited number of frames
	beq @end_animation
	lda bClimbHalfFrames
	beq @down
@up:
	dec bClimbHalfFrames
	lda #00
	sta player0 + PLAYER::frame
	jsr Entities::position_y_dec
	bra @set_bitmap
@down:
	lda #02
	sta player0 + PLAYER::frame
	jsr Entities::position_y_inc
@set_bitmap:
	jmp Player::set_bitmap	
@end_animation:
	lda wPositionY
	ldy wPositionY + 1
	jsr Entities::position_y

	; pass through

change_state:
	jsr Entities::get_collision_map
	lda (r0)
	cmp #TILE_TOP_LADDER
	beq @ladder
	cmp #TILE_SOLID_LADER
	beq @ladder
	jmp set_climb
@ladder:
	jmp set_ladder

; slide from on ledge to the next one
climb_animate_slide:
	dec bCounter
	beq @slide2
	rts
@slide2:
	lda player0 + PLAYER::frame
	cmp #02
	beq change_state

	inc
	sta player0 + PLAYER::frame
	jsr Player::set_bitmap

	lda #16
	sta bCounter

	lda bClimb_direction
	bit #02
	bne @left
@right:
	clc
	lda player0 + PLAYER::entity + Entity::levelx
	adc #08
	tay
	lda player0 + PLAYER::entity + Entity::levelx + 1
	adc #00
	bra @set
@left:
	sec
	lda player0 + PLAYER::entity + Entity::levelx
	sbc #08
	tay
	lda player0 + PLAYER::entity + Entity::levelx + 1
	sbc #00
@set:
	tax
	tya
	jmp Entities::position_x

; slide from on ledge to the one above or below
climb_animate:
	dec bCounter
	beq @slide2
	rts
@slide2:
	lda player0 + PLAYER::frame
	cmp #02
	beq change_state

	inc
	sta player0 + PLAYER::frame
	jsr Player::set_bitmap

	lda #16
	sta bCounter

	lda bClimb_direction
	bit #02
	bne @down
@up:
	clc
	lda player0 + PLAYER::entity + Entity::levely
	adc #08
	tay
	lda player0 + PLAYER::entity + Entity::levely + 1
	adc #00
	bra @set
@down:
	sec
	lda player0 + PLAYER::entity + Entity::levely
	sbc #08
	tay
	lda player0 + PLAYER::entity + Entity::levely + 1
	sbc #00
@set:
	tax
	tya
	jmp Entities::position_y

;************************************************
; force player to be aligned with aclimb tile
; input: r3
;	Y = index of the tile tested
align_climb:
	; force player on the ladder tile
	lda player0 + Entity::levelx
	and #$0f
	bne :+				; already on a ladder tile
	rts
:
	tya
	bit #01
	bne @ladder_on_right
@ladder_on_left:
	lda player0 + Entity::levelx
	and #$f0						; force on the tile
	ldx player0 + Entity::levelx + 1
	bra @force_position

@ladder_on_right:
	lda player0 + Entity::levelx
	and #$f0						; force on the tile
	clc
	adc #$10
	tay
	lda player0 + Entity::levelx + 1
	adc #00
	tax
	tya
@force_position:
	jmp Entities::position_x

;************************************************
; force player to be aligned with aclimb tile
; input: r3
align_climb_y:
	; force player on the ladder tile
	lda player0 + Entity::levely
	and #$0f
	bne :+				; already on a ladder tile
	rts
:
	lda player0 + Entity::levely
	and #$f0						; force on the tile
	ldx player0 + Entity::levelx + 1
	jmp Entities::position_y

;************************************************
; Try to jump player to an right grab point
; input: r3 = pointer to player
;	
climb_right:
	lda player0 + PLAYER::entity + Entity::levelx + 1
	beq @go_on
	lda player0 + PLAYER::entity + Entity::levelx
	cmp #<(LEVEL_WIDTH - TILE_WIDTH)
	bcc @go_on
	rts									; if X > level_width-tile_width, reach right border
@go_on:
	jsr Entities::get_collision_map
	ldy #01
@get_tile:
	lda #TILE_WIDTH
	sta bClimbFrames
	lda (r0),y
	beq @check2					; no tile on left, retry on left + 1
	tax
	lda tiles_attributes,x
	bit #TILE_ATTR::GRABBING
	bne @jump_right
	rts
@check2:
	iny
	lda #(TILE_WIDTH*2)
	sta bClimbFrames
	lda (r0),y
	beq @return					; no tile on left, retry on left + 1
	tax
	lda tiles_attributes,x
	bit #TILE_ATTR::GRABBING
	bne @jump_right
@return:
	rts							; no escalade point on right and right + 1
@jump_right:
	ldx #0						; move horizontal right (+)
	jmp climb_start_animation

;************************************************
; try to move the player to the left of a ladder
;	
climb_left:
	lda player0 + PLAYER::entity + Entity::levelx + 1
	bne @go_on
	lda player0 + PLAYER::entity + Entity::levelx
	cmp #TILE_WIDTH
	bcs @go_on
	rts									; if X < 16, reach left border

@go_on:
	jsr Entities::get_collision_map
	sec
	lda r0L
	sbc #02
	sta r0L
	lda r0H
	sbc #00
	sta r0H							; mode 2 tiles back

	ldy #01
	lda #TILE_WIDTH
	sta bClimbFrames
@get_tile:
	lda (r0),y
	beq @check2						; no tile on left, try left - 2
	tax
	lda tiles_attributes,x
	bit #TILE_ATTR::GRABBING
	bne @jump_left
	rts
@check2:
	dey
	lda #(TILE_WIDTH*2)
	sta bClimbFrames
	lda (r0),y
	beq @return						; no tile on left, try left - 2
	tax
	lda tiles_attributes,x
	bit #TILE_ATTR::GRABBING
	bne @jump_left
@return:
	rts								; collision on left blocking the move
@jump_left:
	ldx #2							; move horizontal left (-)
	jmp climb_start_animation

;************************************************
; try to jump the player up an escalade point
;	input: r3 = player address
;	only climb a ladder if the 16 pixels mid-X are fully enclosed in the ladder
;	modify: r0, r1, r2
;	
climb_up:
	lda player0 + PLAYER::entity + Entity::levely + 1
	bne @go_on
	lda player0 + PLAYER::entity + Entity::levely
	cmp #TILE_WIDTH
	bcs @go_on
	rts									; if X < 16, reach left border

@go_on:
	jsr Entities::get_collision_map
	sec
	lda r0L
	sbc #LEVEL_TILES_WIDTH
	sta r0L
	lda r0H
	sbc #0
	sta r0H

	ldy #00
@test_above:
	lda #TILE_HEIGHT
	sta laddersNeeded
	lda (r0L),y
	beq @return					; no collision upward
	tax
	lda tiles_attributes,x
	bit #TILE_ATTR::GRABBING
	beq @return
@jump_up:
	ldx #3							; move vertical up (-)
	jmp climb_start_animation
@return:
	rts

;************************************************
; try to move the player down (crouch, hide, move down a ladder)
;	input: r3 = player address
;	
climb_down:
	lda player0 + PLAYER::entity + Entity::levely + 1
	beq @go_on
	lda player0 + PLAYER::entity + Entity::levely
	cmp #<(LEVEL_HEIGHT - TILE_WIDTH)
	bcc @go_on
	rts									; if X > level_width-tile_width, reach right border
@go_on:
	jsr Entities::get_collision_map
	lda #TILE_WIDTH
	sta laddersNeeded
	ldy #LEVEL_TILES_WIDTH
	lda (r0L),y
	beq @return							; nothing on feet level => 
	tax
	lda tiles_attributes,x
	bit #TILE_ATTR::GRABBING
	beq @return
@jump_down:
	ldx #1							; move horizontal down (+)
	jmp climb_start_animation
@return:
	rts

;************************************************
; change to CLIMB status
;	
set_climb:
	lda #STATUS_CLIMBING
	ldy #Entity::status
	sta (r3),y

	ldy #00
	jsr align_climb
	jsr align_climb_y

	; reset animation frames
	lda #Player::Sprites::CLIMB_UP
	sta player0 + PLAYER::frameID
	lda #01
	sta player0 + PLAYER::frame
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