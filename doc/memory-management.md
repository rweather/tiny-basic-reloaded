Memory management
=================

This file describes how memory manangement is done for this version of
Tiny BASIC, to aid in porting to other platforms.

The description below assumes an 8-bit or 16-bit system with 16-bit integers
and 16-bit pointers.  Some of the sizes may be different for other systems.

## Memory regions

The engine needs the following memory regions:

* Control stack (CTLSTK)
* Subroutine stack (SUBSTK)
* Arithmetic expression stack (AESTK)
* Program and variable storage area
* General-purpose variables for system state

## Control stack (CTLSTK)

The control stack is usually the same as the CPU's native subroutine stack.
It stores return addresses for CALL instructions in the IL bytecode.

The bytecode "CHKSTK" checks the size of the stack during expression
evaluation to detect deep recursion.  If the CPU's stack is getting low,
then report the "FORMULA TOO COMPLEX" error and abort program execution.

Expression evaulation can be up to 10 subroutine levels deep before the
next level of recursion.  If "CHKSTK" detects that there is less than
that available, with some margin for interrupt handlers, then abort.

## Subroutine stack (SUBSTK)

The subroutine stack is used to store return addresses for GOSUB statements
in the BASIC program, and to store information about FOR ... NEXT blocks.
The elements on the stack have variable size.

When a GOSUB is encountered, push the address of the next statement
after the GOSUB onto the stack and the size of the frame onto the
subroutine stack:

    +--------------------+
    |      Size = n      |
    +--------------------+
    |   Return Address   |
    +--------------------+
    |     Line Number    |
    +--------------------+
    |          :         |
    |          :         |

When a FOR statement is encountered, push the address of the statement
just after the FOR, the final "TO" value, the "STEP" value, a pointer to
the loop variable, and the size of the frame on the subroutine stack:

    +--------------------+
    |      Size = n      |
    +--------------------+
    |  Loop Top Address  |
    +--------------------+
    |     Line Number    |
    +--------------------+
    |  Variable Pointer  |
    +--------------------+
    |     STEP Value     |
    +--------------------+
    |      TO Value      |
    +--------------------+
    |          :         |
    |          :         |

The Size field determines the type of frame, or helps to skip
unknown frame types.

When RETURN is encountered, pop frames until a RETURN frame is seen.
FOR frames are discarded.  Then set the current BASIC execution
pointer to the "Return Address" and pop the frame.  If no RETURN frames
are found, report "RETURN WITHOUT GOSUB" and stop.

When "NEXT X" is encountered, pop frames until a FOR frame with the
variable pointer for X is seen.  If X is not supplied, then use the
first FOR frame that is found.  If a RETURN frame is seen or the
subroutine stack is exhausted, then report the "NEXT WITHOUT FOR"
error and stop.

If the STEP value is positive, then check if the value in the
variable is greater than or equal to the TO value.  If the STEP value
is negative, then check if the value in the variable is less than or
equal to the TO value.  If the condition holds, pop the FOR frame
from the subroutine stack and continue with the next statement
after the NEXT.

If the variable has not yet reached or exceeded the TO value,
add the STEP value to the variable and continue execution from
"Loop Top Address".

The subroutine stack management routines should report "TOO MANY GOSUBS"
or "TOO MANY FORS" if the subroutine stack is full when pushing a new frame.

## Arithmetic expression stack (AESTK)

The arithmetic expression stack is a stack of integer values that keeps
track of in-progress values for expression evaluation.

If AESTK overflows due to a push operation, report the
"FORMULA TOO COMPLEX" error and abort program execution.

Bytecode instructions that pop from the stack; e.g. ADD, can safely
do so without checking for stack underflow.  The structure of the
code ensures that all needed values are on AESTK before the instruction
that needs to pop.

## Program storage area

The program storage area occupies most of memory.  It must be a
contiguous region of RAM.  Each line of BASIC code is stored as follows:

    +--------------------+
    |  Line Number Low   |
    +--------------------+
    |  Line Number High  |
    +--------------------+
    |      Size = N      |
    +--------------------+
    |          :         |
    |   N Bytes of Text  |
    |          :         |
    +--------------------+
    |   NUL Terminator   |
    +--------------------+

Line numbers may be between 1 and 31999.  N must be 252 or less.

After the last line is four zero bytes to indicate the end of the program.

At least 208 bytes of space must be available after the end of the
program to store the plain variables and array variable headers.

## Variable storage area

The variable storage area is placed just after the end of the program.
Any modification to the program, such as inserting or deleting lines,
will cause an implicit "CLEAR" operation to clear all variables.

The plain variables A-Z are stored just after the end of the program.
Each variable occupies 2 bytes for the 16-bit integer value of the variable.

After the plain variables is 26 "array headers" of 6 bytes each for the
array variables A() to Z():

    +--------------------+
    |  Dimension 1 Low   |
    +--------------------+
    |  Dimension 1 High  |
    +--------------------+
    |  Dimension 2 Low   |
    +--------------------+
    |  Dimension 2 High  |
    +--------------------+
    |    Pointer Low     |
    +--------------------+
    |    Pointer High    |
    +--------------------+

For unused array variables, "Dimension 1" is set to zero.  For 1D arrays,
"Dimension 2" is set to zero.  For 2D arrays, both "Dimension 1" and
"Dimension 2" must be non-zero.

Note that the dimension values are the upper bound for the dimension,
with the lower bound being implicitly zero.  A 1D array with dimension 10
implies that there are 11 elements in the array.  A 2D array with
dimensions 2 and 3 implies that there are (2 + 1) * (3 + 1) = 12 elements.

The pointer field refers to the region of the program storage area that
contains the elements of the array.  Array memory is allocated starting
from just after the array headers and continuing to the end of the
program storage area.
