src = src\main.asm src\player.asm src\sprites.asm src\layers.asm src\objects.asm \
		src\tiles.asm src\tilemap.asm src\entities.asm src\tilemap.inc src\sprite.inc \
		src/player/climb.asm src/player/ladder.asm src/player/swim.asm src/joystick.asm \
		src/utils/bresenhams.asm src/slopes.asm

bin\test.prg: $(src)
	cd src && ..\..\bin\ca65 --debug-info -t cx16 main.asm -o main.o -l main.lst
	cd src && ..\..\bin\cl65 -t cx16 -Ln ../bin/main.sym -o ../bin/test.prg main.o -C ../cx16-aligned.cfg --asm-define DEBUG -u __EXEHDR__
	
src\sprite.inc: assets\player.png
	cd assets && python ..\png2vera_sprite.py player.png ..\sprite.inc
	
src\tilemap.inc: assets\level.tmx assets\background.tmx assets\tileset16x16.tsx assets\tileset.png
	python png2vera.py
	
debug1: bin\test.prg
	cd bin && ..\..\box16.exe -prg test.prg 

debug: bin\test.prg
	cd bin && ..\..\x16emu.exe -prg test.prg -debug -scale 2 -joy1

mydebug: bin\test.prg
	cd bin && D:\dev\X16\box16\build\vs2022\out\x64\Debug\box16.exe -prg test.prg -lst ..\src\main.lst
