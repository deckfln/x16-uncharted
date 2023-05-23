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
; start jump animation loop
; input r3 = current object pointer
;		bClimbFrames
;       x = direction : bit #1 = horizontal | vertical, bit #2 = + | -
start_animation:
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
	lda #<Climb::animate_jump
	ldx #>Climb::animate_jump
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

	lda #<Climb::climb_animate_slide
	ldx #>Climb::climb_animate_slide
	bra @set_animate
@vertical:
	lda #16
	sta bCounter
	lda #Sprites::CLIMB_UP
	sta player0 + PLAYER::frameID
	stz player0 + PLAYER::frame
	jsr Player::set_bitmap
	lda #<Climb::climb_animate
	ldx #>Climb::climb_animate

@set_animate:
	; register virtual function animate
	sta fnAnimate_table
	stx fnAnimate_table+1

	; save y
	lda player0 + PLAYER::entity + Entity::levely
	sta wPositionY
	lda player0 + PLAYER::entity + Entity::levely + 1
	sta wPositionY + 1

	lda #%11111111			; block ALL actions
	jsr Player::set_noaction

	rts

;************************************************
; jump animation loop
; input r3

; jump from on ledge to the next one
animate_jump:
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
	jmp Player::set_controler

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
	ldx player0 + Entity::levely + 1
	jmp Entities::position_y

;************************************************
; Try to jump player to an right grab point
; input: r3 = pointer to player
;	
Right:
	lda player0 + PLAYER::entity + Entity::levelx + 1
	beq @go_on
	lda player0 + PLAYER::entity + Entity::levelx
	cmp #<(LEVEL_WIDTH - TILE_WIDTH)
	bcc @go_on
	rts									; if X > level_width-tile_width, reach right border
@go_on:
	lda player0 + PLAYER::entity + Entity::levelx
	and #$0f
	beq @test_right
	ldx #00							; set entity 0 (player)
	ldy #00							; do not check ground
	jmp Entities::move_right		; if we are not a tile 0, right was already tested, so we continue

@test_right:
	stz bForceJump
	jsr Entities::get_collision_map
	lda (r0)
	cmp #TILE::HANG_FROM
	bne @tile_after
	lda #01
	sta bForceJump
@tile_after:

	ldy #01
@get_tile:
	lda #TILE_WIDTH
	sta bClimbFrames
	lda (r0),y
	beq @check2					; no tile on left, retry on left + 1
	tax
	lda tiles_attributes,x
	bit #TILE_ATTR::GRABBING
	bne @jump_slide_right
	rts
@jump_slide_right:
	cpx #TILE::LEDGE
	beq @slide_right
	cpx #TILE::TOP_LEDGE
	bne @jump_right				; next tile is not a ledge, so we jump to the tile
@slide_right:
	lda bForceJump
	bne @jump_right

	lda #02
	sta player0 + PLAYER::animation_tick
	lda #STATUS_CLIMBING
	sta player0 + PLAYER::entity + Entity::status
	ldx #00						; set entity 0 (player)
	ldy #00						; do not check ground
	jmp Entities::move_right	; next tile is a ledge, so we slide pixel by pixel

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
	jmp start_animation

;************************************************
; enter the climb mode and jump right to reach a ledge
;	
check_climb_right:
	lda #TILE_WIDTH
	sta bClimbFrames
	lda (r0),y
	beq @check2					; no tile on left, retry on left + 1
	tax
	lda tiles_attributes,x
	bit #TILE_ATTR::GRABBING
	bne @jump_slide_right
	rts
@jump_slide_right:
	cpx #TILE::LEDGE
	beq @jump_right
	cpx #TILE::TOP_LEDGE
	bne @jump_right				; next tile is not a ledge, so we jump to the tile
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
	jsr Climb::Set
	ldx #0						; move horizontal right (+)
	jmp start_animation

;************************************************
; try to move the player to the left of a ladder
;	
Left:
	lda player0 + PLAYER::entity + Entity::levelx + 1
	bne @go_on
	lda player0 + PLAYER::entity + Entity::levelx
	cmp #TILE_WIDTH
	bcs @go_on
	rts									; if X < 16, reach left border

@go_on:
	lda player0 + PLAYER::entity + Entity::levelx
	and #$0f
	beq @test_left
	ldx #00							; set entity 0 (player)
	ldy #00							; do not check ground
	jmp Entities::move_left			; if we are not a tile 0, right was already tested, so we continue

@test_left:
	stz bForceJump
	jsr Entities::get_collision_map
	lda (r0)
	cmp #TILE::HANG_FROM
	bne @tiles_before
	lda #01
	sta bForceJump
@tiles_before:
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
	bne @jump_slide_left
	rts
@jump_slide_left:
	lda (r0),y
	cmp #TILE::LEDGE
	beq @slide_left
	cmp #TILE::TOP_LEDGE
	bne @jump_left				; next tile is not a ledge, so we jump to the tile
@slide_left:
	lda bForceJump
	bne @jump_left

	lda #02
	sta player0 + PLAYER::animation_tick
	lda #STATUS_CLIMBING
	sta player0 + PLAYER::entity + Entity::status
	ldx #00						; set entity 0 (player)
	ldy #00							; do not check ground
	jmp Entities::move_left	; next tile is a ledge, so we slide pixel by pixel

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
	jmp start_animation

;************************************************
; enter the climb mode and jump right to reach a ledge
;	
check_climb_left:
	sec
	lda r0L
	sbc #01
	sta r0L
	lda r0H
	sbc #00
	sta r0H							; mode 2 tiles back

	lda #TILE_WIDTH
	sta bClimbFrames

	ldy #01
	lda (r0),y
	beq @check2					; no tile on left, retry on left + 1
	tax
	lda tiles_attributes,x
	bit #TILE_ATTR::GRABBING
	bne @jump_slide_left
	rts
@jump_slide_left:
	cpx #TILE::LEDGE
	beq @jump_left
	cpx #TILE::TOP_LEDGE
	bne @jump_left				; next tile is not a ledge, so we jump to the tile
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
	bne @jump_left
@return:
	rts							; no escalade point on right and right + 1
@jump_left:
	jsr Climb::Set
	ldx #02						; move horizontal left (-)
	jmp start_animation

;************************************************
; try to jump the player up an escalade point
;	input: r3 = player address
;	only climb a ladder if the 16 pixels mid-X are fully enclosed in the ladder
;	modify: r0, r1, r2
;	
Up:
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
	beq @check_walk					; no collision upward
	tax
	lda tiles_attributes,x
	bit #TILE_ATTR::GRABBING
	bne @jump_up
	rts
@jump_up:
	ldx #3							; move vertical up (-)
	jmp start_animation
@check_walk:
	ldy #LEVEL_TILES_WIDTH
	lda (r0L),y
	cmp #TILE::TOP_LEDGE
	beq @set_walk
	rts
@set_walk:
	sec
	lda player0 + Entity::levely
	sbc player0 + Entity::bHeight
	tay
	lda player0 + Entity::levely + 1
	sbc #00
	tax
	tya
	jsr Entities::position_y			; force the player at ground level
	jmp set_walk

;************************************************
; try to move the player down (crouch, hide, move down a ladder)
;	input: r3 = player address
;	
Down:
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
	ldx #1							; move vertical down (+)
	jmp start_animation
@return:
	rts

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
	jmp Player::set_walk

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
	jsr Player::set_walk
	lda bForceJump
	jmp Player::jump

;************************************************
; change to CLIMB status
;	
Set:
	lda #STATUS_CLIMBING
	ldy #Entity::status
	sta (r3),y

	ldy #00
	jsr align_climb
	jsr align_climb_y

	; disengage physics engine for that entity
	ldy #Entity::bFlags
	lda (r3),y
	and #(255-EntityFlags::physics)
	sta (r3),y						

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
	lda #<Climb::Right
	sta Entities::fnMoveRight_table
	lda #>Climb::Right
	sta Entities::fnMoveRight_table+1
	lda #<Climb::Left
	sta Entities::fnMoveLeft_table
	lda #>Climb::Left
	sta Entities::fnMoveLeft_table+1

	; set virtual functions move up/down
	lda #<Climb::Up
	sta Entities::fnMoveUp_table
	lda #>Climb::Up
	sta Entities::fnMoveUp_table+1
	lda #<Climb::Down
	sta Entities::fnMoveDown_table
	lda #>Climb::Down
	sta Entities::fnMoveDown_table+1

	; set virtual functions walk jump
	lda #<Climb::Jump
	sta fnJump_table
	lda #>Climb::Jump
	sta fnJump_table+1

	; set virtual functions walk grab
	lda #<Climb::Release
	sta fnGrab_table
	lda #>Climb::Release
	sta fnGrab_table+1

	; set virtual functions walk animate
	lda #<Player::animate
	sta fnAnimate_table
	lda #>Player::animate
	sta fnAnimate_table+1

	rts

	.endscope