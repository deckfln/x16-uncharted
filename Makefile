entity = src/entity/physic.asm src/entity/slide.asm src/entity/walk.asm
player = src/player/climb.asm src/player/ladder.asm src/player/swim.asm src/player\walk.asm
src = src\main.asm src\player.asm src\sprites.asm src\layers.asm src\objects.asm src/joystick.asm src/slopes.asm \
		src/utils/bresenhams.asm \
		src\tiles.asm src\tilemap.asm src\entities.asm src\tilemap.inc src\sprite.inc \
		$(entity) $(player)
		
bin\test.prg: $(src)
	cd src && ..\..\bin\ca65 --debug-info -t cx16 main.asm -o main.o -l main.lst
	cd src && ..\..\bin\cl65 -t cx16 -Ln ../bin/main.sym -o ../bin/test.prg main.o -C ../cx16-aligned.cfg --asm-define DEBUG -u __EXEHDR__ -Wl --dbgfile,../bin/test.dbg
	
src\sprite.inc: assets\player.png
	cd assets && python ..\png2vera_sprite.py player.png ..\sprite.inc
	
src\tilemap.inc: assets\level.tmx assets\background.tmx assets\tileset16x16.tsx assets\tileset.png
	python png2vera.py
	
debug1: bin\test.prg
	cd bin && ..\..\box16.exe -prg test.prg 

debug: bin\test.prg
	cd bin && ..\..\x16emu.exe -prg test.prg -debug -scale 2 -joy1

mydebug: bin\test.prg
	cd bin && ..\..\x16-emulator\x64\Release\x16-emulator.exe -rom ../../rom.bin -remote-debugger -fsroot ../../x16-uncharted/bin -prg test.prg -debug -scale 2 -joy1
