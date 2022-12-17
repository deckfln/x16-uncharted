;-----------------------------------------------------------------------------
;/////////////////////////////////////////////////////////////////////////////
;           start ENTITY code
;\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------------------------------

.struct Entity
	id			.byte	; id of the entity
    spriteID    .byte   ; ID of the vera sprite
	status		.byte	; status of the player : IDLE, WALKING, CLIMBING, FALLING
	connectedID	.byte	; EntityID connected to that one
    levelx      .word   ; level position
    levely      .word 
	falling_ticks .word	; ticks since the player is falling (thing t in gravity) 
	delta_x		.byte	; when driving by phisics, original delta_x value

	bWidth		.byte	; widht in pixel of the entity
	bHeight		.byte	; Height in pixel of the entity
	bFlags		.byte	; position of the entity was changed
	bXOffset	.byte	; signed offset of the top-left corder of the sprite vs the collision box
	bYOffset	.byte	;
	collision_addr	.addr	; cached @ of the collision equivalent of the center of the player
	fnBind		.addr	; virtual function 'bind' (connect 2 entites together)
	fnUnbind	.addr	; virtual function 'unbind' (disconnect 2 entities)
	fnMoveRight	.addr	; virtual function move_right
	fnMoveLeft	.addr	; virtual function move_left
	fnMoveUp	.addr	; virtual function move_up
	fnMoveDown	.addr	; virtual function move_down
	fnPhysics	.addr	; virtual function physics
.endstruct

.enum EntityFlags
	physics = 1
	moved = 2
	colission_map_changed = 4
.endenum


.scope Entities

MAX_ENTITIES = 16
ENTITY_ZP = $0065

bSaveX = ENTITY_ZP + 3
bSide2test = ENTITY_ZP + 4

; pixel size converted to tiles size
bTilesWidth = ENTITY_ZP + 5
bTilesHeight = ENTITY_ZP + 6

bInLoop = ENTITY_ZP + 8
bSlopX_delta = $30

; global variable to mark slope for the current entity
bPlayerOnSlop = ENTITY_ZP + 7

; number of tiles an entity covers (based on the collision box height and width)
bTilesCoveredX = r1L
bTilesCoveredY = r1H

; if TRUE do a simple tile based collision (0 = no collision)
bBasicCollisionTest = ENTITY_ZP + 9

; value of the last collision tile
bLastCollisionTile = ENTITY_ZP + 10

; pointers to entites
indexLO = $0600
indexHI = indexLO + MAX_ENTITIES
indexUse = indexHI + MAX_ENTITIES

; space to save entities position
save_position_xL = indexUse + MAX_ENTITIES
save_position_xH = save_position_xL + MAX_ENTITIES
save_position_yL = save_position_xH + MAX_ENTITIES
save_position_yH = save_position_yL + MAX_ENTITIES

;************************************************
; init the Entities modules
;
initModule:
	stz bBasicCollisionTest
	lda #00
	ldy #MAX_ENTITIES
	ldx #00
@loop:
	sta indexLO,x
	sta indexHI,x
	sta indexUse,x
	inx
	dey
	bne @loop

	; cleanup virtual functions
	lda #00
	ldy #MAX_ENTITIES
	ldx #00
:
	sta fnJump_table,x
	inx
	sta fnJump_table,x
	inx
	dey
	bne :-

	rts

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
    lda #$ff
    ldy #Entity::connectedID
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
	ldy #Entity::bFlags
	lda #(EntityFlags::physics | EntityFlags::moved | EntityFlags::colission_map_changed)
	sta (r3),y	; force screen position and size to be recomputed

	; register virtual function bind/unbind
	ldy #Entity::fnBind
	lda #<Entities::bind
	sta (r3),y
	iny
	lda #>Entities::bind
	sta (r3),y
	iny
	lda #>Entities::unbind
	sta (r3),y
	iny
	lda #>Entities::unbind
	sta (r3),y
    rts

;************************************************
; change  position of the sprite (level view) => (screen view)
;   input: R3 = start of the object
;
set_position:
	sty ENTITY_ZP			; save Y

    ; screenX = levelX - layer1_scroll_x
    ldy #Entity::levelx
    sec
    lda (r3), y
    sbc VERA_L1_hscrolllo
    sta r1L
    iny
    lda (r3), y
    sbc VERA_L1_hscrolllo + 1
    sta r1H

    ; screenY = levelY - layer1_scroll_y
    ldy #Entity::levely
    sec
    lda (r3), y
    sbc VERA_L1_vscrolllo
    sta r2L
    iny
    lda (r3), y
    sbc VERA_L1_vscrolllo + 1
    sta r2H

    ; get the sprite ID
	ldy #Entity::spriteID
	lda (r3),y                      ; sprite id
    tay

    ; adresse of the and px, py attributes
	lda #<r1L
    sta r0L
	lda #>r1L
    sta r0H
	jsr Sprite::position			; set position of the sprite

	ldy #Entity::bFlags
	lda (r3), y
	and #(255 - EntityFlags::moved)
	sta (r3), y  		; clear the refresh flag

@return:
	ldy ENTITY_ZP		; restore Y
    rts

;************************************************
; recompute the collision map address of the entity
;   input: R3 = start of the object
;   output: r0 = address on the collision map
;
get_collision_map:
	ldy #Entity::bFlags
	lda (r3),y
	bit #EntityFlags::colission_map_changed
	bne @update_addr

	; cache the collision @
	ldy #Entity::collision_addr
	lda (r3),y
	sta r0L
	iny
	lda (r3),y
	sta r0H

	rts

@update_addr:
	ldy #Entity::levely
	lda (r3),y
	sta r0L
	iny
	lda (r3),y
	sta r0H								; r0 = sprite absolute position Y in the level

	ldy #Entity::levelx
	lda (r3),y
	sta r1L
	iny
	lda (r3),y
	sta r1H								; r1 = sprite absolute position X in the level

	jsr Tilemap::get_collision_addr		; update the collision address

	; cache the collision @
	ldy #Entity::collision_addr
	lda r0L
	sta (r3),y
	iny
	lda r0H
	sta (r3),y

	ldy #Entity::bFlags
	lda (r3), y
	and #(255 - EntityFlags::colission_map_changed)
	sta (r3), y  						; clear the refresh flag
	rts

;************************************************
; update all entities screen position (when the object was moved, when the layer was moved)
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

	ldy #Entity::bFlags
	lda (r3),y
	bit #EntityFlags::physics
	beq :+			; nothing to do
	jsr fn_physics

:
	ldy #Entity::bFlags
	lda (r3),y
	bit #EntityFlags::moved
	beq @next			; nothing to do
	jsr Entities::set_position
	jsr Entities::get_collision_map
@next:
	inx
	cpx #MAX_ENTITIES
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
	jsr Entities::get_collision_map

@next:
	inx
	cpx #MAX_ENTITIES
    bne @loop

@return:
    rts

;************************************************
; save the current position if restore is needed
;   input: X = entity ID
;
save_position:
	lda indexHI,x
	sta r3H
	lda indexLO,x
	sta r3L

save_position_r3:
	ldy #Entity::levelx
	lda (r3), y
	sta save_position_xL,x
	iny
	lda (r3), y
	sta save_position_xH,x
	iny
	lda (r3), y
	sta save_position_yL,x
	iny
	lda (r3), y
	sta save_position_yH,x

	; keep the dirty flags
	rts

;************************************************
; restore the current position 
;   input: X = entity ID
;
restore_position:
	lda indexHI,x
	sta r3H
	lda indexLO,x
	sta r3L

restore_position_r3:
	ldy #Entity::levelx
	lda save_position_xL,x
	sta (r3), y
	iny
	lda save_position_xH,x
	sta (r3), y
	iny
	lda save_position_yL,x
	sta (r3), y
	iny
	lda save_position_yH,x
	sta (r3), y

	; force to recompute the collision map
	ldy #Entity::bFlags
	lda (r3), y  						; set the refresh bits
	ora #(EntityFlags::moved |EntityFlags::colission_map_changed)
	sta (r3), y  						

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
	ldy #Entity::bFlags
	lda (r3), y  						; set the refresh bits
	ora #(EntityFlags::moved | EntityFlags::colission_map_changed)
	sta (r3), y  						

	ldy #Entity::spriteID
	lda (r3),y
	tax
	jsr Sprite::aabb_x_inc
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
	ldy #Entity::bFlags
	lda (r3), y  						; set the refresh bits
	ora #(EntityFlags::moved | EntityFlags::colission_map_changed)
	sta (r3), y 

	ldy #Entity::spriteID
	lda (r3),y
	tax
	jsr Sprite::aabb_x_dec

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
	ldy #Entity::bFlags
	lda (r3), y  						; set the refresh bits
	ora #(EntityFlags::moved | EntityFlags::colission_map_changed)
	sta (r3), y 

	ldy #Entity::spriteID
	lda (r3),y
	tax
	jsr Sprite::aabb_y_inc

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
	ldy #Entity::bFlags
	lda (r3), y  						; set the refresh bits
	ora #(EntityFlags::moved | EntityFlags::colission_map_changed)
	sta (r3), y 

	ldy #Entity::spriteID
	lda (r3),y
	tax
	jsr Sprite::aabb_y_dec

	rts

;************************************************
;	compute the number of tiles covered by the boundingbox
; input: r3 pointer to entity
; output: r1L : number of tiles height
;			X = r1H : number of tiles width
;			Y = r2L : index of the first tile to test
;				r2H : size of object in tile coordinated
								; 8 pixels => + 0 byte
								; 16 pixels => + 1 byte
								; 32 pixels => + 2 bytes
								; 64 pixels => + 4 bytes

bbox_coverage:
	ldy #Entity::bWidth
	lda (r3),y
	cmp #16
	bne :+
	lda #01
	bra @width
:
	cmp #32
	bne :+
	lda #02
	bra @width
:	
	lda #00

@width:
	sta bTilesWidth

	; X = how many column of tiles to test
    ldy #Entity::levelx
	lda (r3),y
	and #%00001111
	beq @one_tile
@two_tiles_right:
	ldx bTilesWidth						; test 2 column ( y % 16 <> 0)
	inx
	stx bTilesCoveredX
	ldy #00								; starting on row +1
	sty r2L
	bra @test_lines
@one_tile:
	ldx bTilesWidth						; test 1 column ( y % 16  == 8)
	stx bTilesCoveredX
	ldy #00								; starting on row +1
	sty r2L

@test_lines:
	ldy #Entity::bHeight
	lda (r3),y
	cmp #16
	bne :+
	lda #01
	bra @height
:
	cmp #32
	bne :+
	lda #02
	bra @height
:	
	lda #00
@height:
	sta bTilesHeight

    ldy #Entity::levely
	lda (r3),y
	and #%00001111
	bne @yfloat				; if player is not on a multiple of 16 (tile size)
@yint:
	lda bTilesHeight		; test 2 lines ( y % 16 == 0)
	sta bTilesCoveredY
	rts
@yfloat:
	lda bTilesHeight
	inc
	sta bTilesCoveredY
	rts

;************************************************
; check collision on the height
; input: r3 pointer to entity
; return:;	A = vaule of the collision
;	        ZERO = no collision
;
if_collision_tile_height:
    ldy #Entity::collision_addr
	lda (r3),y
	sta r0L
    iny
	lda (r3),y
	sta r0H

	; only tiles test if we are on a tile edge
    ldy #Entity::levelx
	lda (r3),y
	and #%00001111
	bne @no_collision

	jsr bbox_coverage
	ldx bTilesCoveredY				; tiles height
	lda bSide2test
	bpl @right

@left:
	; check one tile on the left
	sec
	lda r0L
	sbc #01
	sta r0L
	lda r0H
	sbc #00
	sta r0H
	ldy #00
	bra @test_line

@right:
	lda bTilesWidth
	tay					; test x(tile) + bTlesWidth

@test_line:
	lda (r0L),y
	beq @test_next_line

	sta bLastCollisionTile			; save the value of the 'last' collision tested

	sty $30
	ldy bBasicCollisionTest			; if basic collision, any tilemap<>0 is a collision
	bne @collision
	tay
	lda tiles_attributes,y
	bit #TILE_ATTR::SOLID_WALL
	beq @test_next_line1			; else check the tilemap attributes
@collision:
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
	lda #01							; colllision right border
	rts

:
	lda #$01
	sta bSide2test
	jsr if_collision_tile_height
	bne @return						; if tile collision, return the tile value

	ldy #Entity::spriteID
	lda (r3),y
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
	sta bSide2test
	jsr if_collision_tile_height
	bne @return

	ldy #Entity::spriteID
	lda (r3),y
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
	bne @check_sprites

@check_tiles:	
    ldy #Entity::collision_addr
	lda (r3),y
	sta r0L
    iny
	lda (r3),y
	sta r0H

	jsr bbox_coverage
	ldx bTilesHeight	; check below the player
	lda #00
	clc
@loop:
	adc #LEVEL_TILES_WIDTH
	dex
	bne @loop
	tay

	ldx bTilesCoveredX						; tiles to test in width
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

@check_sprites:
	ldy #Entity::spriteID
    lda (r3),y
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
    ldy #Entity::levely
	lda (r3),y               	; if the player is inbetween 2 tiles there can be no collision
	and #%00001111
	bne @check_sprites

	sec
    ldy #Entity::collision_addr
	lda (r3),y
	sbc #LEVEL_TILES_WIDTH
	sta r0L
    iny
	lda (r3),y
	sbc #0
	sta r0H

	jsr bbox_coverage

	ldx bTilesCoveredX
	ldy #00
@test_colum:
	lda (r0L),y							; left side
	beq @next_column

	sty ENTITY_ZP
	tay
	lda tiles_attributes,y
	bit #TILE_ATTR::SOLID_CEILING
	bne @collision
	ldy ENTITY_ZP

@next_column:	
	dex
	beq @no_collision
	iny
	bra @test_colum
@collision:
	lda #01
	rts
@no_collision:
@check_sprites:
	lda #00
	rts

;************************************************
; check if the player feet is ABOVE a slope tile
;   input: 	r0 pointer to player position on collision map
;			r3 pointer to entity
;	        Y = feet position tested (vs r0)
;	modify: bPlayerOnSlop
;	return: Z = slop
;
if_above_slop:
	stz bPlayerOnSlop				; no slope

	jsr bbox_coverage
	
	clc
	lda #00
	ldx bTilesCoveredY					; test BELOW feet level
:
	adc #LEVEL_TILES_WIDTH
	dex
	bne :-
	sta ENTITY_ZP + 2					; position of the feet tiles

    ldy #Entity::levelx
	lda (r3),y
	and #%00001111
	cmp #08
	bcc @column0
	beq @no_slope						; if x % 16 > 8, on the edge
@column1:
	inc ENTITY_ZP + 2					; if x % 16 > 8, check the next colum
@column0:
    ldy ENTITY_ZP + 2
	lda (r0),y						
	cmp #TILE_SOLD_SLOP_LEFT
	beq @above_slope
	cmp #TILE_SOLD_SLOP_RIGHT
	beq @above_slope
@no_slope:
	lda #0
	sta bPlayerOnSlop
	rts
@above_slope:
	sta bPlayerOnSlop
	lda bPlayerOnSlop
	rts

;************************************************
; check if the entity base is exactly on a slope tile
;   input:  A = direction the object is moving to  (left = $ff, right = $01)
;			r0 pointer to player position on collision map
;			r3 pointer to entity	
;	modify: bPlayerOnSlop
;	return: Z = slop
;			Y = feet position tested (vs r0)
;
if_on_slop:
	stz bPlayerOnSlop				; no slope

	jsr bbox_coverage

	clc
	lda #00
	ldx bTilesCoveredY
	dex									; remove 1 to pick the feet position, and not BELOW the feet
:
	adc #LEVEL_TILES_WIDTH
	dex
	bne :-
	sta ENTITY_ZP + 2					; position of the feet tiles

    ldy #Entity::levelx
	lda (r3),y
	and #%00001111
	cmp #08
	bcc @column0						; if x % 16 < 8, check column 0
	bne @column1						; if x % 16 > 8, check column 1
	
    ldy ENTITY_ZP + 2					; if x%16==8 test both columns
	lda (r0),y							
	cmp #TILE_SOLD_SLOP_LEFT
	beq @on_slope
	cmp #TILE_SOLD_SLOP_RIGHT
	beq @on_slope

@column1:
	inc ENTITY_ZP + 2					; if x % 16 > 8, check the next colum
@column0:
    ldy ENTITY_ZP + 2
	; check if player feet is ON a slop
	lda (r0),y						; test ON feet level
	cmp #TILE_SOLD_SLOP_LEFT
	beq @on_slope
	cmp #TILE_SOLD_SLOP_RIGHT
	bne @no_slope
@on_slope:
	sta bPlayerOnSlop
	lda bPlayerOnSlop				; remove the Z flag
	rts

@no_slope:
	lda #0
	sta bPlayerOnSlop
	rts

;************************************************
; Handle entity physics when jumping or falling
;   input: r3 pointer to entity
;
physics:
	stx bSaveX

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
	ldx bSaveX
	rts

	;
	; deal with gravity driven falling
	; 
@fall:
.ifdef DEBUG
	CHECK_DEBUG
.endif
	stz bInLoop					; we are not yet the the physic loop
@loop:
	jsr Entities::get_collision_map
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
	cmp #08
	bcc :+
	eor #%00001111
	clc
	adc #09
	bra @store_y1					; if x % 16 >= 8 = delta_y:  (x=8 => y=+15, x=15 => y = +8)
:
	eor #%00001111
	sec 
	sbc #07							; if x % 16 < 8 = delta_y:  (x=0 => y=+8, x=7 => y = +0)
@store_y1:
	sta bSlopX_delta
	bra @slope_y
@slope_left:
	lda (r3),y						; X position defines how far down Y can go
	and #%00001111
	cmp #08
	beq :+							; x%16 == 8 => keep 16
	bcc :+							; x%16 < 8	+8
	sec								; x%16 > 8	-8
	sbc #08
	bra @store_y1
:
	clc
	adc #08
	sta bSlopX_delta
@slope_y:
	ldy #Entity::levely
	lda (r3),y
	and #%00001111
	bne :+
	lda #$10						; dirty trick y % 16 == 0 => convert to $10 (far end of the tile) 
:
	cmp bSlopX_delta
	bcc @no_collision_down
	jmp @sit_on_solid

@no_collision_down:	
	lda bInLoop						; only modify the status and t if we are not in the loop
	bne @drive_fall

	lda #01
	sta bInLoop

	; if the entity is connected to another, sever the link

	ldy #Entity::connectedID
	lda (r3),y
	cmp #$ff
	beq :+

	; TODO //////////////////////////////////////////////////////////
	tax

	; call virtual function of the remote object to unbind
	lda indexLO,x
	sta r9L
	lda indexHI,x
	sta r9H
	jsr Entities::unbind

	; call virtual function of the remote object to unbind
	lda r3L
	sta r9L
	lda r3H
	sta r9H
	lda indexLO,x
	sta r3L
	lda indexHI,x
	sta r3H
	jsr Entities::unbind
	lda r9L
	sta r3L
	lda r9H
	sta r3H				; restore this

	; TODO \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\

	; if the player is already falling, increase t
:
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
	bne @check_loop
	lda #FALL_LO_TICKS
	sta (r3),y									
	iny
	lda (r3),y
	inc 
	sta (r3),y

@check_loop:
	ldy #Entity::falling_ticks + 1
	lda (r3),y
	bne @start_drive_fall
	jmp @fall_once

@start_drive_fall:	
	sta r9L

@drive_fall:
	; move the player down #(falling_ticks + 1)
	jsr position_y_inc

	dec r9L
	beq @apply_delta_x
	jmp @loop						; take t in count for gravity

@apply_delta_x:
	; we did all the Y modification, so now as there was no collision we can move X
	ldy #Entity::delta_x
	lda (r3),y
	beq :+						; delta_x == 0 => entity is not moving left or right
	bmi @fall_left					; delta_x < 0 => move left
	bra @fall_right
:
	ldx bSaveX
	rts

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
	lda bPlayerOnSlop
	beq @move_x_inc

	; on slope, check if we can move on X axis
	ldy #Entity::levely
	lda (r3),y
	and #%00001111
	bne :+
	lda #$10						; dirty trick y % 16 == 0 => convert to $10 (far end of the tile) 
:
	cmp bSlopX_delta
	bcc @move_x_inc
@cannot_move_x:
	ldx bSaveX
	rts

@move_x_inc:	
	jsr position_x_inc
	ldx bSaveX
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
	ldx bSaveX
	rts	
@no_fcollision_left:
	lda bPlayerOnSlop
	beq @move_x_dec

	; on slope, check if we can move on X axis
	ldy #Entity::levely
	lda (r3),y
	and #%00001111
	bne :+
	lda #$10						; dirty trick y % 16 == 0 => convert to $10 (far end of the tile) 
:
	cmp bSlopX_delta
	bcc @move_x_dec
@cannot_move_x_dec:
	ldx bSaveX
	rts
@move_x_dec:
	jsr position_x_dec
	ldx bSaveX
	rts

@fall_once:
	jsr position_y_inc
	bra @apply_delta_x

@sit_on_solid:
	ldy #Entity::bFlags
	lda (r3),y
	and #(255-EntityFlags::physics)
	sta (r3),y						; disengage physics engine for that entity

	; change the status if falling
	ldy #Entity::status
	lda (r3),y
	cmp #STATUS_FALLING
	bne @return
	lda #STATUS_WALKING_IDLE
	sta (r3),y

@return:
	ldx bSaveX
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
	jsr Entities::get_collision_map

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
	ldx bSaveX
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
	ldx bSaveX
	rts	
@no_collision_left:
	jsr position_x_dec
	ldx bSaveX
	rts

@apex:
    ldy #Entity::status
	lda #STATUS_JUMPING_IDLE
	sta (r3),y

	ldx bSaveX
	rts

;************************************************
; Try to move entity to the right
;	input : X = entity ID
;	return: A = 00 => succeeded to move
;			A = ff => error_right_border
;			A = 02 => error collision on right
;	
move_right:
	lda indexHI,x
	sta r3H
	lda indexLO,x
	sta r3L

move_right_entry:
	; cannot move if we are at the border
	ldy #Entity::levelx + 1
	lda (r3), y
	cmp #>(LEVEL_WIDTH - 32)
	bne @not_border

	ldy #Entity::levelx
	lda (r3), y
	cmp #<(LEVEL_WIDTH - 32)
	bne @not_border

@failed_border:
	lda #$ff
	rts

@not_border:
	ldy #Entity::collision_addr
	lda (r3), y 
	sta r0L
	iny
	lda (r3), y 
	sta r0H

	jsr Entities::check_collision_right
	tax
	beq @no_collision						; block is collision on the right  and there is no slope on the right
	txa
	rts										; return the collision tile code

@no_collision:
	; set direction vector
	ldy #Entity::delta_x
	lda #01
	sta (r3),y

	; move the entity in the level
	jsr Entities::position_x_inc		
	jsr Entities::get_collision_map

	; activate physics engine
	ldy #Entity::bFlags
	lda (r3),y
	ora #(EntityFlags::physics)
	sta (r3),y

	lda #00
	rts

;************************************************
; Try to move entity to the left
;	input : X = entity ID
;	return: A = 00 => succeeded to move
;			A = ff => error_right_border
;			A = 02 => error collision on right
;	
move_left:
	lda indexHI,x
	sta r3H
	lda indexLO,x
	sta r3L

move_left_entry:
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
	ldy #Entity::collision_addr
	lda (r3), y 
	sta r0L
	iny
	lda (r3), y 
	sta r0H

	jsr Entities::check_collision_left
	tax
	beq @no_collision						
	txa										; block is collision on the left  and there is no slope on the right
	rts										; return the collision tile code

@no_collision:
	; set direction vector LEFT
	ldy #Entity::delta_x
	lda #$ff
	sta (r3),y

	; move the entity in the level
	jsr Entities::position_x_dec	
	jsr Entities::get_collision_map

	; activate physics engine
	ldy #Entity::bFlags
	lda (r3),y
	ora #(EntityFlags::physics)
	sta (r3),y

	lda #00
	rts

;************************************************
; try to move the player down (crouch, hide, move down a ladder)
;	input r3 = entity pointer
;	output: A=00 => moved down, A=01 => blocked
;	
move_down:
	jsr Entities::get_collision_map
	jsr Entities::bbox_coverage
	lda r2L 
	clc
	adc #(LEVEL_TILES_WIDTH * 2)	; check below the player
	tay

@test_colum:
	lda (r0L),y
	beq @next_column

	sty $30
	tay
	lda tiles_attributes,y
	bit #TILE_ATTR::SOLID_GROUND
	bne @cannot_move_down
	ldy $30
@next_column:
	dex 
	beq @move_down
	iny
	bra @test_colum

@move_down:
	jsr Entities::position_y_inc					; move down 
	lda #01
	rts

@cannot_move_down:
	lda #00
	rts

;************************************************
; try to move the player up (move up a ladder)
;	only climb a ladder if the 16 pixels mid-X are fully enclosed in the ladder
;	modify: r0, r1, r2
;	
move_up:
	jsr Entities::get_collision_map
	jsr Entities::bbox_coverage
	ldy r2L

	; check the situation ABOVE the player
	sec
	lda r0L
	sbc #LEVEL_TILES_WIDTH
	sta r0L
	lda r0H
	sbc #0
	sta r0H

@test_colum:
	lda (r0L),y
	beq @next_column
	sty $30
	tay
	lda tiles_attributes,y
	bit #TILE_ATTR::SOLID_CEILING
	bne @cannot_move_up
	ldy $30
@next_column:
	dex 
	beq @move_up
	iny
	bra @test_colum

@move_up:
	jsr Entities::position_y_dec		; move up
	lda #01
	rts

@cannot_move_up:
	lda #00
	rts

;************************************************
; virtual function bind
;   input: r3 = this
;   input: r9 = start of connected object
;
bind:
	ldy #Entity::id
	lda (r3),y							; link the grabbed object back
	ldy #Entity::connectedID
	sta (r9),y

	; simulate a jsr ((r3),y)
	ldy #Entity::fnBind+1
	lda (r3),y
	bne @call_children
	rts
@call_children:	
	sta @jsr + 2
	dey
	lda (r3),y
	sta @jsr + 1
@jsr:
	jmp 0000							; call children class

;************************************************
; virtual function unbind
;   input: r3 = this
;   input: r9 = start of connected object
;
unbind:
	lda #$ff
	ldy #Entity::connectedID
	sta (r3),y

	; simulate a jsr ((r3),y)
	ldy #Entity::fnUnbind+1
	lda (r3),y
	bne @call_children
	rts
@call_children:	
	sta @jsr + 2
	dey
	lda (r3),y
	sta @jsr + 1
@jsr:
	jmp 0000							; call children class

;************************************************
; virtual function move_right
;   input: X = entityID
;
fn_move_right:
	lda indexHI,x
	sta r3H
	lda indexLO,x
	sta r3L

	ldy #Entity::fnMoveRight+1
	lda (r3),y
	bne @call_subclass
	jmp Entities::move_right_entry
@call_subclass:
	sta @jsr + 2
	dey
	lda (r3),y
	sta @jsr + 1
@jsr:
	jmp 0000

;************************************************
; virtual function move_left
;   input: X = entityID
;
fn_move_left:
	lda indexHI,x
	sta r3H
	lda indexLO,x
	sta r3L

	ldy #Entity::fnMoveLeft+1
	lda (r3),y
	bne @call_subclass
	jmp Entities::move_left_entry
@call_subclass:
	sta @jsr + 2
	dey
	lda (r3),y
	sta @jsr + 1
@jsr:
	jmp 0000

;************************************************
; virtual function move_down
;   input: X = entityID
;
fn_move_down:
	lda indexHI,x
	sta r3H
	lda indexLO,x
	sta r3L

	ldy #Entity::fnMoveDown+1
	lda (r3),y
	bne @call_subclass
	rts							; move_down not implemented
@call_subclass:
	sta @jsr + 2
	dey
	lda (r3),y
	sta @jsr + 1
@jsr:
	jmp 0000

;************************************************
; virtual function move_up
;   input: X = entityID
;
fn_move_up:
	lda indexHI,x
	sta r3H
	lda indexLO,x
	sta r3L

	ldy #Entity::fnMoveUp+1
	lda (r3),y
	bne @call_subclass
	rts							; ; move_up not implemented
@call_subclass:
	sta @jsr + 2
	dey
	lda (r3),y
	sta @jsr + 1
@jsr:
	jmp 0000

;************************************************
; virtual function physics
;   input: R3 = current entity
;
fn_physics:
	ldy #Entity::fnPhysics+1
	lda (r3),y
	bne @call_subclass
	jmp Entities::physics
@call_subclass:
	sta @jsr + 2
	dey
	lda (r3),y
	sta @jsr + 1
@jsr:
	jmp 0000

.endscope