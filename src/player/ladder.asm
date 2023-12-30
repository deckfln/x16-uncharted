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
	jsr Entities::try_right			; if we are not a tile 0, right was already tested, so we continue
	beq @check_right_pixel
	rts
@move_right:
	jsr Entities::position_x_inc
@check_right_pixel:
	jsr Player::animate
	jsr Entities::get_collision_head
	lda (r0),y
	cmp #TILE::SOLID_LADER
	bne @change_controler
@return:
	rts
@change_controler:
	tax
	jmp Player::set_controler		; let the entity decide what to do

@check_right_tile:
	jsr Entities::check_collision_right
	bne @return						; there is a collision on the right, so block the move
	ldy #02							; check_collision_right move the collision map one tile left
	lda (r0),y 
	beq @return						; nothing on the right, stick to the ladder
	cmp #TILE::SOLID_LADER
	beq @move_right					; move to a ladder on the right
@set_controler:
	ldx #TILE::SOLID_LADER
	jsr Transitions::get			; check how to move to the next tile
	bne @set_controler1
	ldy #Transitions::Transition::action
	lda (r1),y
	cmp #01							
	beq	@move_right						; move pixel by pixel to the next slide
@set_controler1:
	lda (r0)
	tax
	jmp Player::set_controler		; let the entity decide what to do

;************************************************
; try to move the player to the left of a ladder
;	
Left:
	lda player0 + PLAYER::entity + Entity::levelx
	and #$0f
	beq @check_left_tile

@try_left:
	ldx #00							; set entity 0 (player)
	ldy #00							; do not check ground
	jsr Entities::Left				; if we are not a tile 0, right was already tested, so we continue
	beq @check_left_pixel
	rts
@move_left:
	jsr Entities::position_x_dec
@check_left_pixel:
	jsr Player::animate
	jsr Entities::get_collision_head
	lda (r0),y
	cmp #TILE::SOLID_LADER
	bne @change_controler
@return:
	rts
@change_controler:
	tax
	jmp Player::set_controler		; let the entity decide what to do

@check_left_tile:
	jsr Entities::check_collision_left
	bne @return						; there is a collision on the left, so block the move
	lda (r0)						; check_collision_right move the collision map one tile left
	beq @return						; nothing on the left, stick to the ladder
	cmp #TILE::SOLID_LADER
	beq @move_left					; move the a ladder on the left

	ldx #TILE::SOLID_LADER
	jsr Transitions::get			; check how to move to the next tile
	bne @set_controler
	ldy #Transitions::Transition::action
	lda (r1),y
	cmp #01							
	beq	@move_left					; move pixel by pixel to the next slide

@set_controler:	
	tax
	jmp Player::set_controler		; let the entity decide what to do

;************************************************
; try to move the player up a ladder
;	input: r3 = player address
;	only ladder a ladder if the 16 pixels mid-X are fully enclosed in the ladder
;	modify: r0, r1, r2
;	
Up:
	lda player0 + PLAYER::entity + Entity::levelx
	and #$0f
	beq @on_tile_x
	jsr Entities::align_on_x_tile	; force player on the tile

@on_tile_x:
	lda player0 + Entity::levely
	and #$0f
	beq @on_tile_border
	; in betwwen 2 tiles, just move up
@move_up_pixel:
	jsr Player::animate
	jmp Entities::position_y_dec	; move up the ladder

@on_tile_border:
	jsr Entities::check_collision_up
	beq :+
	rts								; reached the top of the screen, or a SOLID_CEILING
:
	jsr Entities::position_y_dec
	jsr Entities::get_collision_map

	; check the tile above  the player head
@head:
	ldy #00
	lda (r0),y
	beq @feet					; if player half in the air (torso on empty tile)
	tax
	lda tiles_attributes,x
	bit #TILE_ATTR::LADDER
	bne @move_up_pixel			; top of the ladder is a ceiling

@feet:
	ldy #LEVEL_TILES_WIDTH
	lda (r0),y
	beq @retract
	sta Player::tmp_player
	tax
	beq @change_controler		; if player half in the air (torso on empty tile)
	lda tiles_attributes,x
	bit #TILE_ATTR::LADDER
	bne @move_up_pixel

@change_controler:
	txa
	ldx #TILE::SOLID_LADER
	jsr Transitions::get
	bne @set_controler
	ldy #Transitions::Transition::action
	lda (r1),y
	cmp #01							
	beq	@move_up_pixel			; move pixel by pixel to the next slide
	jsr Entities::position_y_dec
	jsr Transitions::run

@set_controler:
	ldx Player::tmp_player
	jmp Player::set_controler	; feet defines the new controler

@retract:
	jmp Entities::position_y_inc; restore the position

;************************************************
; try to move the player down (crouch, hide, move down a ladder)
;	input: r3 = player address
;	
Down:
	lda player0 + PLAYER::entity + Entity::levelx
	and #$0f
	beq @on_tile_x
	jsr Entities::align_on_x_tile	; force player on the tile

@on_tile_x:
	lda player0 + Entity::levely
	and #$0f
	beq @on_tile_border
	; in betwwen 2 tiles, just move down
@on_ladder:	
	jsr Player::animate
	jmp Entities::position_y_inc	; move down the ladder

@on_tile_border:
	jsr Entities::check_collision_down
	beq :+
	rts										; reached the bottom  of the screen, or a sprite
:
	jsr Entities::get_collision_feet
	lda (r0),y
	tax
	lda tiles_attributes,x
	bit #TILE_ATTR::SOLID_GROUND
	bne @change_controler			; if feet tile is already on a solid_ground

	jsr Entities::position_y_inc	; move down the ladder
	jsr Entities::get_collision_map
	lda (r0)						; check the tile at head level
	beq @test_feet					; nothing to stick at ?
	tax
	lda tiles_attributes,x
	bit #TILE_ATTR::LADDER
	bne @on_ladder					; ladder or rope, so go on

@test_feet:							; are we reaching a ground
	jsr Entities::get_collision_feet
	lda (r0L),y
	beq @change_controler			; nothing to hang from (head level), nothing to rest on (feet level) => drop
	tax
	lda tiles_attributes,x
	bit #TILE_ATTR::LADDER
	bne @on_ladder					; still on a ladder

@change_controler:
	jmp Player::set_controler

;************************************************
; change to ladder status
;	input: r3
;		A = tile attributes
;		X = tile value
;	
Set:
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

	; align X & Y on the tile
	;jsr Entities::align_on_x_tile
	;jsr Ladder::align_on_y_tile
	
	; reset animation tick counter
	lda #10
	sta player0 + PLAYER::animation_tick	
	lda #01
	sta player0 + PLAYER::frameDirection

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

	; set the proper update
	ldy #Entity::update
	lda #<Update
	sta (r3),y
	iny
	lda #>Update
	sta (r3),y

	rts

;*******************************
; force the player position on the ladder
;  going from platform to ladder below : player is half above the top of the ladder
;  going from platform to ladder above
;  going from platform to ladder at the same level : just switch
;
align_on_y_tile:
	jsr Entities::get_collision_map	
	lda (r0)						; get tile on the head of the player
	tax
	lda tiles_attributes,x
	bit #TILE_ATTR::LADDER
	bne @head_on_ladder
	jsr Entities::get_collision_feet
	lda (r0),y
	tax
	lda tiles_attributes,x
	bit #TILE_ATTR::LADDER
	bne @feet_on_ladder
@error:
	brk								; not head no feet on a ladder, what's going on

@head_on_ladder:
	rts								; actually, there is nothing to do, we are just picking the ladder

@feet_on_ladder:
	clc
	ldy #Entity::levely
	lda (r3),y
	and #$f0						; align Y on 0
	adc #TILE_HEIGHT				; then move down 1 tile height
	sta tmp_player
	iny
	lda (r3),y
	adc #00
	tax
	lda tmp_player

	jmp Entities::position_y

.endscope