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
    levelx_d    .byte  	; decimal
    levelx      .word   ; level position
    levely_d    .byte
    levely      .word 
	falling_ticks .byte	; ticks since the player is falling (thing t in gravity) 
	vtx			.byte	; v0.x * dt (decimal part)
	vty			.word	; v0.y * dt (HI = interger part, LOW = decimal part)
	gt			.word 	; 0.25g * dt
	delta_x_dir	.byte	; direction of the X vector
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
	IN_GROUND
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
bCheckBelow = ENTITY_ZP + 2
bSaveX = ENTITY_ZP + 3

; pixel size converted to tiles size
bTilesWidth = ENTITY_ZP + 9
bTilesHeight = ENTITY_ZP + 10

bInLoop = ENTITY_ZP + 8
bSlopX_delta = $30

; global variable to mark slope for the current entity
bPlayerOnSlop = ENTITY_ZP + 7

; number of tiles an entity covers (based on the collision box height and width)
bTilesCoveredX = r1L
bTilesCoveredY = r1H

; if TRUE do a simple tile based collision (0 = no collision)
bBasicCollisionTest = ENTITY_ZP + 9

; index of the center of the entitie on the tile map
bIndexCenter = ENTITY_ZP + 10

; quick access to levelx24bits
dDeltaX = ENTITY_ZP
dDeltaY = ENTITY_ZP + 3
bLoopY = ENTITY_ZP + 7
bSide2test = ENTITY_ZP + 8

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

; value of g
GRAVITY = 7

.include "slopes.asm"

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
	bne get_collision_map_update

	; cache the collision @
	ldy #Entity::collision_addr
	lda (r3),y
	sta r0L
	iny
	lda (r3),y
	sta r0H

	rts

get_collision_map_update:
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
	; move one tile on the left
	jsr get_collision_map
	sec
	lda r0L
	sbc #01
	sta r0L
	lda r0H
	sbc #00
	sta r0H

	; test the current column as it could be a slope
	jsr bbox_coverage

	; check center (on slopes)
	;	+--X--+
	lda #00
	sta bIndexCenter
	stz bSaveX						; check at the top of the tile vy = 0

@loop_slopes:						; test top and bottom of the entity y=0 && y=height - 1
    ldy #Entity::levelx
	lda (r3),y
	and #%00001111
	cmp #$08
	bcc :+						; if x % 16 < 8, adding 8 pixels keeps it on the same colum
	lda #02
	bra :++
:
	lda #01
:
	clc
	adc bIndexCenter
	tay
	lda (r0L),y
	beq @no_slope
	sta bCurentTile
	tay
	lda tiles_attributes,y
	bit #TILE_ATTR::SLOPE
	beq @no_slope					; if the tile on other side is a slope

	jsr Slopes::check_slop_x
	cmp #Collision::NONE
	beq @no_collision_on_line		; don't test left/right if we have no slope collision
	rts								; got a collision on the X axis with a slope

@no_slope:
	;only test left/right if we are on a tile edge
    ldy #Entity::levelx
	lda (r3),y
	and #%00001111
	bne @no_collision_on_line

@check_leftright:
	; check border (if NOT on slope slopes)
	;	X-----X
	lda bSide2test
	bpl @right
@left:
	ldy bIndexCenter				; r0 = tile on the left, so index=0
	bra @test_border
@right:
	clc
	lda bIndexCenter
	adc bTilesWidth
	inc								; r0 = tile on the left, so index=width+1
	tay
@test_border:
	lda (r0L),y
	sta bCurentTile
	beq @no_collision_on_line

	tay
	lda tiles_attributes,y
	bit #TILE_ATTR::SLOPE
	bne @no_collision_on_line		; if the tile on other side is a slope, ignore the slope
	bit #TILE_ATTR::SOLID_WALL
	bne @collision					; else check the tilemap attributes
	bit #TILE_ATTR::SOLID_WALL_LEFT
	bne @collision

@no_collision_on_line:
	dec bTilesCoveredY
	beq @no_collision

	clc
	lda bIndexCenter
	adc #LEVEL_TILES_WIDTH			; test the tile on the right of the player (hip position)
	sta bIndexCenter

	lda #$0f
	sta bSaveX						; move Y to the bottom of the tile

	bra @loop_slopes

@collision:
	lda bCurentTile
	rts
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
	lda #Collision::SCREEN
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
	lda #Collision::SPRITE
	rts

@no_collision:
	lda #Collision::NONE
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
	stz bCheckBelow				; bCheckBelow = FALSE => checking at feet level
	lda (r0),y
	sta bCurentTile
	bne @test_tile				; not empty tile, check it

@test_below:
	ldy #Entity::levely
	lda (r3),y
	and #$0f
	bne @check_sprites			; if y%16 == 0 then check below

@test_below_entity:
	inc bCheckBelow
	clc
	lda bTilesHeight
	adc #LEVEL_TILES_WIDTH
	tay
	lda (r0),y
	sta bCurentTile
	beq @check_sprites			; empty tile, check the sprite aabb

@test_tile:
	ldy bCurentTile
	lda tiles_attributes,y
	bit #TILE_ATTR::SOLID_GROUND
	bne @ground
	bit #TILE_ATTR::SLOPE
	beq @check_sprites			; no slop nor ground => check the sprite aabb

@check_slop:
	jsr Slopes::check_slop_y	; check if we hit a slop on the Y axis
	cmp #Collision::NONE
	beq @check_sprites
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
@ground:
	lda Entities::bCheckBelow
	beq @in_ground					; when checking at feet level, return we are sitting on a ground
@ground_down:
	lda #Collision::GROUND
	rts
@in_ground:
	lda #Collision::IN_GROUND
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
kick_fall:
    ldy #Entity::status
	lda #STATUS_FALLING
	sta (r3),y
	lda #01
	ldy #Entity::falling_ticks
	sta (r3),y						; time t = 0
	lda #00
	ldy #Entity::levely_d
	sta (r3),y						; levely.0
	ldy #Entity::vtx
	sta (r3),y						; deltax = 0.deltax
	ldy #Entity::vty
	sta (r3),y						
	ldy #Entity::gt
	sta (r3),y						
	ldy #Entity::gt + 1
	sta (r3),y						; deltax = 0.deltax
	rts

;
; Move left/right using a decimal byte 
;
move_left_right:
	ldy #Entity::delta_x_dir	; move X using decimals
	lda (r3),y
	bne :+
	rts
:
	bpl @right
@left:
	ldy #Entity::vtx		; move X using decimals
	clc
	lda (r3),y
	ldy #Entity::levelx_d
	adc (r3),y
	sta (r3),y
	bcc :+
	jsr position_x_dec
:
	rts
@right:
	ldy #Entity::vtx		; move X using decimals
	clc
	lda (r3),y
	ldy #Entity::levelx_d
	adc (r3),y
	sta (r3),y
	bcc :+
	jsr position_x_inc
:
	rts

;
; Move left/right using a decimal byte 
;
physics1:
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

	ldy #Entity::status
	lda (r3),y
	cmp #STATUS_CLIMBING
	beq @return1
	cmp #STATUS_CLIMBING_IDLE
	bne @phys
@return1:
	ldx bSaveX
	rts

	;
	; deal with gravity driven falling
	; 
@phys:
	ldy #Entity::falling_ticks	; if t = 0 => no activity
	lda (r3),y
	bne @do
@justcheck:
	jsr get_collision_map
	jsr check_collision_down
	bne @sit_on_solid1				; trigger fall if no ground
	jsr kick_fall
	ldy #Entity::vtx
	lda #$00
	sta (r3),y						; deltax = 0.deltax
	ldy #Entity::delta_x_dir
	lda #00
	sta (r3),y
	rts
@sit_on_solid1:
	jmp sit_on_solid	
@do:
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
	ldy #Entity::vtx
	lda (r3),y
	bpl @positive_vtx
	ldy #Entity::levelx_d
	adc (r3),y
	sta (r3),y
	ldy #Entity::levelx
	lda (r3),y
	adc #$ff
	sta r12
	ldy #Entity::levelx + 1
	lda (r3),y
	adc #$ff
	sta r12H				; p0.x += entity.vtx
	bra :+

@positive_vtx:	
	ldy #Entity::levelx_d
	adc (r3),y
	sta (r3),y
	ldy #Entity::levelx
	lda (r3),y
	adc #$00
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
	jsr position_x_dec
	jsr Entities::get_collision_map_update
	jsr check_collision_left
	beq @no_collision_left
	ldy #Entity::vtx
	lda #00
	sta (r3),y
	inc
	sta (r3),y						; set vtx to ZERO
	lda #$ff
	rts
@no_collision_left:
	lda #00
	rts

move_x_right:
	jsr position_x_inc
	jsr Entities::get_collision_map_update
	jsr check_collision_right
	beq @no_collision_right
	lda #00
	sta (r3),y
	inc
	sta (r3),y						; set vtx to ZERO
	lda #$ff
	rts
@no_collision_right:
	lda #00
	rts
	
move_y_up:
	jsr position_y_inc
	jmp physics_check
move_y_down:
	jsr position_y_dec
physics_check:
	; refresh r3
	jsr Entities::get_collision_map_update

	jsr check_collision_down
	beq @no_collision_down			; solid tile below the player that is not a slope
	cmp #Collision::SLOPE
	beq @no_collision_down			; there is a slope below the player feet, so we continue falling
	cmp #Collision::SCREEN
	beq sit_on_solid
	cmp #Collision::SPRITE
	bne sit_on_solid

@no_collision_down:	
	lda #00
	rts

	; Collision::GROUND
sit_on_solid:
	ldy #Entity::bFlags
	lda (r3),y
	and #(255-EntityFlags::physics)
	sta (r3),y						; disengage physics engine for that entity

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
	jmp Entities::set_physics_slide	; change the physics for the slider engine

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
	jsr save_position_r3
	jsr Entities::get_collision_map
	jsr get_feet
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
	lda #$ff
	jsr Entities::fn_restore_action
	jmp Entities::set_physics

set_physics_slide:
	lda (r3)		; entityID
	asl
	tax
	lda #<Entities::physics_slide
	sta fnPhysics_table,x
	lda #>Entities::physics_slide
	sta fnPhysics_table+1,x

	ldy #Entity::bFlags
	lda (r3),y
	ora #EntityFlags::physics
	sta (r3),y						; engage physics engine for that entity

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
	jsr get_collision_map
	jsr Entities::check_collision_right
	beq @no_collision
	cmp #Collision::SLOPE
	beq @no_collision						; if we are straight on a slope, move on
	rts										; return the collision tile code

@no_collision:
	; set direction vector
	ldy #Entity::delta_x_dir
	lda #01
	sta (r3),y

	;test the current tile the entity is sitting on
	jsr get_feet
	tay
	lda (r0),y
	sta bCurentTile
	cmp #TILE::SOLD_SLOP_LEFT
	beq @go_up_slope
	cmp #TILE::SLIDE_LEFT
	beq @go_up_slide			; walk up but activate sliding to go back
	cmp #TILE::SOLD_SLOP_RIGHT
	beq @go_down_slope

	; move the entity in the level on the x axe
@go_right:
	jsr Entities::position_x_inc
	bra @next
@go_up_slope:
	jsr Entities::position_x_inc
	jsr Entities::position_y_dec
	bra @next
@go_down_slope:
	jsr Entities::position_x_inc
	jsr Entities::position_y_inc
	bra @next
@go_up_slide:
	jsr Entities::position_x_inc
	jsr Entities::position_y_dec
	ldy #Entity::levelx
	lda (r3),y
	and #$0f
	bne @next
	ldy #Entity::status
	lda #Status::SLIDE_LEFT
	sta (r3),y
	jsr Entities::set_physics_slide
	jsr Entities::sever_link						; if the entity is connected to another, sever the link
	lda #00
	rts

@next:
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
	ldy #Entity::status
	sta (r3),y
	jsr Entities::set_physics_slide
	jsr Entities::sever_link						; if the entity is connected to another, sever the link

@fall:
	; activate physics engine
	ldy #Entity::bFlags
	lda (r3),y
	ora #(EntityFlags::physics)
	sta (r3),y

	jsr kick_fall

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
	jsr get_collision_map
	jsr Entities::check_collision_left		; warning, this command changes r0
	beq @no_collision
	cmp #Collision::SLOPE
	beq @no_collision						; if we are straight on a slope, move on
	rts										; return the collision tile code

@no_collision:
	; set direction vector LEFT
	ldy #Entity::delta_x_dir
	lda #$ff
	sta (r3),y

	;test the current tile the entity is sitting on
	jsr get_collision_map
	jsr get_feet
	tay
	lda (r0),y
	sta bCurentTile
	cmp #TILE::SOLD_SLOP_RIGHT
	beq @go_up_slope
	cmp #TILE::SLIDE_RIGHT
	beq @go_up_slide			; walk up but activate sliding to go back
	cmp #TILE::SOLD_SLOP_LEFT
	beq @go_down_slope
	; move the entity in the level on the x axe
@go_left:
	jsr Entities::position_x_dec
	bra @next
@go_up_slope:
	jsr Entities::position_x_dec
	jsr Entities::position_y_dec
	bra @next
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
	bra @next
@go_down_slope:
	jsr Entities::position_x_dec
	jsr Entities::position_y_inc

@next:
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
	ldy #Entity::status
	lda #Status::SLIDE_LEFT
	sta (r3),y
	jsr Entities::set_physics_slide
	jsr Entities::sever_link						; if the entity is connected to another, sever the link

@fall:
	; activate physics engine
	ldy #Entity::bFlags
	lda (r3),y
	ora #(EntityFlags::physics)
	sta (r3),y

	jsr kick_fall

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

physics:
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

	sec
	ldy #Entity::levelx
	lda (r3),y
	sbc #01
	sta r12
	ldy #Entity::levelx + 1
	lda (r3),y
	sbc #00
	sta r12H

	ldy #Entity::levely
	lda (r3),y
	sta r13
	ldy #Entity::levely + 1
	lda (r3),y
	sta r13H

	jsr Utils::line			; bresenham line to move between the points
	beq @return
	jmp sit_on_solid

@return:
	rts
.endscope