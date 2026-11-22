Tiny BASIC Reloaded
===================

## History

[Tiny BASIC](https://en.wikipedia.org/wiki/Tiny_BASIC) was created by
contributors to the "People's Computer Company" (PCC) newletter,
which over time evolved into Doctor Dobb's Journal.  Tiny BASIC Extended
followed, which added more features from standard BASIC like arrays
and FOR..NXT loops (yes, "NXT" not "NEXT").

There is no single implementation of Tiny BASIC from the era.  And that's
kind of the point.  Tiny BASIC is a specification for a minimal version of
BASIC that can be easily implemented on the limited microcomputers of the era.
And then extended however the user wanted.

Interestingly, it is an interpreter on top of an interpreter!  Tiny BASIC
itself is written in an intermediate bytecode language called IL and the
full listing of the original IL is in an early PCC newsletter.  The hobbyist
need only write an IL interpreter for their machine and they have a BASIC.
And due to the compact nature of IL, it was tiny!

For more historical information, see
[Volume 1 of Doctor Dobb's Journal](https://archive.org/details/dr_dobbs_journal_vol_01).

## Why now?

So why make yet another BASIC and a Tiny one at that?  Microsoft BASIC for
the Z-80 and 6502 are now open source, so porting the "real deal" is
possible.  Other implementations also exist, like
[EhBASIC](http://retro.hansotten.nl/6502-sbc/lee-davison-web-site/enhanced-6502-basic/).

Retro and homebrew computing is why.

There is a resurgence of interest in restoring older machines, many of which
are boring "business computers" from the era and don't come with any good
programming language for writing examples and games once restored.
You might find an old Fortran or ALGOL tape if you're lucky, but usually
you will be stuck with assembly code.  Some of the machines are so old that
memory constraints are an issue.

Homebrew computers, built to similar designs as those in the 1970's
and 1980's, can also present issues.  If you are building your computer
around an odd CPU or making a CPU from scratch in TTL logic or an FPGA,
then your language options are limited without a lot of software work.

A BASIC implementation that is very easy to port to odd architectures?  Useful.

And ... I like writing compilers and interpreters.  So why not?

## Approach

My implementation uses the original IL bytecode idea to write the core
of the BASIC interpreter once.  And then automated machine translation
is used to convert the bytecode into assembly code for the target
architecture.  The IL bytecode may be interpreted on the target, or it
may be directly compiled to the target depending on space constraints.

This approach reduces the implementation burden of BASIC on new targets.
To port to a target, the user need only supply I/O, memory management,
opcode helper functions, and the automated translator.  Still a lot,
but the hard part of the parser and expression evaluator is done for you.

An implementation in C of the bytecode interpreter is provided under
[src/reference](src/reference) to test changes to the language, and to
provide a reference for the expected behaviour on real targets.
The [IL Bytecode Reference](doc/bytecode.md) also describes the
expected behaviour of each bytecode.

## Features

Tiny BASIC Reloaded borrows a number of features from other BASIC's to
provide a reasonable set of capabilities in an integer-only BASIC.
This implementation goes well beyond "Tiny" with features from more
powerful versions of BASIC.

Inspiration was taken from Tiny BASIC, Tiny BASIC Extended,
AppleSoft BASIC, Apple II Integer BASIC, and TRS-80 Level II BASIC.
The syntax mostly follows AppleSoft except where AppleSoft was
missing something like INKEY.

* 26 16-bit integer variables A to Z.
* 26 arrays of 16-bit integers which can be dimensioned with 1 or 2 dimensions.
* Commands: CALL, CLR, DIM, END, FOR...NEXT, GOSUB...RETURN, GOTO,
IF...THEN, IF...GOTO, INPUT, LET, LIST, LOAD, POKE, POP, PRINT,
REM, RUN, SAVE, SIZE, SPC.
* Operators: +, -, &#42;, /, MOD, ABS, AND, OR, NOT, BAND, BOR, BNOT, XOR,
SHL, SHR, LSL, =, &lt;&gt;, &lt;, &gt;, &lt;=, &gt;=.
* Built-in functions: ABS, PEEK, RND.
* Some limited string support with ASC and CHR$.
* Some limited fixed-point support with +, -, and FPMUL in place of
true floating-point.
* Non-blocking character input with INKEY to assist with writing
interactive programs like video games.

See the [Language Reference Manual](doc/language-reference.md) for
more information.

## Targets

The following targets are currently supported:

* C reference implementation
* MOS 6502A (need the "A" for the fixed "ROR" instruction)

More to come!

## Documentation

* [Language Reference Manual](doc/language-reference.md)
* [IL Bytecode Reference](doc/bytecode.md)
* [Memory Management](doc/memory-management.md)

## Future work

* Lots more targets.
* Commands like CLS, MOVE, COLOR, etc for richer text mode operations.
* String handling, possibly based on how Apple II Integer BASIC does strings.
* Alternative language front-ends; e.g. for [INTERPROGRAM](https://github.com/rweather/interprogram).

## License

Distributed under the terms of the MIT license.

## Contact

For more information on this code, to report bugs, or to suggest
improvements, please contact the author Rhys Weatherley via
[email](mailto:rhys.weatherley@gmail.com).
