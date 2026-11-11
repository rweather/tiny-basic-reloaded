Tiny BASIC Reloaded
===================

## History

[Tiny BASIC](https://en.wikipedia.org/wiki/Tiny_BASIC) was invented in
1975 as a reaction to Bill Gates' letter complaining about early
microcomputer enthusiasts pirating Microsoft's implementation of Altair BASIC.
At the time, the microcomputer community was all about experimentation and
sharing.  Gates' letter and charging for software in general was seen
as an afront to the community spirit.  Which it was!

There is no single implementation of Tiny BASIC from the era.  And that's
kind of the point.  Tiny BASIC is a specification for a minimal version of
BASIC that can be easily implemented on the limited microcomputers of the era.
And then extended however the user wanted.

The original specification was in an issue of the People's Computer
Company (PCC) newsletter, which over time evolved into Doctor Dobb's Journal.

Interestingly, it is an interpreter on top of an interpreter!  Tiny BASIC
itself is written in an intermediate bytecode language called IL and the
full listing of the original IL is in the first PCC newsletter.  The hobbyist
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

Homebrew computers, built to similar designs as those in the 1970's,
can also present issues.  If you are building your computer around an
odd CPU or making a CPU from scratch in TTL logic or an FPGA,
then your language options are limited without a lot of software work.

A BASIC implementation that is very easy to port to odd architectures?  Useful.

And ... I like writing compilers and interpreters.  So why not?

## Approach

My implementation uses the original IL bytecode idea to write the core
of the BASIC interpreter once.  And then automated machine translation
is used to convert the bytecode into assembly code for the target
architecture.  The bytecode is not interpreted; it is compiled.

This approach produces more efficient code than interpreting IL bytecode
at runtime, while reducing the implementation burden on new targets.
To port to a target, the user need only supply I/O, memory management,
a math library, and the automated translator.

This implementation also goes beyond "Tiny" with features from more
featureful versions of BASIC.  New IL bytecode instructions are added to
provide the extra functionality.

## License

Distributed under the terms of the MIT license.

## Contact

For more information on this code, to report bugs, or to suggest
improvements, please contact the author Rhys Weatherley via
[email](mailto:rhys.weatherley@gmail.com).
