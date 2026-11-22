
This directory contains the MOS6502A version of Tiny BASIC Reloaded.
The core code is in "tb-core.s".  The IL is converted into "tb-bytecode.s".
Those are the two files you need to make it work on your 6502-based system.

Some configuration is required to set the location of BASIC in ROM and
the location of the BASIC program area in RAM.  System routines must be
provided for character input and output and other system things.

There is a comment at the top of "tb-core.s" that describes what you
need to provide.  The specific target ports "target-emul.s" and
"target-eater.s" can be used as an example of how to configure
Tiny BASIC Reloaded.

Tiny BASIC Reloaded uses the zero page between $40 and $9F.  You will
need to edit "tb-core.s" if you have to relocate it away from other
things on your system.

Memory requirements:

* 7k of ROM for the code that results from "tb-core.s" and "tb-bytecode.s".
* 96 bytes of zero page RAM between $40 and $9F.
* 256 bytes of RAM for the keyboard input buffer, KEYBUF.
* Contiguous RAM between BASIC\_MEM and BASIC\_MEM\_END for control structures,
the BASIC program, and array storage.  Recommend at least 4k, but supply as
much contiguous RAM as you can scrape up.

This code in this directory is designed to be assembled with "vasm".
The "vasm6502\_oldstyle" binary is assumed to be on your PATH.
Edit the Makefile if the binary is somewhere else, or you want to use a
different assembler.
