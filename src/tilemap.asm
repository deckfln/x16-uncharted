;-----------------------------------------------------------------------------
;/////////////////////////////////////////////////////////////////////////////
; START Tilemap code
;\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------------------------------

.scope Tilemap

COLLISION_MAP = HIMEM

;************************************************
; load the layers and the collision map
;
load:
	; load tilemap into layer 0
	VCONFIG_TILES 0,VERA_CONFIG_32x32
	VCONFIG_DEPTH 0,VERA_CONFIG_8BPP
	VMAPBASE 0, VRAM_layer0_map
	VLOAD_FILE fsbackground, (fsbackground_end-fsbackground), VRAM_layer0_map
	
	; load tilemap into layer 1
	VCONFIG_TILES 1,VERA_CONFIG_32x32
	VCONFIG_DEPTH 1,VERA_CONFIG_8BPP
	VMAPBASE 1, VRAM_layer1_map
	VLOAD_FILE fslevel, (fslevel_end-fslevel), VRAM_layer1_map

	; load collisionmap into ram 
	lda #0
	sta $00
	LOAD_FILE fscollision, (fscollision_end-fscollision), COLLISION_MAP


    rts

;************************************************
; convert (x,y) position into a collision memory address
;	input: r0  = X
;            r1 = Y
;	output : r0
;
get_collision_addr:
	lda r0L
	and #%11110000
	asl
	rol r0H	
	sta r0L 					; r0 = first tile of the tilemap in the row
								; spriteY / 16 (convert to tile Y) * 32 (number of tiles per row in the tile map)

    lda r1H	
	lsr			
	ror r1L
	lsr
	ror r1L
	lsr
	ror r1L
	lsr
	ror r1L	
	sta r1H 					; r1 = tile X in the row 
								; sprite X /16 (convert to tile X)
	
	clc
	lda r0L
	adc r1L
	sta r0L
	lda r0H
	adc r1H
	sta r0H						; r0 = tile position in the tilemap
	
	clc
	lda r0L
	adc #<COLLISION_MAP
	sta r0L						; r0 = tile position in the memory tilemap
	lda r0H
	adc #>COLLISION_MAP
	sta r0H						; r0 = tile position in the memory tilemap
	rts

.endscope