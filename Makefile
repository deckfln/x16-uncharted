src = src\main.asm src\player.asm src\sprites.asm src\layers.asm src\objects.asm \
		src\tiles.asm src\tilemap.asm src\entities.asm src\tilemap.inc src\sprite.inc 

bin\test.prg: $(src)
	cd src && ..\..\bin\cl65 -t cx16 -o ../bin/test.prg -l main.lst main.asm -D DEBUG
	
src\sprite.inc: assets\player.png
	cd assets && python ..\png2vera_sprite.py player.png ..\sprite.inc
	
src\tilemap.inc: assets\level.tmx assets\background.tmx assets\tileset16x16.tsx assets\tileset.png
	python png2vera.py
	
debug1: bin\test.prg
	cd bin && ..\..\box16.exe -prg test.prg 

debug: bin\test.prg
	cd bin && ..\..\x16emu.exe -prg test.prg -debug -scale 2 -joy1
