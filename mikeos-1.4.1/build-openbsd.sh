#!/bin/sh

# This script assembles the MikeOS bootloader, kernel and programs
# with NASM, and then creates floppy and CD images (on OpenBSD)

# Only the root user can mount the floppy disk image as a virtual
# drive (loopback mounting), in order to copy across the files


echo "Experimental OpenBSD build script..."


if test "`whoami`" != "root" ; then
	echo "You must be logged in as root to build (for loopback mounting)"
	echo "Enter 'su' to switch to root"
	exit
fi


echo ">>> Assembling bootloader..."

nasm -f bin -o source/bootload.bin source/bootload.asm || exit


echo ">>> Assembling MikeOS kernel..."

cd source
nasm -f bin -o mikekern.bin os_main.asm || exit
cd ..


echo ">>> Assembling programs..."

cd programs

for i in *.asm
do
	nasm -f bin $i -o `basename $i .asm`.bin || exit
done

cd ..


echo ">>> Adding bootloader to floppy image..."

dd               conv=notrunc if=source/bootload.bin of=disk_images/mikeos.flp || exit


echo ">>> Copying MikeOS kernel and programs..."

rm -rf tmp-loop
vnconfig svnd3 disk_images/mikeos.flp || exit

mkdir tmp-loop && mount         -t msdos           /dev/svnd3c tmp-loop && cp source/mikekern.bin tmp-loop/

cp programs/*.bin tmp-loop

echo ">>> Unmounting loopback floppy..."

umount tmp-loop || exit

vnconfig -u svnd3 || exit
rm -rf tmp-loop


echo ">>> Creating CD-ROM ISO image..."

rm -f disk_images/mikeos.iso
mkisofs -quiet -V 'MIKEOS' -input-charset iso8859-1 -o disk_images/mikeos.iso -b mikeos.flp disk_images/ || exit

echo '>>> Done!'

