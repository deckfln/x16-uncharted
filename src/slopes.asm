;-----------------------------------------------------------------------------
;/////////////////////////////////////////////////////////////////////////////
;           manage slopes tiles
;\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------------------------------

.scope Slopes

;************************************************
; test slope on Y axis
; input : A = tile index
;       r3 = current entity
;
check_slop_y:
	lda Entities::bCheckBelow
	cmp #01
	beq @collision_slope
	lda Entities::bCurentTile
	cmp #TILE_SOLD_SLOP_LEFT
	beq @slope_left
	cmp #TILE_SLIDE_LEFT
	beq @slope_left
@slope_right:
	ldy #Entity::levelx
	lda (r3),y						; X position defines how far down Y can go
	clc
	adc #08							; collision point is midle of the width
	and #%00001111
@store_y1:
	sta Entities::bSlopX_delta
	bra @slope_y
@slope_left:
	ldy #Entity::levelx
	lda (r3),y						; X position defines how far down Y can go
	clc
	adc #08							; collision point is midle of the width
	and #%00001111
	eor #%00001111
	sta Entities::bSlopX_delta
@slope_y:
	ldy #Entity::levely
	lda (r3),y
	clc
	adc #$0f						; contact point is at the bottom of a tile
	and #%00001111
	cmp Entities::bSlopX_delta
	beq :+							; hit the slop if y = deltaX
	bcc @no_slope   				; hit the slop if y >= deltaX
:
	lda Entities::bCheckBelow
	beq @ground_down				; when checking at feet level, return we are sitting on a ground
@collision_slope:
	lda #Collision::SLOPE			; checked BELOW the feet
	rts
@ground:
	lda Entities::bCheckBelow
	beq @in_ground					; when checking at feet level, return we are sitting on a ground
@ground_down:
	lda #Collision::GROUND
	rts
@in_ground:
	lda #Collision::IN_GROUND
	rts
@no_slope:
	lda #Collision::NONE
    rts

;************************************************
; test slope on X axis
; input : A = tile index
;       r3 = current entity
;
check_slop_x:
	lda Entities::bCurentTile
	cmp #TILE_SOLD_SLOP_LEFT
	beq @slope_left
	cmp #TILE_SLIDE_LEFT
	beq @slope_left
@slope_right:
	ldy #Entity::levelx
	lda (r3),y						
	clc
	adc #08							; collision point is at midle of the entity
	and #%00001111
@store_y1:
	sta Entities::bSlopX_delta
	bra @slope_x
@slope_left:
	ldy #Entity::levelx
	lda (r3),y						; X position defines how far down Y can go
	clc
	adc #08							; collision point is midle of the width
	and #%00001111
	eor #%00001111
	sta Entities::bSlopX_delta
@slope_x:
	ldy #Entity::levely
	lda (r3),y
	clc
	adc Entities::bSaveX	    	; contact point is at top or bottom of the tile ?
	and #%00001111
	cmp Entities::bSlopX_delta
	beq @on_slope					; hit the slop if y = deltaX
	bcs @in_ground	    			; hit the slop if y >= deltaX
@no_slope:
	lda #Collision::NONE
    rts
@on_slope:
	lda #Collision::SLOPE			; straight on slope
	rts
@in_ground:
	lda #Collision::IN_GROUND
	rts

.endscope