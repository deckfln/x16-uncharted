; License: Public Domain
.ifndef VERA_INC
VERA_INC = 1

verareg =$9f20

veralo  		= verareg+$0
veramid 		= verareg+$1
verahi  		= verareg+$2
veradat 		= verareg+$3
veradat2		= verareg+$4
veractl 		= verareg+$5
veraien 		= verareg+$6
veraisr 		= verareg+$7
verairqlo 		= verareg+$8

; DCSEl = 0
veradcvideo		= verareg+$9

VERA_VGA		= %00000001
VERA_LAYER0		= %00010000
VERA_LAYER1		= %00100000
VERA_SPRITE		= %01000000

veradchscale	= verareg+$a
veradcvscale	= verareg+$b
veradcborder	= verareg+$c

; DCSEl = 1
veradchstart	= verareg+$9
veradchstop		= verareg+$a
veradcvstart	= verareg+$b
veradcvstop		= verareg+$c

; L0
veral0config	= verareg+$d
veral0mapbase	= verareg+$e
veral0tilebase	= verareg+$f
VERA_L0_hscrolllo	= verareg+$10
VERA_L0_hscrollhi	= verareg+$11
veral0vscrolllo	= verareg+$12
veral0vscrollhi	= verareg+$13

; L1
veral1config	= verareg+$14
veral1mapbase	= verareg+$15
veral1tilebase	= verareg+$16
VERA_L1_hscrolllo	= verareg+$17
VERA_L1_hscrollhi	= verareg+$18
veral1vscrolllo	= verareg+$19
veral1vscrollhi	= verareg+$1a

VERA_CONFIG_CLEAR_TILES=%00001111
VERA_CONFIG_32x32 = 	%00000000
VERA_CONFIG_32x64 = 	%00010000
VERA_CONFIG_32x128 = 	%00100000
VERA_CONFIG_32x256 = 	%00110000
VERA_CONFIG_64x32 = 	%01000000
VERA_CONFIG_128x32 = 	%10000000
VERA_CONFIG_256x32 = 	%11000000
VERA_CONFIG_64x64 = 	%01010000
VERA_CONFIG_64x128 = 	%01100000
VERA_CONFIG_64x256 = 	%01110000
VERA_CONFIG_128x64 = 	%10010000
VERA_CONFIG_128x128 = 	%10100000
VERA_CONFIG_128x256 = 	%10110000
VERA_CONFIG_256x64 = 	%11010000
VERA_CONFIG_256x128 = 	%11100000
VERA_CONFIG_256x256 = 	%11110000

VERA_CONFIG_CLEAR_DEPTH=%00001111
VERA_CONFIG_1BPP	=	%00000000
VERA_CONFIG_2BPP	=	%00000001
VERA_CONFIG_4BPP	=	%00000010
VERA_CONFIG_8BPP	=	%00000011

VERA_CLEAR_TILE_SIZE= %11111100
VERA_TILE_8x8 		= %00000000
VERA_TILE_8x16 		= %00000010
VERA_TILE_16x8 		= %00000001
VERA_TILE_16x16 	= %00000011

VERA_TILEBASE_CLEAR_ADR = %00000011

; audio
veraaudioctl	= verareg+$1b
veraaudiorate	= verareg+$1c
veraaudiodata	= verareg+$1d
veraspidata		= verareg+$1e
veraspictl		= verareg+$1f

vram_sprd  = $1fc00

AUTO_INC_0 		= $000000
AUTO_INC_1 		= $100000
AUTO_INC_2 		= $200000
AUTO_INC_4 		= $300000
AUTO_INC_8 		= $400000
AUTO_INC_16		= $500000
AUTO_INC_32		= $600000
AUTO_INC_64		= $700000
AUTO_INC_128	= $800000
AUTO_INC_256	= $900000
AUTO_INC_512	= $A00000
AUTO_INC_40		= $B00000
AUTO_INC_80		= $C00000
AUTO_INC_160	= $C00000
AUTO_INC_320	= $E00000
AUTO_INC_640	= $F00000

SPRITE_SIZE_8	= $0
SPRITE_SIZE_16	= $1
SPRITE_SIZE_32	= $2
SPRITE_SIZE_64	= $3

SPRITE_ZDEPTH_DISABLED = %00000000
SPRITE_ZDEPTH_BGto0 = %00000100
SPRITE_ZDEPTH_0to1 = %00001000
SPRITE_ZDEPTH_TOP = %00001100

SPRITE_FLIP_CLEAR = %11111100
SPRITE_FLIP_NONE = %00000000
SPRITE_FLIP_H = %00000001
SPRITE_FLIP_V = %00000010

veral0mode = %00010000
VERA_VSYNC_BIT         = $01


.macro vset addr
	lda #0
	sta veractl
	lda #<(addr >> 16) | $10
	sta verahi
	lda #<(addr >> 8)
	sta veramid
	lda #<(addr)
	sta veralo
.endmacro

.macro vset2 addr
	lda #1
	sta veractl
	lda #<(addr >> 16) | $10
	sta verahi
	lda #<(addr >> 8)
	sta veramid
	lda #<(addr)
	sta veralo
.endmacro

.macro vstore addr
	pha
	vset addr
	pla
	sta veradat
.endmacro

.macro vstore2 addr
	pha
	vset addr
	pla
	sta veradat2
.endmacro

.macro vload addr
	vset addr
	lda veradat
.endmacro

.macro vload2 addr
	vset addr
	lda veradat2
.endmacro

.macro sprset offset
	lda #<(vram_sprd >> 16) | $10
	sta verahi
	txa
	lsr
	lsr
	lsr
	lsr
	lsr
	clc
	adc #<((vram_sprd + offset) >> 8)
	sta veramid
	txa
	asl
	asl
	asl
	clc
	adc #<(vram_sprd + offset)
	sta veralo
.endmacro

.macro sprload offset
	sprset offset
	lda veradat
.endmacro

.macro sprload2 offset
	sprset offset
	lda veradat2
.endmacro

.macro sprstore offset
	pha
	sprset offset
	pla
	sta veradat
.endmacro

.macro sprstore2 offset
	pha
	sprset offset
	pla
	sta veradat2
.endmacro

.macro video_init
	lda #0
	sta veractl ; set ADDR1 active
	sta veramid
	lda #$1F    ; $F0000 increment 1
	sta verahi
	lda #$00
	sta veralo
	lda #1
	sta veradat ; VGA output
.endmacro

.endif
