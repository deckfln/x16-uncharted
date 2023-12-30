;**************************************************
; <<<<<<<<<< 	drive physics status     >>>>>>>>>>
;**************************************************

.scope Slide

;************************************************
; Macro to help the controler identity the component
;
.macro Entity_Slide_check
	bit #TILE_ATTR::SLOPE
	beq :+
	jmp Slide::set
:
.endmacro

;************************************************
; Activate the component
;
set:
	cmp #TILE::SOLD_SLOP_LEFT
    beq @left
@right:
	lda #Status::SLIDE_RIGHT
@left:
	lda #Status::SLIDE_LEFT
@next:
	ldy #Entity::status
	sta (r3),y

	lda (r3)		; entityID
	asl
	tax
	lda #<update
	sta fnPhysics_table,x
	lda #>update
	sta fnPhysics_table+1,x

	; activate physics engine
	ldy #Entity::bFlags
	lda (r3),y
	ora #EntityFlags::physics
	sta (r3),y						; engage physics engine for that entity

	rts

;************************************************
; sliding physics
;   input: r3 pointer to entity
;
update:
	jsr save_position_r3
	jsr get_collision_feet
	tay
	lda (r0),y
	beq @finish						; restore normal physic if entity floating in the air
	cmp #TILE::SLIDE_LEFT
	beq @on_sliding_tile_left
	cmp #TILE::SLIDE_RIGHT
	beq @on_sliding_tile_right
@test_ground:
	tax
	lda tiles_attributes,x
	bit #TILE_ATTR::SOLID_GROUND
	bne @on_ground
	bra @finish

@on_ground:							; slided into ground, so move 1px up
	jsr Entities::position_y_dec
	bra @finish

@on_sliding_tile_right:	
	jsr Entities::check_collision_right
	bne @collision_side				; block is collision on the right  and there is no slope on the right

	jsr Entities::position_x_inc
	jsr Entities::position_y_inc
	bra @next

@on_sliding_tile_left:
	jsr Entities::check_collision_left
	bne @collision_side				; block is collision on the right  and there is no slope on the right
	jsr Entities::position_x_dec
	jsr Entities::position_y_inc

@next:								; if wa can slide, still check sprites collision
	ldy #Entity::spriteID
	lda (r3),y
	tax
	jsr Sprite::check_collision
	cmp #$ff
	beq @no_sprite_collision
@sprite_collision:
	jsr restore_position_r3			; in case of collision, restore the previous position
@no_sprite_collision:
@collision_side:
	rts
@finish:
	ldy #Entity::status
	lda #STATUS_WALKING_IDLE
	sta (r3),y
	jmp Entities::set_physics

.endscope