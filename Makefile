bin\test.prg: src\main.asm src\player.asm src\sprites.asm src\layers.asm src\tilemap.inc src\sprite.inc
	cd src && ..\..\bin\cl65 -t cx16 -o ../bin/test.prg -l main.lst main.asm -D DEBUG
	
sprite.inc: assets\player.png
	cd assets && python ..\png2vera_sprite.py player.png ..\sprite.inc
	
tilemap.inc: assets\level.tmx assets\background.tmx assets\tileset16x16.tsx assets\tileset.png
	cd assets && python ..\png2vera.py
	
debug: bin\test.prg
#	cd bin && ..\..\x16emu.exe -prg test.prg -debug -scale 2 -joy1
	cd bin && ..\..\box16.exe -prg test.prg 