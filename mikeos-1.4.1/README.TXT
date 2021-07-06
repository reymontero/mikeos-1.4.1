===================================================================
MikeOS -- Open source 16-bit operating system for x86 PCs
Copyright (C) 2006 - 2008 MikeOS Developers -- see LICENSE.TXT
===================================================================


NOTE: Please read the full documentation: doc/handbook.html


MikeOS is a 16-bit real mode operating system for x86-compatible PCs, 
written entirely in assembly language, which boots from a floppy disk or 
CD-ROM. It features a text-based dialog-driven user interface, a 
command-line, support for FAT12 (MS-DOS-like) floppy disks and sound via 
the PC speaker. It can load external programs and has over 40 system 
calls. Additionally, basic DOS .COM program support is included.

We do not plan to turn MikeOS into a general-purpose operating system 
like Linux; it is designed as a learning tool, to demonstrate how simple 
OSes work. You can use it as the basis of your own OS project, or to 
learn about x86 assembly language. The complete documentation for 
MikeOS, including instructions on running it, building it and writing 
your own operating system, can be found in handbook.html in the doc/ 
directory.

Quick getting-started guide: MikeOS can run from a floppy disk or 
CD-ROM, either on an emulator or a real PC. See the disk_images/ 
directory for files that you can write to the approprate media. You can 
run the ISO image in an emulator such as QEMU, VMware or VirtualBox; for 
a real PC, burn it to a CD-R and boot from it.

When MikeOS has booted, you can choose between a dialog-driven program 
menu or a command-line interface. Example programs include a music 
keyboard, image viewer, machine code monitor and freeware DOS game
(STAKAN.BIN).

See doc/LICENSE.TXT for redistribution/modification rights, and 
doc/CREDITS.TXT for a list of people involved.

Have fun!

 -- Mike Saunders (okachi@gmail.com)


===================================================================

