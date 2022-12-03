;-----------------------------------------------------------------------------
;/////////////////////////////////////////////////////////////////////////////
;           start ENTITY code
;\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------------------------------

.struct Entity
    spriteID    .byte   ; ID of the vera sprite
	status		.byte	; status of the player : IDLE, WALKING, CLIMBING, FALLING
    levelx      .word   ; level position
    levely      .word 
	falling_ticks .word	; ticks since the player is falling (thing t in gravity) 
	delta_x		.byte	; when driving by phisics, original delta_x value
	bPhysics	.byte	; physics engine has to be activated or not
	bWidth		.byte	; widht in pixel of the entity
	bHeight		.byte	; Height in pixel of the entity
	bDirty		.byte	; position of the entity was changed
	collision_addr	.word	; cached @ of the collision equivalent of the center of the player
.endstruct

ENTITY_ZP = $0065

.scope Entities

; pointers to entites
indexLO:	.word $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
indexHI:	.word $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
indexUse:	.word $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00

;************************************************
; add an entity
;   input: a = lo-byte of entity address
;		   y = hi-byte 
;			x = entityID
register:
	.ifdef DEBUG
	cpx .sizeof(indexLO)
	bcs :+
	stp				; detect out of bound
:
	.endif
	sta indexLO,x
	tya
	sta indexHI,x

	lda #01
	sta indexUse,x	; entitie is activate
	rts

;************************************************
; init all attributes of an entity
;   input: X = entityID
;	output: r3 = entity address
;
get_pointer:
	.ifdef DEBUG
	cpx .sizeof(indexLO)
	bcs :+
	stp				; detect out of bound
:
	lda indexUse, x
	bne :+
	stp				; detect inactive entities
:
	.endif
	lda indexLO, x
	sta r3
	lda indexHI, x
	sta r3
	rts

;************************************************
; init all attributes of an entity
;   input: X = entityID
;
initIndex:
	.ifdef DEBUG
	cpx .sizeof(indexLO)
	bcs :+
	stp				; detect out of bound
:
	lda indexUse, x
	bne :+
	stp				; detect inactive entities
:
	.endif
	lda indexLO, x
	sta r3
	lda indexHI, x
	sta r3

	; pass through

;************************************************
; init all attributes of an entity
;   input: R3 = start of the object
;
init:
	.ifdef DEBUG
	cmp r3H
	bne :+
	cmp r3L
	bne :+

	stp				; detect NULL pointer
:
	.endif

    lda #00
    ldy #Entity::spriteID
	sta (r3), y
    ldy #Entity::status
	lda #STATUS_WALKING_IDLE
	sta (r3), y
    lda #00
    ldy #Entity::falling_ticks
	sta (r3),y 
    iny
	sta (r3),y 
    iny
	sta (r3),y 	; delta_x
    ldy #Entity::levelx
	sta (r3),y
    iny
	sta (r3),y
    ldy #Entity::levely
	sta (r3),y
    iny
	sta (r3),y
	lda #01
	ldy #Entity::bPhysics
	sta (r3),y 	; bPhysics = TRUE upon creation
	lda #00
	ldy #Entity::bDirty
	sta (r3),y	; force screen position and size to be recomputed
    rts

;************************************************
; change  position of the sprite (level view) => (screen view)
;   input: R3 = start of the object
;
set_position:
	sty ENTITY_ZP			; save Y

    ; screenX = levelX - layer1_scroll_x
    ldy #(Entity::levelx)
    sec
    lda (r3), y
    sbc VERA_L1_hscrolllo
    sta r1L
    iny
    lda (r3), y
    sbc VERA_L1_hscrolllo + 1
    sta r1H

    ; screenY = levelY - layer1_scroll_y
    ldy #(Entity::levely)
    sec
    lda (r3), y
    sbc VERA_L1_vscrolllo
    sta r2L
    iny
    lda (r3), y
    sbc VERA_L1_vscrolllo + 1
    sta r2H

    ; get the sprite ID
	lda (r3)                        ; sprite id
    tay

    ; adresse of the and px, py attributes
	lda #<r1L
    sta r0L
	lda #>r1L
    sta r0H
	jsr Sprite::position			; set position of the sprite

	ldy #Entity::bDirty
	lda #00
	sta (r3), y  		; clear the refresh flag

@return:
	ldy ENTITY_ZP		; restore Y
    rts

;************************************************
; update all entities screen position (when the object was moved, when the layer was moved)
;   input: R3 = start of the object
;
update:
	ldx #00

@loop:
	lda indexUse,x
	beq @next

	lda indexHI,x
	sta r3H
	lda indexLO,x
	sta r3L

	ldy #Entity::bDirty
	lda (r3),y
	beq @next			; nothing to do
	jsr Entities::set_position
@next:
	inx
	cpx #(.sizeof(indexLO))
    bne @loop

@return:
    rts

;************************************************
; change screen position of all entities when the layer moves (level view) => (screen view)
;
fix_positions:
	ldx #00

@loop:
	lda indexUse,x
	beq @next

	lda indexHI,x
	sta r3H
	lda indexLO,x
	sta r3L

    jsr Entities::set_position

@next:
	inx
	cpx #(.sizeof(indexLO))
    bne @loop

@return:
    rts

;************************************************
; increase entity X position
;   input: R3 = start of the object
;
position_x_inc:
	; move the absolute position levelx + 1
	ldy #Entity::levelx
    lda (r3),y
    inc
    sta (r3),y
    bne :+
    iny
    lda (r3),y
    inc
    sta (r3),y
:
	ldy #Entity::bDirty
	lda #01
	sta (r3), y  		; set the refresh flag

	rts

;************************************************
; decrease entity X position
;   input: R3 = start of the object
;
position_x_dec:
	ldy #Entity::levelx
    lda (r3),y
    dec
    sta (r3),y
    cmp #$ff
    bne :+
    iny
    lda (r3),y
    dec
    sta (r3),y
:
	ldy #Entity::bDirty
	lda #01
	sta (r3), y  		; set the refresh flag
	rts

;************************************************
; increase entity Y position
;   input: R3 = start of the object
;
position_y_inc:
	; move the absolute position levelx + 1
	ldy #Entity::levely
    lda (r3),y
    inc
    sta (r3),y
    bne :+
    iny
    lda (r3),y
    inc
    sta (r3),y
:
	ldy #Entity::bDirty
	lda #01
	sta (r3), y  		; set the refresh flag
	rts

;************************************************
; decrease entity X position
;   input: R3 = start of the object
;
position_y_dec:
	ldy #Entity::levely
    lda (r3),y
    dec
    sta (r3),y
    cmp #$ff
    bne :+
    iny
    lda (r3),y
    dec
    sta (r3),y
:
	ldy #Entity::bDirty
	lda #01
	sta (r3), y  		; set the refresh flag
	rts

;************************************************
;	compute the number of tiles covered by the boundingbox
; input: r3 pointer to entity
; output: r1L : number of tiles height
;			X = r1H : number of tiles width
;			Y = r2L : index of the first tile to test
;
bbox_coverage:
	; X = how many column of tiles to test
    ldy #Entity::levelx
	lda (r3),y
	and #%00001111
	cmp #8
	beq @one_tile
	bmi @two_tiles_straight				; if X < 8, test as if int
@two_tiles_right:
	ldx #02								; test 2 column ( y % 16 <> 0)
	stx r1H
	ldy #01								; starting on row +1
	sty r2L
	bra @test_lines
@one_tile:
	ldx #01								; test 1 column ( y % 16  == 8)
	stx r1H
	ldy #01								; starting on row +1
	sty r2L
	bra @test_lines
@two_tiles_straight:
	ldx #02								; test 2 columns ( y % 16 == 0)
	stx r1H
	ldy #00								; test on row  0 ( x % 16 != 0)
	sty r2L

@test_lines:
	; X = how many lines of tiles to test
    ldy #Entity::levely
	lda (r3),y
	and #%00001111
	bne @yfloat				; if player is not on a multiple of 16 (tile size)
@yint:
	lda #02					; test 2 lines ( y % 16 == 0)
	sta r1L
	rts
@yfloat:
	lda #03					; test 3 rows ( y % 16 <> 0)
	sta r1L
	rts

;************************************************
; check collision on the height
; input: r3 pointer to entity
; return:;	A = vaule of the collision
;	        ZERO = no collision
;
check_collision_height:
	; only test if we are 'centered'
    ldy #Entity::levelx
	lda (r3),y
	and #%00001111
	cmp #08
	bne @no_collision

    ldy #Entity::collision_addr
	lda (r3),y
	sta r0L
    iny
	lda (r3),y
	sta r0H

	jsr bbox_coverage
	ldx r1L				; tiles height
	lda r2L
	clc
	adc ENTITY_ZP + 5
	tay

@test_line:
	lda (r0L),y
	beq @test_next_line

	; some tiles are not real collision 
	sty $30
	tay
	lda tiles_attributes,y
	bit #TILE_ATTR::SOLID_WALL
	beq @test_next_line1
	ldy $30
	lda (r0L),y
	rts

@test_next_line1:
	ldy $30

@test_next_line:
	dex
	beq @no_collision
	tya
	clc
	adc #LEVEL_TILES_WIDTH			; test the tile on the right of the player (hip position)
	tay
	bra @test_line					; LADDERS can be traversed

@no_collision:						; force a no collision
	lda #00
@return:
	rts

;************************************************
; check collision on the right
; input: r3 pointer to entity
; output: A = value of the collision, or 00/01 for sprites
;			ZERO = no collision
;
check_collision_right:
	; if levelx == TILEMAP_WIDTH - sprite.width => collision
	ldy #Entity::levelx + 1
	lda (r3),y
	beq :+							; if x < 256, no need to test right border
	ldy #Entity::levelx
	lda (r3),y
	ldy #Entity::bWidth
	adc (r3),y
	cmp #<(LEVEL_WIDTH)
	bne :+
	lda #01
	rts

:
	lda #$01
	sta ENTITY_ZP + 5
	jsr check_collision_height
	bne @return						; if tile collision, return the tile value

	lda (r3)
    tax
	lda #(02 | 04)
	ldy #01
	jsr Sprite::precheck_collision	; precheck 1 pixel right, if a=$ff => nocollision
	bmi @no_collision
	lda #01
	rts

@no_collision:
	lda #00
@return:
	rts

;************************************************
; check collision on the left
; input: r3 pointer to entity
; output: A = value of the collision, or 00/01 for sprites
;			ZERO = no collision
;
check_collision_left:
	; if levelx == 0 => collision
	ldy #Entity::levelx + 1
	lda (r3),y
	bne :+
	ldy #Entity::levelx
	lda (r3),y
	bne :+
	lda #01
	rts

:
	; left border is a collision
	lda #$ff
	sta ENTITY_ZP + 5
	jsr check_collision_height
	bne @return

	lda (r3)
    tax
	lda #(02 | 08)
	ldy #01
	jsr Sprite::precheck_collision	; precheck 1 pixel right
	bmi @no_collision
	lda #01
	rts

@no_collision:
	lda #00
@return:
	rts

;************************************************
; check collision down
;	collision surface to test is 16 pixels around the mid X
; input: r3 pointer to entity
; output : Z = no collision
;
check_collision_down:
	; if levely == LEVEL_HEIGHT - sprite.width => collision
	ldy #Entity::levely + 1
	lda (r3),y
	beq :+							; if x < 256, no need to test right border
	ldy #Entity::levely
	lda (r3),y
	ldy #Entity::bHeight
	adc (r3),y
	cmp #<(LEVEL_HEIGHT)
	bne :+
	lda #01
	rts

:
    ldy #Entity::levely
	lda (r3),y               	; if the player is inbetween 2 tiles there can be no collision
	and #%00001111
	beq @real_test

@check_sprites:
    lda (r3)
    tax
	lda #(01 | 04)
	ldy #01
	jsr Sprite::precheck_collision	; precheck 1 pixel right
	bmi @no_collision
	lda #01
	rts
@no_collision:
	lda #00
	rts
@real_test:	
    ldy #Entity::collision_addr
	lda (r3),y
	sta r0L
    iny
	lda (r3),y
	sta r0H

	jsr bbox_coverage
	lda r2L 
	clc
	adc #(LEVEL_TILES_WIDTH * 2)	; check below the player
	tay

@test_colum:
	lda (r0L),y
	beq @next_colum							; empty tile, test the next one

	sty $30
	tay
	lda tiles_attributes,y
	bit #TILE_ATTR::SOLID_GROUND
	bne @collision							; considere slopes as empty
	ldy $30

@next_colum:
	dex
	beq @check_sprites
	iny
	bra @test_colum
@collision:
	lda #01
	rts

;************************************************
; check collision up
;	collision surface to test is 16 pixels around the mid X
; input: r3 pointer to entity
;		r0 : @ of current tile the top-left corner of the player sprite
; output : Z = no collision
;
check_collision_up:
	; if levely == 0 => collision
	ldy #Entity::levely + 1
	lda (r3),y
	bne :+
	ldy #Entity::levely
	lda (r3),y
	bne :+
	lda #01
	rts

:
	sec
    ldy #Entity::collision_addr
	lda (r3),y
	sbc #LEVEL_TILES_WIDTH
	sta r0L
    iny
	lda (r3),y
	sbc #0
	sta r0H

	; X = how many column of tiles to test
    ldy #Entity::levelx
	lda (r3),y
	and #%00001111
	beq @xint				; if player is not on a multiple of 16 (tile size)
@xfloat:
	cmp #8
	bmi @xint
	ldx #1					; test 1 column ( y % 16 <> 0)
	ldy #1					; starting at colum + 1
	bra @test_colum
@xint:
	ldx #2					; test 2 columns ( y % 16 == 0)
	ldy #0					; starting at colum

@test_y:
	; Y = how many tile rows to test
    sty ENTITY_ZP
    ldy #Entity::levely
	lda (r3),y
	and #%00001111
	beq @yint				; if player is not on a multiple of 16 (tile size)
@yfloat:
	lda ENTITY_ZP
	adc #(LEVEL_TILES_WIDTH * 2)	; test on (row -1) +1 ( x % 16 != 0) + column
	tay
	bra @test_colum
@yint:

@test_colum:
	lda (r0L),y							; left side
	beq @next_column

	sty ENTITY_ZP
	tay
	lda tiles_attributes,y
	bit #TILE_ATTR::SOLID_CEILING
	bne @return1
	ldy ENTITY_ZP

@next_column:	
	dex
	beq @return
	iny
	bra @test_colum
@return1:
	lda #01
@return:
	rts

;************************************************
; check if the player feet is ABOVE a slope tile
;   input: 	r0 pointer to player position on collision map
;			r3 pointer to entity
;	        Y = feet position tested (vs r0)
;	modify: player_on_slop
;	return: Z = slop
;
if_above_slop:
	stz player_on_slop				; no slope

	tya
	clc
	adc #LEVEL_TILES_WIDTH
	tay								; test BELOW feet level
	lda (r0),y						
	cmp #TILE_SOLD_SLOP_LEFT
	beq @above_slope
	cmp #TILE_SOLD_SLOP_RIGHT
	beq @above_slope
@no_slope:
	lda #0
	sta player_on_slop
	rts
@above_slope:
	sta player_on_slop
	rts

;************************************************
; check if the entity base is exactly on a slope tile
;   input:  r0 pointer to player position on collision map
;			r3 pointer to entity	
;	modify: player_on_slop
;	return: Z = slop
;			Y = feet position tested (vs r0)
;
if_on_slop:
	stz player_on_slop				; no slope

	jsr bbox_coverage

	clc
	lda r2L
	ldx r1L							
	dex
:
	adc #LEVEL_TILES_WIDTH
	dex
	bne :-
	sta ENTITY_ZP + 2					; position of the feet tiles

    ldy #Entity::levelx
	lda (r3),y
	and #%00001111
	cmp #08
	bpl :+
	inc ENTITY_ZP + 2
:
    ldy ENTITY_ZP + 2
	; check if player feet is ON a slop
	lda (r0),y						; test ON feet level
	cmp #TILE_SOLD_SLOP_LEFT
	beq @on_slope
	cmp #TILE_SOLD_SLOP_RIGHT
	bne @no_slope
@on_slope:
	lda (r0),y						; test ON feet level
	sta player_on_slop
	rts

@no_slope:
	lda #0
	sta player_on_slop
	rts

;************************************************
; Handle entity physics when jumping or falling
;   input: r3 pointer to entity
;
physics:
	ldy #Entity::bPhysics
	lda (r3),y
	bne @do_it
	rts

@do_it:
	ldy #Entity::levely
	lda (r3),y
	sta r0L
	iny
	lda (r3),y
	sta r0H												; r0 = sprite absolute position Y in the level

	ldy #Entity::levelx
	lda (r3),y
	sta r1L
	iny
	lda (r3),y
	sta r1H												; r1 = sprite absolute position X in the level

	jsr Tilemap::get_collision_addr

	; cache the collision @
	ldy #Entity::collision_addr
	lda r0L
	sta (r3),y
	iny
	lda r0H
	sta (r3),y

	ldy #Entity::status
	lda (r3),y
	cmp #STATUS_CLIMBING
	beq @return1
	cmp #STATUS_CLIMBING_IDLE
	beq @return1
	cmp #STATUS_JUMPING
	bne @fall
	jmp @jump
@return1:
	rts

	;
	; deal with gravity driven falling
	; 
@fall:
.ifdef DEBUG
	CHECK_DEBUG
.endif
	jsr check_collision_down
	beq @check_on_slope				; no solid tile below the player, still check if the player is ON a slope
	jmp @sit_on_solid				; solid tile below the player that is not a slope

@check_on_slope:
	jsr if_on_slop
	beq @no_collision_down			; not ON a slope, and not ABOVE a solid tile => fall

	; player is on a slope
@on_slope:
	ldy #Entity::levelx
	cmp #TILE_SOLD_SLOP_LEFT
	beq @slope_left
@slope_right:
	lda (r3),y						; X position defines how far down Y can go
	and #%00001111
	eor #%00001111					; X = 0 => Y can go up to 15
	sta $30
	bra @slope_y
@slope_left:
	lda (r3),y						; X position defines how far down Y can go
	and #%00001111
	sta $30
	bra @slope_y
@slope_y:
	ldy #Entity::levely
	lda (r3),y
	and #%00001111
	cmp $30
	bmi @no_collision_down
	jmp @sit_on_solid

@no_collision_down:	
	; if the player is already falling, increase t
	ldy #Entity::status
	lda (r3),y
	cmp #STATUS_FALLING
	beq @increase_ticks

	; start the falling timer
	lda #STATUS_FALLING
	sta (r3),y
	lda #FALL_LO_TICKS
	ldy #Entity::falling_ticks
	sta (r3),y						; reset t
	iny
	lda #00
	sta (r3),y
@increase_ticks:
	ldy #Entity::falling_ticks
	lda (r3),y									; increase the timer every 10 screen refresh
	dec
	sta (r3),y
	bne @drive_fall
	lda #FALL_LO_TICKS
	sta (r3),y									
	iny
	lda (r3),y
	inc 
	sta (r3),y

@drive_fall:
	ldy #Entity::falling_ticks + 1
	lda (r3),y
	beq @fall_once
	sta r9L

	; move the player down #(falling_ticks + 1)
@loop_fall:
	jsr position_y_inc

	; refresh the collision addr
	ldy #Entity::levely
	lda (r3),y
	sta r0L
	iny
	lda (r3),y
	sta r0H							; r0 = sprite absolute position Y in the level

	ldy #Entity::levelx
	lda (r3),y
	sta r1L
	iny
	lda (r3),y
	sta r1H							; r1 = sprite absolute position X in the level

	jsr Tilemap::get_collision_addr

	ldy #Entity::collision_addr
	lda r0L
	sta (r3),y
	iny
	lda r0H
	sta (r3),y

	; test reached solid ground
	jsr check_collision_down
	bne @sit_on_solid

@loop_fall_no_collision:
	dec r9L
	bne @loop_fall					; take t in count for gravity

@apply_delta_x:
	ldy #Entity::delta_x
	lda (r3),y
	beq @return						; delta_x == 0 => entity is not moving left or right
	bmi @fall_left					; delta_x < 0 => move left

@fall_right:
	; cannot move if we are at the right border
	ldy #Entity::levelx
	lda (r3),y
	cmp #<(LEVEL_WIDTH - 32)
	bne @test_fall_collision_right
	iny
	lda (r3),y
	cmp #>(LEVEL_WIDTH - 32)
	beq @fcollision_right			; we are at the level limit
@test_fall_collision_right:
	jsr check_collision_right
	beq @no_fcollision_right
@fcollision_right:
	lda #00
	ldy #Entity::delta_x
	sta (r3),y						; cancel deltaX to transform to vertical movement
	rts	
@no_fcollision_right:
	jsr position_x_inc
	rts

@fall_left:
	; cannot move if we are at the left border
	ldy #Entity::levelx + 1
	lda (r3),y
	bne @test_fall_collision_left
	dey
	lda (r3),y
	beq @fcollision_left
@test_fall_collision_left:	
	jsr check_collision_left
	beq @no_fcollision_left
@fcollision_left:
	lda #00
	ldy #Entity::delta_x
	sta (r3),y				 		; cancel deltaX to transform to vertical movement
	rts	
@no_fcollision_left:
	jsr position_x_dec
	rts

@fall_once:
	jsr position_y_inc
	bra @apply_delta_x

@sit_on_solid:
	ldy #Entity::bPhysics
	lda #00
	sta (r3),y						; disengage physics engine for that entity

	; change the status if falling
	ldy #Entity::status
	lda (r3),y
	cmp #STATUS_FALLING
	bne @return
	lda #STATUS_WALKING_IDLE
	sta (r3),y

@return:
	rts

	;
	; deal with gravity driven jumping
	; 
@jump:
@decrease_ticks:
	ldy #Entity::falling_ticks
	lda (r3),y
	dec								 	; decrease  HI every 10 refresh
	sta (r3),y
	bne @drive_jump
	iny
	lda (r3),y
	dec 
	sta (r3),y
	beq @apex							; reached the apex of the jump

	lda #JUMP_LO_TICKS
	dey
	sta (r3),y							; reset t

@drive_jump:
	ldy #Entity::falling_ticks + 1
	lda (r3),y
	sta ENTITY_ZP + 1
@loop_jump:
	jsr position_y_dec

	; refresh the collision address
	ldy #Entity::levely
	lda (r3),y
	sta r0L
	iny
	lda (r3),y
	sta r0H							; r0 = sprite absolute position Y in the level

	ldy #Entity::levelx
	lda (r3),y
	sta r1L
	iny
	lda (r3),y
	sta r1H							; r1 = sprite absolute position X in the level

	jsr Tilemap::get_collision_addr

	ldy #Entity::collision_addr
	lda r0L
	sta (r3),Y
	iny
	lda r0H
	sta (r3),Y

	ldy #Entity::levely
	lda (r3),y
	and #%00001111
	bne @no_collision_up				; if player is not on a multiple of 16 (tile size)

	; test hit a ceiling
	jsr check_collision_up
	bne @collision_up
@no_collision_up:
	dec ENTITY_ZP + 1
	bne @loop_jump						; loop to take t in count for gravity

@collision_up:
	ldy #Entity::delta_x
	lda (r3),y					 		; deal with deltax
	beq @return
	bmi @jump_left
@jump_right:
	jsr check_collision_right
	beq @no_collision_right
@collision_right:
	lda #00
	ldy #Entity::delta_x
	sta (r3),y							; cancel deltaX to transform to vertical movement
	rts	
@no_collision_right:
	jsr position_x_inc
	rts
@jump_left:
	jsr check_collision_left
	beq @no_collision_left
@collision_left:
	lda #00
	ldy #Entity::delta_x
	sta (r3),y							; cancel deltaX to transform to vertical movement
	rts	
@no_collision_left:
	jsr position_x_dec
	rts

@apex:
    ldy #Entity::status
	lda #STATUS_JUMPING_IDLE
	sta (r3),y

	rts

.endscope