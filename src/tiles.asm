;-----------------------------------------------------------------------------
;/////////////////////////////////////////////////////////////////////////////
; START Tiles code
;\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------------------------------

.enum TILE_ATTR
    NONE = 0
	SOLID_GROUND = 1
	SOLID_WALL = 2
    SOLID_WALL_LEFT = 4
	SOLID_CEILING = 8
	GRABBING = 16			; player can grab the tile (ladder, ledge, rope)
    LADDER = 32             ; player can climb uop/down (ladder, rope)
    SLOPE = 64
.endenum

.enum
	TILE_NO_COLLISION
	TILE_SOLID_GROUND
	TILE_SOLD_SLOP_LEFT
	TILE_SOLD_SLOP_RIGHT
	TILE_SOLID_LADER
	TILE_LEDGE
	TILE_SOLID_TOP
	TILE_WATER
	TILE_SOLID_GRAB			; edgge of the tile can be grabbed to walk on
	TILE_TOP_LADDER
	TILE_TOP_LEDGE
	TILE_HANG_FROM
	TILE_ROPE
	TILE_TOP_ROPE
    TILE_SLIDE
.endenum

tiles_attributes: 
	.byte %00000000	;	TILE_NO_COLLISION
	.byte %00000111	;	TILE_SOLID_GROUND
	.byte TILE_ATTR::SLOPE	;	TILE_SOLD_SLOP_LEFT
	.byte TILE_ATTR::SLOPE	;	TILE_SOLD_SLOP_RIGHT
	.byte TILE_ATTR::GRABBING | TILE_ATTR::LADDER	;	TILE_SOLID_LADER
	.byte TILE_ATTR::GRABBING		;	TILE_LEDGE
	.byte TILE_ATTR::SOLID_GROUND	;	TILE_FLOOR
	.byte TILE_ATTR::NONE			;	TILE_WATER
	.byte %00001111					;	TILE_SOLID_GRAB
	.byte TILE_ATTR::SOLID_GROUND | TILE_ATTR::GRABBING	| TILE_ATTR::LADDER; TILE_TOP_LADDER
	.byte TILE_ATTR::SOLID_GROUND | TILE_ATTR::GRABBING	; TILE_TOP_LEDGE
	.byte TILE_ATTR::GRABBING		; TILE_HANG_FROM
	.byte TILE_ATTR::GRABBING | TILE_ATTR::LADDER		; TILE_ROPE
	.byte TILE_ATTR::SOLID_GROUND | TILE_ATTR::GRABBING | TILE_ATTR::LADDER		; TILE_TOP_ROPE
	.byte TILE_ATTR::SOLID_WALL | TILE_ATTR::SLOPE	                            ; TILE_SLIDE_LEFT
	.byte TILE_ATTR::SOLID_WALL_LEFT | TILE_ATTR::SLOPE	                            ; TILE_SLIDE_RIGHT

TILE_WIDTH = 16
TILE_HEIGHT = 16

.scope Tiles

;animated_tiles_map
;   nb_animated_tiles
;   tile[0]
;        tick,
;        nb_frames
;        current_frame
;        @frame[0][0]
;        nb_tiles  
;        @addr_tiles_list[0]
;   tile[1]
;   ....
;   tile[nb_animated_tiles-1]
;   frame[t0][0]: duration, tile_index
;   frame[t0][1]
;   .....
;   frame[t0][ tile[0].nb_frames - 1 ]
;   frame[t1][0]: duration, tile_index
;   frame[t1][1]
;   .....
;   frame[t1][ tile[1].nb_frames - 1 ]
;   .....
;   frame[tnb_animated_tiles-1][0]
;   .....
;   frame[tnb_animated_tiles-1][ tile[nb_animated_tiles-1].nb_frames - 1 ]
;   addr_tiles_list[0] : tile[0].nb_tiles word
;   addr_tiles_list[1] : tile[1].nb_tiles word
;   addr_tiles_list[nb_animated_times -1] : tile[1].nb_tiles word

.struct ANIMATED_TILES
    nb_animated_tiles   .byte

    .struct ANIMATED_TILE
        tick            .byte   ; number of 18ms frames until next animation
        nb_frames       .byte
        current_frame   .byte
        addr_frames  .addr   ; offset of the list of animation
        nb_tiles        .byte   ; numner of tiles on the tilemap
        addr_tiles_list      .addr   ; offset of the list of tiles on the tilemap
    .endstruct
.endstruct

.struct FRAME
    duration    .byte
    tile_index  .byte
.endstruct

animated_tiles_map = HIMEM + $400
animated_tiles = HIMEM + $400 + 1

fsanimated_tiles: .literal "tilesani.bin"
fsanimated_tiles_end:

;-----------------------------------------
; load static tiles
;
load_static:
	VLOAD_FILE fstile, (fstileend-fstile), ::VRAM_tiles
	VTILEBASE 0, ::VRAM_tiles
	VTILEBASE 1, ::VRAM_tiles
	VTILEMODE 0,VERA_TILE_16x16 
	VTILEMODE 1,VERA_TILE_16x16 
    rts

;-----------------------------------------
; load and fix the animated tiles data
;
load_anim:
	lda #0
	sta $00
	LOAD_FILE fsanimated_tiles, (fsanimated_tiles_end-fsanimated_tiles), animated_tiles_map

    ; convert offsets in the data structure to memory addr
    ldy animated_tiles_map + ANIMATED_TILES::nb_animated_tiles
    ldx #0

@next_tile:
    clc
    lda animated_tiles + ANIMATED_TILES::ANIMATED_TILE::addr_frames, x
    adc #<animated_tiles_map
    sta animated_tiles + ANIMATED_TILES::ANIMATED_TILE::addr_frames, x
    lda animated_tiles + ANIMATED_TILES::ANIMATED_TILE::addr_frames + 1, x
    adc #>animated_tiles_map
    sta animated_tiles + ANIMATED_TILES::ANIMATED_TILE::addr_frames + 1, x

    clc
    lda animated_tiles + ANIMATED_TILES::ANIMATED_TILE::addr_tiles_list, x
    adc #<animated_tiles_map
    sta animated_tiles + ANIMATED_TILES::ANIMATED_TILE::addr_tiles_list, x
    lda animated_tiles + ANIMATED_TILES::ANIMATED_TILE::addr_tiles_list + 1, x
    adc #>animated_tiles_map
    sta animated_tiles + ANIMATED_TILES::ANIMATED_TILE::addr_tiles_list + 1, x

    dey
    beq @convert_tileslist_addr

    txa
    clc
    adc #.sizeof(ANIMATED_TILES::ANIMATED_TILE)
    tax
    bra @next_tile

@convert_tileslist_addr:
    ; convert tilemap offset into vera offset
    ; convert offsets in the data structure to memory addr
    ldy animated_tiles_map + ANIMATED_TILES::nb_animated_tiles
    ldx #0
@next_tile1:
    ; setup the listf of memory offset in vera memory
    lda animated_tiles + ANIMATED_TILES::ANIMATED_TILE::addr_tiles_list, x
    sta r0L
    lda animated_tiles + ANIMATED_TILES::ANIMATED_TILE::addr_tiles_list + 1, x
    sta r0H

    phy
    phx
    lda animated_tiles + ANIMATED_TILES::ANIMATED_TILE::nb_tiles, x
    tax
    ldy #00

@loop_tiles:
    clc
    lda (r0),y
    adc #<VRAM_layer1_map
    sta (r0),y
    iny

    lda (r0),y
    adc #>VRAM_layer1_map
    sta (r0),y
    iny

    dex
    bne @loop_tiles
    plx
    ply

    dey
    beq @init

    txa
    clc
    adc #.sizeof(ANIMATED_TILES::ANIMATED_TILE)
    tax
    bra @next_tile1

@init:
    ; init the timers
    ldy animated_tiles_map + ANIMATED_TILES::nb_animated_tiles
    ldx #0

@next_tile2:
    ; setup the list of frames
    lda animated_tiles + ANIMATED_TILES::ANIMATED_TILE::addr_frames, x
    sta r0L
    lda animated_tiles + ANIMATED_TILES::ANIMATED_TILE::addr_frames + 1, x
    sta r0H

    ; save new frame duration in the timer
    lda (r0)
    sta animated_tiles + ANIMATED_TILES::ANIMATED_TILE::tick, x

    dey
    beq @return

    txa
    clc
    adc #.sizeof(ANIMATED_TILES::ANIMATED_TILE)
    tax
    bra @next_tile2

@return:
    rts

;-----------------------------------------
; parse the animated tiles to update
;
update:
    ldy animated_tiles_map + ANIMATED_TILES::nb_animated_tiles
    ldx #0

@next_tile:
    dec animated_tiles + ANIMATED_TILES::ANIMATED_TILE::tick, x
    bne :+
    jsr next_frame
:
    dey
    beq @return

    txa
    clc
    adc #.sizeof(ANIMATED_TILES::ANIMATED_TILE)
    tax
    bra @next_tile

@return:
    rts

;-----------------------------------------
; move to the next frame of an animated tile
; update tiles on the tilemap
; input X : offset of the anim_tile structure 
;
next_frame:
    lda animated_tiles + ANIMATED_TILES::ANIMATED_TILE::current_frame, x
    inc
    cmp animated_tiles + ANIMATED_TILES::ANIMATED_TILE::nb_frames, x
    bne :+
    lda #00         ; roll back to 0
:
    sta animated_tiles + ANIMATED_TILES::ANIMATED_TILE::current_frame, x
    phx
    phy

    asl         ; the are 2 bytes per frame, so multiply the index by 2
    tay         ; Y = current animation frame

    ; setup the list of frames
    lda animated_tiles + ANIMATED_TILES::ANIMATED_TILE::addr_frames, x
    sta r0L
    lda animated_tiles + ANIMATED_TILES::ANIMATED_TILE::addr_frames + 1, x
    sta r0H

    lda (r0), y         ; save new frame duration in the timer
    sta animated_tiles + ANIMATED_TILES::ANIMATED_TILE::tick, x
    iny
    lda (r0), y         
    sta $30                 ; X = index of the new tile to store in VERA memory

    ; setup the listf of memory offset in vera memory
    lda animated_tiles + ANIMATED_TILES::ANIMATED_TILE::addr_tiles_list, x
    sta r0L
    lda animated_tiles + ANIMATED_TILES::ANIMATED_TILE::addr_tiles_list + 1, x
    sta r0H

    ; push all tiles in vera memory
    lda animated_tiles + ANIMATED_TILES::ANIMATED_TILE::nb_tiles, x
    asl         ; number of tiles in the list * 2 (these are addr)
    dec         ; start at the end
    tay

    ldx $30

@next_tile_index:
    ; set the vera memory (as we start from the end of the list, vera gigh is first)

	lda #0
	sta veractl
  	lda #(^VRAM_layer1_map + 2)
	sta verahi
    lda (r0), y
	sta veramid	                ; vera = $1fc00 + sprite index (X) * 8
    dey
    lda (r0), y
	sta veralo
    dey
    stx veradat

    bpl @next_tile_index

    ply
    plx
    rts
.endscope