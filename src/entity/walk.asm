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
	ldy #Entity::levelx
	lda (r3),y
	and #$08
	sta bSaveXt								; save tile index

	jsr Entities::check_collision_right		; R0 is on tile on the left of the current position
	beq @no_collision
	cmp #Collision::SLOPE
	beq @no_collision						; if we are straight on a slope, move on
	rts										; return the collision tile code

@no_collision:
	;test the current tile the entity is walking on
	jsr get_collision_feet
	lda (r0),y
	sta bCurentTile
	cmp #TILE::SOLD_SLOP_LEFT
	beq @go_up_slope
	cmp #TILE::SLIDE_LEFT
	beq @go_up_slide						; walk up but activate sliding to go back
	cmp #TILE::SOLD_SLOP_RIGHT
	beq @go_down_slope
@go_right:									; move the entity in the level on the x axe
	jsr Entities::position_x_inc
	jmp check_still_ground
@go_up_slope:
	jsr Entities::position_x_inc
	jsr Entities::position_y_dec
	jmp check_still_ground
@go_down_slope:
	jsr Entities::position_x_inc

	ldy #Entity::levely
	lda (r3),y
	and #$0f
	bne :+									; y % 15 <> 0, we are not on the Y border

	; we would be breaking to the right-down tile, but is there a solid tile on the right ?
	ldy bTilesHeight
	iny										; check on the right
	lda (r0), y
	tax										
	lda tiles_attributes,x
	bit #TILE_ATTR::SOLID_GROUND
	beq :+									; we are not walking right_down, but walk straight right
	lda #00									; continue with the WALK controler
	rts
:
	jsr Entities::position_y_inc
	jmp check_still_ground
@go_up_slide:
	jsr Entities::position_x_inc			; walk up the slide on the right
	jsr Entities::position_y_dec
	ldy #Entity::levelx
	lda (r3),y
	and #$0f
	jmp check_still_ground				   	; still on some solide tile
	jsr Entities::sever_link		   		; on thin air, so we shall fall => if the entity is connected to another, sever the link
    ldx #TILE_ATTR::NONE
	jmp Entities::go_class_controler

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
	ldy #Entity::levelx
	lda (r3),y
	and #$08
	sta bSaveXt								; save tile index

	jsr Entities::check_collision_left
	beq @no_collision
	cmp #Collision::SLOPE
	beq @no_collision						; if we are straight on a slope, move on
	rts										; return the collision tile code

@no_collision:
	;test the current tile the entity is sitting on
	jsr get_collision_feet
	lda (r0),y
	sta bCurentTile
	cmp #TILE::SOLD_SLOP_RIGHT
	beq @go_up_slope
	cmp #TILE::SLIDE_RIGHT
	beq @go_up_slide			; walk up but activate sliding to go back
	cmp #TILE::SOLD_SLOP_LEFT
	beq @go_down_slope
	
@go_left:
	jsr Entities::position_x_dec
	bra check_still_ground
@go_up_slope:
	jsr Entities::position_x_dec
	jsr Entities::position_y_dec
	bra check_still_ground
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
	bra check_still_ground
@go_down_slope:
	jsr Entities::position_x_dec

	ldy #Entity::levely
	lda (r3),y
	and #$0f
	bne :+									; y % 15 <> 0, we are not on the Y border

	; we would be breaking to the left-down tile, but is there a solid tile on the left ?
	ldy bTilesHeight
	dey										; check on the left
	lda (r0), y
	tax										
	lda tiles_attributes,x
	bit #TILE_ATTR::SOLID_GROUND
	beq :+									; we are not walking left_down, but walk straight left
	lda #00									; continue with the WALK controler
	rts
:
	jsr Entities::position_y_inc
	bra check_still_ground
@set_slide_left:
	jsr Entities::position_y_inc
	jsr Entities::sever_link						; if the entity is connected to another, sever the link
    ldx #TILE::SOLD_SLOP_LEFT
	jmp Entities::go_class_controler

;************************************************
; check if the entity is till on a solid ground after moving
;
check_still_ground:
	; did the gravity point crossed a tile
	ldy #Entity::levelx
	lda (r3),y
	and #$08
	cmp bSaveXt
	beq @keep_walking			; didn't cross
	jsr get_collision_feet		; yes it did
@check_controler1:				; read the next tile
	lda (r0),y					; r0 got updated with the new tile index
	beq @fall					; empty tile, so should be falling
	tax							; pass the new tile content
	lda tiles_attributes,x
	bit #TILE_ATTR::SOLID_GROUND
	bne @keep_walking			; we are still on a tile with controler WALK
	bra @normal_check			; check
	
@fall:							; test if we have to enter falling mode
	tya
	clc
	adc  #LEVEL_TILES_WIDTH
	tay							; check below the gravity point
	lda (r0),y					; check the tile below
	tax
	lda tiles_attributes,x
	bit #TILE_ATTR::SLOPE
	beq @change_controler		; change to the gravity controler
@move_on_slope:					; force the entity position on the top of the below slope
	jsr Entities::position_y_inc
	bra @keep_walking

@normal_check:
	; if the gravity point changed tile, recheck
	; compare the previous  gravity point tile with the new one
	clc
	lda r0
	adc bTilesHeight
	sta bSaveX
	lda r0+1
	adc #00
	sta bSaveX + 1 				; save the feet tile index
	jsr get_collision_feet
	clc
	lda r0
	adc bTilesHeight
	sta r0
	lda r0+1
	adc #00
	sta r0 + 1 					; get the new feet tile index

	lda r0 + 1
	cmp bSaveX + 1
	bne @check_controler		; new feet index <> old feet index
	lda r0
	cmp bSaveX
	bne @check_controler		; new feet index <> old feet index
@keep_walking:
	lda #00						; continue with the WALK controler
	rts

@check_controler:				; read the next tile
	lda (r0)					; r0 got updated with the new tile index
	tax							; pass the new tile content
	lda tiles_attributes,x
	bit #TILE_ATTR::SOLID_GROUND
	bne @keep_walking			; we are still on a tile with controler WALK
@change_controler:
	jmp Entities::go_class_controler; check the object based set_controler
.endscope