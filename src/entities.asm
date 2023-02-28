;-----------------------------------------------------------------------------
;/////////////////////////////////////////////////////////////////////////////
;           start ENTITY code
;\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------------------------------

.struct Entity
	id			.byte	; id of the entity
	classID		.byte	; classID
    spriteID    .byte   ; ID of the vera sprite
	status		.byte	; status of the player : IDLE, WALKING, CLIMBING, FALLING
	connectedID	.byte	; EntityID connected to that one
    levelx      .word   ; level position
    levely      .word 
	falling_ticks .word	; ticks since the player is falling (thing t in gravity) 
	delta_x		.byte	; when driving by phisics, original delta_x value

	bWidth		.byte	; widht in pixel of the entity
	bHeight		.byte	; Height in pixel of the entity
	bFeetIndex	.byte	; Index of the feet in TILES 
	bFlags		.byte	; position of the entity was changed
	bXOffset	.byte	; signed offset of the top-left corder of the sprite vs the collision box
	bYOffset	.byte	;
	collision_addr	.addr	; cached @ of the collision equivalent of the center of the player
.endstruct

.enum EntityFlags
	physics = 1
	moved = 2
	colission_map_changed = 4
.endenum

.enum Status
	IDLE
	SLIDE_LEFT=11
	SLIDE_RIGHT=12
.endenum

.enum Collision
	NONE
	GROUND
	SLOPE
	SPRITE
	SCREEN = 255
.endenum
.scope Entities

MAX_ENTITIES = 16
ENTITY_ZP = $0065

bCurentTile = ENTITY_ZP
bLeftOrRight = ENTITY_ZP + 1

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

; virtual function pointers
fnBind_table = save_position_yH + MAX_ENTITIES * 2
fnUnbind_table = fnBind_table + MAX_ENTITIES * 2
fnMoveRight_table = fnUnbind_table + MAX_ENTITIES * 2
fnMoveLeft_table = fnMoveRight_table + MAX_ENTITIES * 2
fnMoveUp_table = fnMoveLeft_table + MAX_ENTITIES * 2
fnMoveDown_table= fnMoveUp_table + MAX_ENTITIES * 2
fnPhysics_table= fnMoveDown_table + MAX_ENTITIES * 2
fnSetPhysics_table= fnPhysics_table + MAX_ENTITIES * 2

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

	jsr height_tiles
	ldy #Entity::bFeetIndex
	sta (r3), y

init_next:
	lda #01
	ldy #Entity::bFlags
	lda #(EntityFlags::physics | EntityFlags::moved | EntityFlags::colission_map_changed)
	sta (r3),y	; force screen position and size to be recomputed

	; register virtual function bind/unbind
	lda (r3)			; entityID
	asl
	tax
	lda #00
	sta fnBind_table,x
	lda #00
	sta fnBind_table+1,x

	lda #00
	sta fnUnbind_table,x
	sta fnMoveLeft_table,x
	sta fnMoveRight_table,x
	lda #00
	sta fnUnbind_table+1,x
	sta fnMoveLeft_table+1,x
	sta fnMoveRight_table+1,x

	lda #<Entities::move_up
	sta fnMoveUp_table,x
	lda #>Entities::move_up
	sta fnMoveUp_table+1,x

	lda #<Entities::move_down
	sta fnMoveDown_table,x
	lda #>Entities::move_down
	sta fnMoveDown_table+1,x

	lda #<Entities::set_physics_entity
	sta fnSetPhysics_table,x
	lda #>Entities::set_physics_entity
	sta fnSetPhysics_table+1,x

	jsr Entities::set_physics

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

	phx

	ldy #Entity::bFlags
	lda (r3),y
	bit #EntityFlags::physics
	beq :+			; nothing to do
	jsr fn_physics

:
	ldy #Entity::bFlags
	lda (r3),y
	bit #EntityFlags::moved
	beq :+			; nothing to do
	jsr Entities::set_position
	jsr Entities::get_collision_map
:
	plx
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
; force X position
;   input: R3 = start of the object
;			A = low X
;			X = hi X
;
position_x:
	ldy #Entity::levelx
    sta (r3),y
    iny
	txa
    sta (r3),y

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
; force Y position
;   input: R3 = start of the object
;			A = low y
;			X = hi y
;
position_y:
	ldy #Entity::levely
    sta (r3),y
    iny
	txa
    sta (r3),y

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
; convert height in pixel to height in tiles
;	input : r3 = this
;	output : A = height in tiles
;
height_tiles:
	; compute the height of the entity in tiles
	ldy #Entity::bHeight
	lda (r3),y
	lsr
	lsr
	lsr
	lsr
	dec
	tax
	clc
	lda #00
:	
	adc #LEVEL_TILES_WIDTH
	dex
	bne :-
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
	ldy bTilesWidth

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
	bne @collision					; else check the tilemap attributes
	bit #TILE_ATTR::SOLID_WALL_LEFT
	beq @test_next_line1
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
; output : A = 00 : no collision
;			01 : hit tile
;			02 : hit slop
;			03 : hit sprite
;			ff : bottom of the screen
;
check_collision_down:
	; if levely == LEVEL_HEIGHT - sprite.width => collision
	ldy #Entity::levely + 1
	lda (r3),y
	beq @check_tiles			; if x < 256, no need to test right border
	ldy #Entity::levely
	lda (r3),y
	ldy #Entity::bHeight
	adc (r3),y
	cmp #<(LEVEL_HEIGHT)
	bne @check_tiles

	lda #Collision::SCREEN
	sta bCurentTile
	rts

@check_tiles:
	jsr get_collision_map
	jsr get_feet

	tay							; test at feet level
@test_feet:
	lda (r0),y
	sta bCurentTile
	bne @test_tile				; not empty tile, check it
@test_below:
	ldy #Entity::levely
	lda (r3),y
	and #$0f
	bne @check_sprites			; if y%16 == 0 then check below

@test_below_entity:
	clc
	lda bTilesHeight
	adc #LEVEL_TILES_WIDTH
	tay
	lda (r0),y
	sta bCurentTile
	beq @check_sprites			; empty tile, check the sprite aabb

	tay							; if the tile below the entity is a slop ground => no collision
	lda tiles_attributes,y
	bit #TILE_ATTR::SOLID_GROUND
	beq @no_collision

@collision:
	lda #Collision::GROUND
	rts

@test_tile:
	ldy bCurentTile
	lda tiles_attributes,y
	bit #TILE_ATTR::SOLID_GROUND
	bne @collision				
	bit #TILE_ATTR::SLOPE
	beq @check_sprites			; no slop nor ground => check the sprite aabb

@check_slop:
	lda bCurentTile
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
	eor #%00001111
@store_y1:
	sta bSlopX_delta
	bra @slope_y
@slope_left:
	ldy #Entity::levelx
	lda (r3),y						; X position defines how far down Y can go
	clc
	adc #08							; collision point is midle of the width
	and #%00001111
	sta bSlopX_delta
@slope_y:
	ldy #Entity::levely
	lda (r3),y
	and #%00001111
	eor #%00001111					; invert Y as it goes downward, but we compare upward
	cmp bSlopX_delta
	beq @collision_slop
	bcs @check_sprites		; hit the slop if y >= deltaX

@collision_slop:
	lda #Collision::SLOPE
	rts

@check_sprites:					; no tile collision, still check the sprites
	ldy #Entity::spriteID
    lda (r3),y
    tax
	lda #(01 | 04)
	ldy #01
	jsr Sprite::precheck_collision	; precheck 1 pixel right
	bmi @no_collision
	lda #Collision::SPRITE
	rts
@no_collision:
	lda #Collision::NONE
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
	
	ldy #Entity::bFeetIndex
	lda (r3),y
	clc
	adc #LEVEL_TILES_WIDTH
	sta bTilesHeight

    ldy #Entity::levelx
	lda (r3),y
	and #%00001111
	cmp #08
	bcc @column0
	beq @no_slope						; if x % 16 > 8, on the edge
@column1:
	inc bTilesHeight					; if x % 16 > 8, check the next colum
@column0:
    ldy bTilesHeight
	lda (r0),y
	tax
	lda tiles_attributes,x
	bit #TILE_ATTR::SLOPE
	bne @above_slope
@no_slope:
	lda #0
	sta bPlayerOnSlop
	rts
@above_slope:
	stx bPlayerOnSlop
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
	tax
	lda tiles_attributes,x
	bit #TILE_ATTR::SLOPE
	bne @on_slope
@column1:
	inc ENTITY_ZP + 2					; if x % 16 > 8, check the next colum
@column0:
    ldy ENTITY_ZP + 2
	; check if player feet is ON a slop
	lda (r0),y						; test ON feet level
	tax
	lda tiles_attributes,x
	bit #TILE_ATTR::SLOPE
	beq @no_slope
@on_slope:
	stx bPlayerOnSlop
	lda bPlayerOnSlop				; remove the Z flag
	rts

@no_slope:
	lda #0
	sta bPlayerOnSlop
	rts

;************************************************
; sever the link between 2 entities
; input : r3 = this
;
sever_link:
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
	ldx r9L
	lda r3L
	sta r9L
	stx r3L

	ldx r9H
	lda r3H
	sta r9H
	stx r3H				; swap *this and *remote

	jsr Entities::unbind
	lda r9L
	sta r3L
	lda r9H
	sta r3H				; restore this
:
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
	beq @no_collision_down				; solid tile below the player that is not a slope

	cmp #Collision::SLOPE
	beq @check_slope
	jmp @sit_on_solid

@check_slope:
	lda bCurentTile
	cmp #TILE_SLIDE_LEFT
	beq @set_slide_left
	cmp #TILE_SLIDE_RIGHT
	beq @set_slide_right
	jmp @sit_on_solid				; We are on a normal slope

@set_slide_left:
	lda #Status::SLIDE_LEFT
	bra :+
@set_slide_right:
	lda #Status::SLIDE_RIGHT
:
	ldy #Entity::status
	sta (r3),y						; force the slide status
	jmp Entities::set_physics_slide	; change the physics for the slider engine

@no_collision_down:	
	lda bInLoop						; only modify the status and t if we are not in the loop
	bne @drive_fall

	lda #01
	sta bInLoop

	; if the entity is connected to another, sever the link
	jsr sever_link

	; if the player is already falling, increase t
	ldy #Entity::status
	lda (r3),y
	cmp #STATUS_FALLING
	beq @increase_ticks

	; start the falling timer
	lda #$ff
	jsr fn_set_noaction

	ldy #Entity::status
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
	lda #$ff
	jsr fn_restore_action

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
	ldx bSaveX
	rts	
@no_collision_right:
	jsr position_x_inc
	rts
@jump_left:
	jsr check_collision_left
	beq @no_collision_left
@collision_left:
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
; sliding physics
;   input: r3 pointer to entity
;

set_physics:
	lda (r3)		; entityID
	asl
	tax
	jmp (fnSetPhysics_table,x)

set_physics_entity:
	lda #<Entities::physics
	sta fnPhysics_table,x
	lda #>Entities::physics
	sta fnPhysics_table+1,x
	rts

;************************************************
; sliding physics
;   input: r3 pointer to entity
;
physics_slide:
	; get the index of tile below the player
	ldy #Entity::bFeetIndex
	lda (r3),y
	clc
	adc #LEVEL_TILES_WIDTH
	sta bTilesHeight

	jsr Entities::get_collision_map

	; check if we reached a floor
	ldy #Entity::levely
	lda (r3),y
	and #$0f
	bne @on_sliding_tile

	; and check left or right
	ldy #Entity::status
	lda (r3),y
	cmp #Status::SLIDE_RIGHT
	beq @sl_after
@sl_before:
	ldy bTilesHeight
	bra @test_next
@sl_after:
	ldy bTilesHeight
	iny
@test_next:
	lda (r0),y
	beq @finish					; restore normal physic if there is no support
	tax
	lda tiles_attributes,x
	bit #TILE_ATTR::SOLID_GROUND
	bne @horizontal				; finish the slide on an horizontal surface
	bit #TILE_ATTR::SLOPE
	beq @finish					; the next tile is not a slope
	cpx #TILE_SLIDE_LEFT
	beq @on_sliding_tile_left
	cpx #TILE_SLIDE_RIGHT
	bne @finish					; not any more on a slide slope, but a normal slope

@on_sliding_tile_right:
	lda #Status::SLIDE_RIGHT
	bra @set_sliding_tile
	; continue sliding to the next tile
@on_sliding_tile_left:
	lda #Status::SLIDE_LEFT
@set_sliding_tile:
	ldy #Entity::status
	sta (r3),y
	bra @go_slide				; skip testing, move directly

@on_sliding_tile:
	jsr Entities::check_collision_down
:
	cmp #Collision::SLOPE
	beq @go_slide
	bra @finish					; any other collision breaks the sliding

@go_slide:
	lda (r3)					; EntityID
	tax
	jsr Entities::save_position_r3
	jsr Entities::position_y_inc

@slide_left_right:
	; and now move left or right
	ldy #Entity::id
	lda (r3), y
	tax

	ldy #Entity::status
	lda (r3),y
	cmp #Status::SLIDE_LEFT
	beq @slide_left
@slide_right:
	jsr Entities::check_collision_right
	bne @blocked_side
	jsr Entities::position_x_inc
	rts
@slide_left:
	jsr Entities::check_collision_left
	bne @blocked_side
	jsr Entities::position_x_dec
	rts

@horizontal:
	ldy #Entity::levelx
	lda (r3), y
	and #$0f
	bne @slide_left_right
@finish:
	ldy #Entity::status
	lda #STATUS_WALKING_IDLE
	sta (r3),y
	lda #$ff
	jsr Entities::fn_restore_action
	jmp Entities::set_physics
@blocked_side:
	lda (r3)		; EntityID
	tax
	jsr Entities::restore_position		; keep the entity on position, until the block is removed
	rts

set_physics_slide:
	lda (r3)		; entityID
	asl
	tax
	lda #<Entities::physics_slide
	sta fnPhysics_table,x
	lda #>Entities::physics_slide
	sta fnPhysics_table+1,x

	lda #%00001111
	jmp Entities::fn_set_noaction

;************************************************
; Get the index of the feet on the collision map
;	input : r3 = current entity
;	return: A = index
get_feet:
	ldy #Entity::bFeetIndex
	lda (r3),y
	sta bTilesHeight			; height of the entity in tiles lines

	ldy #Entity::levely			; if y % 16 <> 0 then add an extra line
	lda (r3),y
	and #$0f
	beq :+
	clc
	lda bTilesHeight
	adc #LEVEL_TILES_WIDTH
	sta bTilesHeight
:

	ldy #Entity::levelx
	lda (r3),y
	and #$0f
	cmp #$08
	bcc :+
	inc bTilesHeight			; if X % 16 > 8, test the second colum
:
	lda bTilesHeight
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

	;test the current tile the entity is sitting on
	jsr get_feet
	tay
	lda (r0),y
	sta bCurentTile
	beq @not_on_slop				; NOT on a slope, still check the pixel below

	tax
	lda tiles_attributes,x
	bit #TILE_ATTR::SLOPE
	beq @return

@on_slop:
	; if we are on the edge of tile, just go up/down based on the tile
	ldy #Entity::levelx
	lda (r3),y
	and #$0f
	cmp #$08
	beq @not_on_slop

@walk_slop:
	; continue walking up or down
	lda bCurentTile
	cmp #TILE_SOLD_SLOP_LEFT
	beq @go_up
	cmp #TILE_SLIDE_LEFT
	beq @go_up					; walk up but activate sliding to go back
@go_down:
	jsr Entities::position_y_inc
	bra @return
@go_up:
	jsr Entities::position_y_dec
	; after 4 pixels, engage physics to slide down
	ldy #Entity::levelx
	lda (r3),y
	and #$0f
	tax
	lda #Status::SLIDE_LEFT
	cpx #$00
	beq @set_slide
@return:
	lda #00
	rts

@not_on_slop:
	; test below the entity
	clc
	lda bTilesHeight
	adc #LEVEL_TILES_WIDTH
@move_right_try_slop:
	tay
	lda (r0),y
	beq @fall
	sta bCurentTile
	tax
	lda tiles_attributes,x
	bit #TILE_ATTR::SLOPE
	bne @set_slope
	lda #00
	rts

@set_slope:
	lda bCurentTile
	cmp #TILE_SLIDE_RIGHT
	beq @set_slide_right
	cmp #TILE_SLIDE_LEFT
	bne @walk_slop
@set_slide_right:
	jsr Entities::position_y_inc
	lda #Status::SLIDE_RIGHT
	bra @set_slide
@set_slide_left:
	jsr Entities::position_y_dec
	lda #Status::SLIDE_LEFT
@set_slide:
	ldy #Entity::status
	sta (r3),y
	jsr Entities::set_physics_slide
	jsr Entities::sever_link						; if the entity is connected to another, sever the link

	; activate physics engine
	ldy #Entity::bFlags
	lda (r3),y
	ora #(EntityFlags::physics)
	sta (r3),y
	lda #00
	rts

@fall:
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

	;test the current tile the entity is sitting on
	jsr get_feet
	tay
	ldy bTilesHeight
	lda (r0),y
	sta bCurentTile
	beq @not_on_slop				; NOT on a slope, still check the pixel below

	tax
	lda tiles_attributes,x
	bit #TILE_ATTR::SLOPE
	beq @return

@on_slop:
	; if we are on the edge of tile, just go up/down based on the tile
	ldy #Entity::levelx
	lda (r3),y
	and #$0f
	cmp #$08
	beq @not_on_slop

@walk_slop:
	; continue walking up or down
	lda bCurentTile
	cmp #TILE_SOLD_SLOP_RIGHT
	beq @go_up
	cmp #TILE_SLIDE_RIGHT
	beq @go_up
@go_down:
	jsr Entities::position_y_inc
	bra @return
@go_up:
	jsr Entities::position_y_dec
	ldy #Entity::levelx
	lda (r3),y
	and #$0f
	tax
	lda #Status::SLIDE_RIGHT
	cpx #$00
	beq @set_slide
@return:
	lda #00
	rts

@not_on_slop:
	; test below the entity
	clc
	lda bTilesHeight
	adc #LEVEL_TILES_WIDTH
@move_right_try_slop:
	tay
	lda (r0),y
	beq @fall
	sta bCurentTile
	tax
	lda tiles_attributes,x
	bit #TILE_ATTR::SLOPE
	bne @set_slope
	lda #00
	rts

@set_slope:
	lda bCurentTile
	cmp #TILE_SLIDE_RIGHT
	beq @set_slide_right
	cmp #TILE_SLIDE_LEFT
	bne @walk_slop

@set_slide_right:
	jsr Entities::position_y_inc
	lda #Status::SLIDE_LEFT
	bra @set_slide
@set_slide_left:
	jsr Entities::position_y_dec
	lda #Status::SLIDE_RIGHT
@set_slide:
	ldy #Entity::status
	sta (r3),y
	jsr Entities::set_physics_slide
	jsr Entities::sever_link						; if the entity is connected to another, sever the link

	; activate physics engine
	ldy #Entity::bFlags
	lda (r3),y
	ora #(EntityFlags::physics)
	sta (r3),y
	lda #00
	rts

@fall:
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
	; control bottom border
	ldy #Entity::levely + 1
	lda (r3), y
	beq @not_border
	dey
	lda (r3), y
	sta bSaveX
	ldy #Entity::bHeight
	lda (r3), y
	clc
	adc bSaveX
	beq :+							; overflow entity.x + entity.height = 256
	cmp #<LEVEL_HEIGHT
	bcs @not_border
:
	rts								; if entity.x + entity.height >= level.height

@not_border:
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
; try to move the player up 
;	only climb a ladder if the 16 pixels mid-X are fully enclosed in the ladder
;	modify: r0, r1, r2
;	
move_up:
	; control bottom border
	ldy #Entity::levely + 1
	lda (r3), y
	bne @not_border
	dey
	lda (r3), y
	bne @not_border
	rts								; if entity.x == 0

@not_border:
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

	ldy #Entity::id
	lda (r9),y							; link the grabbed object back
	ldy #Entity::connectedID
	sta (r3),y

	; simulate a jsr ((r3),y)
	lda (r3)		; entityID
	asl
	tax
	lda fnBind_table+1,x
	bne @call_children
	rts
@call_children:
	jmp (fnBind_table,x)

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
	lda (r3)		; entityID
	asl
	tax
	lda fnUnbind_table+1,x
	bne @call_children
	rts
@call_children:	
	jmp (fnUnbind_table,x)

;************************************************
; virtual function move_right
;   input: X = entityID
;
fn_move_right:
	lda indexHI,x
	sta r3H
	lda indexLO,x
	sta r3L

	lda (r3)
	asl
	tax
	lda fnMoveRight_table+1,x
	bne @call_subclass
	jmp Entities::move_right_entry
@call_subclass:
	jmp (fnMoveRight_table,x)

;************************************************
; virtual function move_left
;   input: X = entityID
;
fn_move_left:
	lda indexHI,x
	sta r3H
	lda indexLO,x
	sta r3L

	lda (r3)
	asl
	tax
	lda fnMoveLeft_table+1,x
	bne @call_subclass
	jmp Entities::move_left_entry
@call_subclass:
	jmp (fnMoveLeft_table,x)

;************************************************
; virtual function move_down
;   input: X = entityID
;
fn_move_down:
	lda indexHI,x
	sta r3H
	lda indexLO,x
	sta r3L

	lda (r3)
	asl
	tax
	jmp (fnMoveDown_table,x)

;************************************************
; virtual function move_up
;   input: X = entityID
;
fn_move_up:
	lda indexHI,x
	sta r3H
	lda indexLO,x
	sta r3L

	lda (r3)
	asl
	tax
	jmp (fnMoveUp_table,x)

;************************************************
; virtual function physics
;   input: R3 = current entity
;
fn_physics:
	lda (r3)
	asl
	tax
	jmp (fnPhysics_table,x)

;************************************************
; virtual function actions
;   input: R3 = current entity
;			A = block or restore actions individualy
;
fn_set_noaction:
	pha
	ldy #Entity::classID
	lda (r3),y
	asl
	tax
	pla
	jmp (class_set_noaction,x)

fn_restore_action:
	pha
	ldy #Entity::classID
	lda (r3),y
	asl
	tax
	pla
	jmp (class_restore_action,x)

set_noaction:
restore_action:
	rts

.endscope