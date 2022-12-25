;**************************************************
; <<<<<<<<<< 	change to SWIM status 	>>>>>>>>>>
;**************************************************

;************************************************
; Virtual function : Try to swim player to the right
;	
swim_right:
	ldx #00
	jsr Entities::move_right
	beq @set_sprite
	rts							; blocked by tile, border or sprite

@set_sprite:
	lda #SPRITE_FLIP_H
	sta player0 + PLAYER::flip
	ldy player0 + PLAYER::entity + Entity::spriteID
	jsr Sprite::set_flip				; force sprite to look right
	rts

;************************************************
; Virtual function : Try to swim player to the left
;	
swim_left:
	ldx #00
	jsr Entities::move_left
	beq @set_sprite
	rts							; blocked by tile, border or sprite

@set_sprite:
	lda #SPRITE_FLIP_NONE
	sta player0 + PLAYER::flip
	ldy player0 + PLAYER::entity + Entity::spriteID
	jsr Sprite::set_flip				; force sprite to loop left
	rts

;************************************************
; Virtual function : Try to swim player to the up
;	
swim_up:
	ldx #00
	jsr Entities::save_position_r3		; r3 is already defined
	jsr Entities::move_up

	; check if we are still in the water. 
	jsr Entities::get_collision_map		; r0 is modified by move_up, so reload
	ldy #00
	lda (r0),y							; Top-left corner of the entity
	cmp #TILE_WATER
	bne @block_move_up					; has to be on a water tile
	rts
@block_move_up:
	jsr Entities::restore_position
	rts

;************************************************
; Virtual function : Try to swim player to the down
;	
swim_down:
	jmp Entities::move_down

;************************************************
; Virtual function : block jump when swiming
;	
swim_jump:
	rts

;************************************************
; run animation get out of water
;
swin_animate_out_water:
	lda player0 + Entity::levely
	and #$0f
	beq @stage1
	; move to the same level as the grab tile
	; r3 = *player
	lda #<player0
	sta r3L
	lda #>player0
	sta r3H
	jsr Entities::position_y_dec
	rts
@stage1:
	; register virtual function animate
	lda #<Player::swin_animate_out_water1
	sta fnAnimate_table
	lda #>Player::swin_animate_out_water1
	sta fnAnimate_table+1

	lda #01
	sta player0 + PLAYER::frame
	jsr Player::set_bitmap	

	; reset animation tick counter
	lda #8
	sta player0 + PLAYER::animation_tick	
	rts

swin_animate_out_water1:
	; r3 = *player
	lda #<player0
	sta r3L
	lda #>player0
	sta r3H
	
	jsr Entities::position_y_dec
	jsr Entities::position_y_dec

	lda PLAYER_ZP + 1
	beq @right
@left:
	jsr Entities::position_x_dec
	jsr Entities::position_x_dec
	bra :+
@right:
	jsr Entities::position_x_inc
	jsr Entities::position_x_inc
:
	dec player0 + PLAYER::animation_tick
	beq @stage2
	rts
@stage2:
	; register virtual function animate
	lda #<Player::swin_animate_out_water2
	sta fnAnimate_table
	lda #>Player::swin_animate_out_water2
	sta fnAnimate_table+1

	lda #02
	sta player0 + PLAYER::frame
	jsr Player::set_bitmap	

	; reset animation tick counter
	lda #8
	sta player0 + PLAYER::animation_tick	
	rts

swin_animate_out_water2:
	lda #<player0
	sta r3L
	lda #>player0
	sta r3H
	jsr Entities::position_y_dec
	jsr Entities::position_y_dec
	dec player0 + PLAYER::animation_tick
	beq @stage3
	rts
@stage3:
	jmp Player::set_walk


;************************************************
; Virtual function : block jump when swiming
;	
swim_grab:
	lda player0 + Entity::levelx
	and #$0f
	beq @test_grab_tile
	rts

@test_grab_tile:	
	lda #<player0
	sta r3L
	lda #>player0
	sta r3H
	jsr Entities::get_collision_map

	lda #00
	sta PLAYER_ZP + 1

	lda player0 + PLAYER::flip
	bne @right
@left:
	sec
	lda r0L
	sbc #02
	sta r0L
	lda r0H
	sbc #00
	sta r0H
	inc PLAYER_ZP + 1
@right:
	ldy #01
	lda (r0),y		
	tay
	lda tiles_attributes,y
	bit #TILE_ATTR::SOLID_GROUND
	bne @get_out_water
	rts

@get_out_water:
	; swap to an animation only mode
	; set virtual functions swim right/meft
	lda #<Player::noaction
	sta Entities::fnMoveRight_table
	lda #>Player::noaction
	sta Entities::fnMoveRight_table+1
	lda #<Player::noaction
	sta Entities::fnMoveLeft_table
	lda #>Player::noaction
	sta Entities::fnMoveLeft_table+1

	; set virtual functions move up/down
	lda #<Player::noaction
	sta Entities::fnMoveUp_table
	sta Entities::fnMoveDown_table
	lda #>Player::noaction
	sta Entities::fnMoveUp_table+1
	sta Entities::fnMoveDown_table+1

	; set virtual functions swim jump
	; set virtual functions swim grab
	lda #<Player::noaction
	sta fnJump_table
	sta fnGrab_table
	lda #>Player::noaction
	sta fnJump_table+1
	sta fnGrab_table+1

	; register virtual function animate
	lda #<Player::swin_animate_out_water
	sta fnAnimate_table
	lda #>Player::swin_animate_out_water
	sta fnAnimate_table+1

	; start out of water animation loop
	lda #Player::Sprites::SWIM_OUT_WATER
	sta player0 + PLAYER::frameID
	lda #00
	sta player0 + PLAYER::frame
	jsr Player::set_bitmap	

	rts

;************************************************
; change to SWIM status
;	
set_swim:
	lda #STATUS_SWIMING
	ldy #Entity::status
	sta (r3),y

	; reset animation frames
	lda #Player::Sprites::SWIM
	sta player0 + PLAYER::frameID
	stz player0 + PLAYER::frame
	jsr Player::set_bitmap

	; reset animation tick counter
	lda #10
	sta player0 + PLAYER::animation_tick	
	lda #01
	sta player0 + PLAYER::frameDirection

	; set virtual functions swim right/meft
	lda #<swim_right
	sta Entities::fnMoveRight_table
	lda #>swim_right
	sta Entities::fnMoveRight_table+1
	lda #<swim_left
	sta Entities::fnMoveLeft_table
	lda #>swim_left
	sta Entities::fnMoveLeft_table+1

	; set virtual functions swim up/down
	lda #<swim_up
	sta Entities::fnMoveUp_table
	lda #>swim_up
	sta Entities::fnMoveUp_table+1
	lda #<swim_down
	sta Entities::fnMoveDown_table
	lda #>swim_down
	sta Entities::fnMoveDown_table+1

	; set virtual functions swim jump
	lda #<swim_jump
	sta fnJump_table
	lda #>swim_jump
	sta fnJump_table+1

	; set virtual functions swim grab
	lda #<swim_grab
	sta fnGrab_table
	lda #>swim_grab
	sta fnGrab_table+1

	rts
