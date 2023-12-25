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
	lda #STATUS_WALKING
	ldy #Entity::status
	sta (r3),y

	jsr Entities::fn_restore_action
	jsr Entities::align_on_y_tile
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
	and #$0f
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
	and #$0f
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
	and #$0f
	cmp #$07					; TODO : must be a more optimzed way
	beq @seven					; TODO : to detect moving from 8 to 7 or 7 to 8
	cmp #$08
	beq @eight
	bra @keep_walking
@seven:
	lda bSaveXt
	cmp #08
	bne @keep_walking
	bra @crossed
@eight:
	lda bSaveXt
	cmp #07
	bne @keep_walking
@crossed:
	jsr get_collision_feet		; yes it did
@check_controler:				; read the next tile
	lda (r0),y					; r0 got updated with the new tile index
	beq @check_below			; empty tile, so should be falling, unless there is a slope below
	tax							; pass the new tile content
	lda tiles_attributes,x
	bit #TILE_ATTR::SOLID_GROUND
	beq @change_controler			; we are still on a tile with controler WALK
@keep_walking:
	lda #00						; continue with the WALK controler
	rts

@check_below:
	tya							; if we are in the air, check directly if there is a slop below
	clc
	adc #LEVEL_TILES_WIDTH
	tay
	lda (r0),y					; r0 got updated with the new tile index
	beq @change_controler		; empty tile, so should be falling
	tax							; pass the new tile content
	lda tiles_attributes,x
	bit #TILE_ATTR::SLOPE
	beq @change_controler		; no slope below, pick a new controler
	jsr Entities::position_y_inc
	bra @keep_walking			; move 1 pixel below on the slope

@change_controler:
	tax
	jmp Entities::go_class_controler; check the object based set_controler
	
.endscope