test.prg: main.asm tilemap.inc sprite.inc
	..\bin\cl65 -t cx16 -o bin/test.prg -l main.lst main.asm
	
sprite.inc: player.png
	python png2vera_sprite.py player.png sprite.inc
	
tilemap.inc: level.tmx background.tmx tileset16x16.tsx tileset.png
	python png2vera.py
	
debug: test.prg
	cd bin && ..\..\x16emu.exe -prg test.prg -debug -scale 2 -joy1