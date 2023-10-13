.scope Walk

;************************************************
; Macro to help the controler identity the component
;
.macro Entity_Walk_check
	bit #TILE_ATTR::SOLID_GROUND
	beq :+
	jmp Walk::set
:
.endmacro

;************************************************
; Activate the walk component
;
set:
	jsr Entities::fn_restore_action
	jmp Entities::set_physics
	rts

;************************************************
; Try to move entity to the right
;	input : X = entity ID
;			Y = check ground or not
;	return: A = 00 => succeeded to move
;			A = ff => error_right_border
;			A = 02 => error collision on right
;	
right:
	sty bCheckGround
	; cannot move if we are at the border
	ldy #Entity::levelx + 1
	lda (r3), y
	cmp #>LEVEL_WIDTH
	bne @not_border
	dey
	lda (r3), y
	sta bSaveX
	ldy #Entity::bWidth
	lda (r3), y
	clc
	adc bSaveX
	beq @not_border
	cmp #<LEVEL_WIDTH
	bne @not_border

@failed_border:
	lda #$ff
	rts

@not_border:
	jsr Entities::check_collision_right		; R0 is on tile on the left of the current position
	beq @no_collision
	cmp #Collision::SLOPE
	beq @no_collision						; if we are straight on a slope, move on
	rts										; return the collision tile code

@no_collision:
	;test the current tile the entity is walking on
	ldy #Entity::bFeetIndex
	lda (r3), y								; delta Y to get the feet tile
	inc										; move to r0 + 1 to compensate for r0 on he left
	tay
	lda (r0),y
	sta bCurentTile
	cmp #TILE::SOLD_SLOP_LEFT
	beq @go_up_slope
	cmp #TILE::SLIDE_LEFT
	beq @go_up_slide						; walk up but activate sliding to go back
	cmp #TILE::SOLD_SLOP_RIGHT
	beq @go_down_slope

	tax
	lda tiles_attributes,x
	bit #TILE_ATTR::SOLID_GROUND
	bne @go_right							; feet are on a tile with SOLID_GROUND attribute
@fall:										
	lda #00
	jmp Entities::set_controler				; feet are not on a solid ground => fall

	
@go_right:									; move the entity in the level on the x axe
	jsr Entities::position_x_inc
	bra @check_ground
@go_up_slope:
	jsr Entities::position_x_inc
	jsr Entities::position_y_dec
	bra @check_ground
@go_down_slope:
	jsr Entities::position_x_inc
	jsr Entities::position_y_inc
	bra @check_ground
@go_up_slide:
	jsr Entities::position_x_inc					; walk up the slide on the right
	jsr Entities::position_y_dec
	ldy #Entity::levelx
	lda (r3),y
	and #$0f
	bne @check_ground				   ; still on some solide tile
	jsr Entities::sever_link		   ; on thin air, so we shall fall => if the entity is connected to another, sever the link
    ldx #TILE_ATTR::NONE
	jmp Entities::go_class_controler


@check_ground:
	lda bCheckGround
	beq @return

	jsr check_collision_down
	beq @fall						;Collision::None
	cmp #Collision::SCREEN
	beq @collision_screen
	cmp #Collision::SLOPE
	beq @above_slope
	cmp #Collision::IN_GROUND		; wen entered ground, so move above
	beq @walk_on_ground

	; Collision::GROUND
@return:
	lda #00
	rts

@collision_screen:
	lda #$ff
	rts

@walk_on_ground:
	jsr Entities::position_y_dec	; move the entity on top of the ground
	lda #00
	rts

@above_slope:
	lda bCurentTile
	cmp #TILE::SLIDE_RIGHT
	beq @set_slide_right
	cmp #TILE::SOLD_SLOP_RIGHT
	bne @return
@set_right:
	jsr Entities::position_y_inc
	lda #00
	rts
@set_slide_right:
	jsr Entities::position_y_inc
	jsr Entities::sever_link						; if the entity is connected to another, sever the link
    ldx #TILE::SOLD_SLOP_RIGHT
	jmp Entities::go_class_controler

;************************************************
; Try to move entity to the left
;	input : X = entity ID
;	return: A = 00 => succeeded to move
;			A = ff => error_right_border
;			A = 02 => error collision on right
;	
left:
	sty bCheckGround

	; cannot move if we are at the left border
	ldy #Entity::levelx + 1
	lda (r3), y
	bne @not_border
	dey
	lda (r3), y
	bne @not_border

@failed_border:
	lda #$ff
	rts

@not_border:
	jsr Entities::check_collision_left
	beq @no_collision
	cmp #Collision::SLOPE
	beq @no_collision						; if we are straight on a slope, move on
	rts										; return the collision tile code

@no_collision:
	;test the current tile the entity is sitting on
	jsr get_collision_map
	ldy #Entity::bFeetIndex
	lda (r3), y								; delta Y to get the feet tile
	tay
	lda (r0),y
	sta bCurentTile
	cmp #TILE::SOLD_SLOP_RIGHT
	beq @go_up_slope
	cmp #TILE::SLIDE_RIGHT
	beq @go_up_slide			; walk up but activate sliding to go back
	cmp #TILE::SOLD_SLOP_LEFT
	beq @go_down_slope

	tax
	lda tiles_attributes,x
	bit #TILE_ATTR::SOLID_GROUND
	bne @go_left							; feet are on a tile with SOLID_GROUND attribute
@fall:										
	lda #00
	jmp Entities::set_controler				; feet are not on a solid ground => fall

	; move the entity in the level on the x axe
@go_left:
	jsr Entities::position_x_dec
	bra @check_ground
@go_up_slope:
	jsr Entities::position_x_dec
	jsr Entities::position_y_dec
	bra @check_ground
@go_up_slide:
	jsr Entities::position_x_dec
	jsr Entities::position_y_dec
	ldy #Entity::levelx
	lda (r3),y
	and #$0f
	tax
	lda #Status::SLIDE_LEFT
	cpx #$00
	beq @set_slide_left
	bra @check_ground
@go_down_slope:
	jsr Entities::position_x_dec
	jsr Entities::position_y_inc

@check_ground:
	lda bCheckGround
	beq @return

	jsr check_collision_down
	beq @fall						;Collision::None
	cmp #Collision::SCREEN
	beq @collision_screen
	cmp #Collision::SLOPE
	beq @above_slope
	cmp #Collision::IN_GROUND		; wen entered ground, so move above
	beq @walk_on_ground

	; Collision::GROUND
@return:
	lda #00
	rts

@collision_screen:
	lda #$ff
	rts

@walk_on_ground:
	jsr Entities::position_y_dec	; move the entity on top of the ground
	lda #00
	rts

@above_slope:
	; test below the entity
	lda bCurentTile
	cmp #TILE::SLIDE_LEFT
	beq @set_slide_left
	cmp #TILE::SOLD_SLOP_LEFT
	bne @return

@set_slope_left:
	jsr Entities::position_y_inc
	lda #00
	rts
@set_slide_left:
	jsr Entities::position_y_inc
	jsr Entities::sever_link						; if the entity is connected to another, sever the link
    ldx #TILE::SOLD_SLOP_LEFT
	jmp Entities::go_class_controler
.endscope