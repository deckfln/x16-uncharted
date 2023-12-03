;**************************************************
; <<<<<<<<<< 	drive physics status     >>>>>>>>>>
;**************************************************

.scope Physic

;************************************************
; Macro to help the controler identity the component
;
.macro Entity_Physic_check
	cmp #TILE_ATTR::NONE
	bne :+
	jmp Physic::set
:
.endmacro

;************************************************
; Activate the component
;
set:
    ldy #Entity::status
	lda #STATUS_FALLING
	sta (r3),y
	lda #01
	ldy #Entity::falling_ticks
	sta (r3),y						; time t = 0
	lda #00
	ldy #Entity::levely_d
	sta (r3),y						; levely.0
	ldy #Entity::vty
	sta (r3),y						
	ldy #Entity::vty + 1
	sta (r3),y						
	ldy #Entity::gt
	sta (r3),y						
	ldy #Entity::gt + 1				; 1/2gt2=0
	sta (r3),y						
	lda #$00
	ldy #Entity::vtx
	sta (r3),y						
	iny
	lda #$00
	sta (r3),y						; vtx = -2.0

	lda (r3)			; entityID
	asl
	tax

	ldy #Entity::update
	lda fnPhysics_table,x
	sta (r3),y
	iny
	lda fnPhysics_table+1,x
	sta (r3),y

	rts

;************************************************
; check if the physic shall be engaged
; input : r3 = current entity
;
check_solid:
	jsr check_collision_down		; check bottom screen or sprite collision
	bne @sit_on_solid				; yep

	ldy #Entity::levely
	lda (r3),y
	and #$0f
	cmp #$00
	beq @on_tile_border
	bra @engage_physic
@on_tile_border:					; inside a tile, check if the tile is a	 SLOPE
	jsr Entities::get_collision_feet
	lda (r0),y
	tax
	lda tiles_attributes,x
	bit #TILE_ATTR::SOLID_GROUND
	bne @sit_on_solid
@engage_physic:
	jsr set							; set controler physics

	;ldy #Entity::bFlags
	;lda (r3),y
	;ora #EntityFlags::physics
	;sta (r3),y						; engage physics engine for that entity

@sit_on_solid:
	rts

;************************************************
; update the physics position
;
update:
	stx bSaveX

	lda #<move_y_down
	sta Utils::ydown + 1
	lda #>move_y_down
	sta Utils::ydown + 2
	lda #<move_y_up
	sta Utils::yup + 1
	lda #>move_y_up
	sta Utils::yup + 2

	lda #<move_x_right
	sta Utils::xright + 1
	lda #>move_x_right
	sta Utils::xright + 2
	lda #<move_x_left
	sta Utils::xleft + 1
	lda #>move_x_left
	sta Utils::xleft + 2

	; if the entity is connected to another, sever the link
	jsr sever_link

	;
	; deal with gravity driven falling
	; 
@phys:
	; save levelX (16bits) & levelY (16bits) as p0.x & p0.y for bresenham
	ldy #Entity::levelx
	lda (r3),y
	sta r10
	ldy #Entity::levelx + 1
	lda (r3),y
	sta r10H

	ldy #Entity::levely
	lda (r3),y
	sta r11
	ldy #Entity::levely + 1
	lda (r3),y
	sta r11H

	; p1.y (bresenmham) = levely + (vty - delta_g) <> v0y * delta_t - 1/2 * g * delta_t
	clc
	ldy #Entity::gt
	lda (r3),y
	ldy #Entity::levely_d
	adc (r3),y
	sta (r3),y				; decimal is not used by bresenham, so save directly in the entity
	ldy #Entity::gt + 1
	lda (r3),y
	ldy #Entity::levely
	adc (r3),y
	sta r13
	ldy #Entity::levely + 1
	lda (r3),y
	adc #00
	sta r13H				; p0.y = levely + entity.gt

	sec
	ldy #Entity::levely_d
	lda (r3),y
	ldy #Entity::vty
	sbc (r3),y
	ldy #Entity::levely_d
	sta (r3),y
	lda r13
	ldy #Entity::vty + 1
	sbc (r3),y
	sta r13
	lda r13H
	sbc #00
	sta r13H				; p0.y -= entity.vty

	clc
	ldy #Entity::vtx+1
	lda (r3),y
	bpl @positive_vtx

	ldy #Entity::vtx
	lda (r3),y
	ldy #Entity::levelx_d
	adc (r3),y
	sta (r3),y
	ldy #Entity::levelx
	lda (r3),y
	ldy #Entity::vtx + 1
	adc (r3),y
	sta r12
	ldy #Entity::levelx + 1
	lda (r3),y
	adc #$ff
	sta r12H				; p0.x += entity.vtx
	bra :+

@positive_vtx:	
	ldy #Entity::vtx
	lda (r3),y
	ldy #Entity::levelx_d
	adc (r3),y
	sta (r3),y
	ldy #Entity::levelx
	lda (r3),y
	ldy #Entity::vtx + 1
	adc (r3),y
	sta r12
	ldy #Entity::levelx + 1
	lda (r3),y
	adc #$00
	sta r12H				; p0.x += entity.vtx
:
	jsr Utils::line			; bresenham line to move between the points

	clc
	ldy #Entity::gt
	lda (r3),y
	adc #<GRAVITY					; deltag = 0.25 * g * dt => 0.25 * 0.2 * 0.25 converted to 3 bytes
	sta (r3),y
	ldy #Entity::gt+1
	lda (r3),y
	adc #00
	sta (r3),y						; gt += deltag

	ldy #Entity::falling_ticks		; increase time
	lda (r3),y
	inc
	sta (r3),y
	rts

; callback fro bresenham, check every point
move_x_left:
	jsr Entities::get_collision_map_update
	jsr check_collision_left
	beq @no_collision_left
	ldy #Entity::vtx
	lda #00
	sta (r3),y
	iny
	sta (r3),y						; set vtx to ZERO
	lda #$ff
	rts
@no_collision_left:
	jsr position_x_dec
	lda #00
	rts

move_x_right:
	jsr Entities::get_collision_map_update
	jsr check_collision_right
	beq @no_collision_right
	ldy #Entity::vtx
	lda #00
	sta (r3),y
	iny
	sta (r3),y						; set vtx to ZERO
	lda #$ff
	rts
@no_collision_right:
	jsr position_x_inc
	lda #00
	rts
	
move_y_up:
	jsr check_collision_down		; check bottom screen or sprite collision
	bne sit_on_solid				; yep

	jsr position_y_inc

	ldy #Entity::levely
	lda (r3),y
	and #$0f
	cmp #$00
	beq @on_tile_border
@on_tile:								; inside a tile, check if the tile is a	 SLOPE
	jsr Entities::get_collision_feet
	lda (r0),y
	tax
	lda tiles_attributes,x
	bit #TILE_ATTR::SLOPE
	bne @on_slope
@no_collision_down:	
	lda #00
	rts
@on_slope:								; if the tile is a SLOP, check the y position to pick the collision
	txa
	jsr Slopes::check_slop_y
	beq @no_collision_down
	bra sit_on_solid

@on_tile_border:
	jsr Entities::get_collision_feet
	lda (r0),y
	tax
	lda tiles_attributes,x
	bit #TILE_ATTR::SOLID_GROUND
	beq @no_collision_down
	bra sit_on_solid

move_y_down:
	; refresh r3
	jsr Entities::get_collision_map_update
	jsr check_collision_up

	beq @no_collision_up			; solid tile below the player that is not a slope
	cmp #Collision::GROUND
	beq sit_on_solid
	cmp #Collision::IN_GROUND
	beq sit_on_solid
	cmp #Collision::SLOPE
	beq @no_collision_up			; there is a slope below the player feet, so we continue falling
	cmp #Collision::SCREEN
	beq sit_on_solid
	cmp #Collision::SPRITE
	beq sit_on_solid

@no_collision_up:	
	jsr position_y_dec
	lda #00
	rts

	; Collision::GROUND
sit_on_solid:
	; clean update
	lda #00
	ldy #Entity::update
	sta (r3),y
	iny
	sta (r3),y

	; change the status if falling
	ldy #Entity::status
	lda #STATUS_WALKING_IDLE
	sta (r3),y
	lda #$ff
	jsr fn_restore_action

	lda bCurentTile
	cmp #TILE::SLIDE_LEFT
	beq @set_slide_left
	cmp #TILE::SLIDE_RIGHT
	beq @set_slide_right
@return:
	lda #01							; cancel bresenham
	rts

@set_slide_left:
	lda #Status::SLIDE_LEFT
	bra :+
@set_slide_right:
	lda #Status::SLIDE_RIGHT
:
	ldy #Entity::status
	sta (r3),y						; force the slide status
	jmp Entities::Slide::set	; change the physics for the slider engine
.endscope