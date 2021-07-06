@echo off
echo Build script for DOS users with NASM for Windows
echo.
cd source
echo Assembling bootloader...
nasmw -f bin -o bootload.bin bootload.asm
echo Assembling MikeOS kernel...
nasmw -f bin -o mikekern.bin os_main.asm
echo Assembling programs...
cd ..\programs
 for %%i in (*.asm) do nasmw -fbin %%i
 for %%i in (*.bin) do del %%i
 for %%i in (*.) do ren %%i %%i.bin
cd ..
echo Done!
 
