/*
 * Copyright (C) 2026 Rhys Weatherley
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included
 * in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
 * OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */

#ifndef TB_H
#define TB_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Instructions for the original Tiny BASIC design */
#define TB_I_TST            0x00    /**< Test if a string */
#define TB_I_CALL           0x01    /**< Call an IL subroutine */
#define TB_I_JMP            0x02    /**< Jump to another IL program location */
#define TB_I_RTN            0x03    /**< Return from subroutine */
#define TB_I_DONE           0x04    /**< Done with line, check for CR */
#define TB_I_PRS            0x05    /**< Print string */
#define TB_I_PRN            0x06    /**< Print number */
#define TB_I_SPC            0x07    /**< Space across to the next print zone */
#define TB_I_NLINE          0x08    /**< Output CRLF */
#define TB_I_NXT            0x09    /**< Execute the next line */
#define TB_I_RNXT           0x0A    /**< Reset for "RUN" and execute next */
#define TB_I_XFER           0x0B    /**< Transfer to line number */
#define TB_I_SAV            0x0C    /**< Save return address on SUBSTK */
#define TB_I_RSTR           0x0D    /**< Restore return address from SUBSTK */
#define TB_I_CMPR           0x0E    /**< Perform a comparison */
#define TB_I_INNUM          0x0F    /**< Input a number */
#define TB_I_FIN            0x10    /**< Finish execution (END) */
#define TB_I_ERR            0x11    /**< Report a syntax error */
#define TB_I_ADD            0x12    /**< Add top two AESTK items */
#define TB_I_SUB            0x13    /**< Subtract top two AESTK items */
#define TB_I_NEG            0x14    /**< Negate top-most AESTK item */
#define TB_I_MUL            0x15    /**< Multiply top two AESTK items */
#define TB_I_DIV            0x16    /**< Divide top two AESTK items */
#define TB_I_LIT            0x17    /**< Push a literal onto AESTK */
#define TB_I_STORE          0x18    /**< Store to a variable */
#define TB_I_TSTV           0x19    /**< Test if a variable */
#define TB_I_TSTN           0x1A    /**< Test if a number */
#define TB_I_TSTL           0x1B    /**< Test if a line number */
#define TB_I_INSRT          0x1C    /**< Insert a line into the program */
#define TB_I_INIT           0x1D    /**< Re-initialize the program (NEW) */
#define TB_I_XINIT          0x1E    /**< Initialize for statement execution */
#define TB_I_GETLN          0x1F    /**< Get a line of input in direct mode */
#define TB_I_LST            0x20    /**< List the BASIC program */

/* Error codes from the original Tiny BASIC design */
#define TB_E_SYNTAX         1       /**< Syntax error */
#define TB_E_MISSING        2       /**< Missing line */
#define TB_E_INVLINE        3       /**< Invalid line number */
#define TB_E_GOSUB          4       /**< Too many GOSUBs */
#define TB_E_RETURN         5       /**< RETURN without GOSUB */
#define TB_E_EXPR           6       /**< Expression too complex */
#define TB_E_MEMORY         7       /**< Out of memory */
#define TB_E_DIVZERO        8       /**< Division by zero */

/* Other error codes */
#define TB_E_NONE           0       /**< No error */
#define TB_E_OVERFLOW       9       /**< Overflow error */
#define TB_E_DIRECT         10      /**< Illegal direct */
#define TB_E_IL             11      /**< IL error */
#define TB_E_NODATA         12      /**< Out of data on INPUT or READ */
#define TB_E_TYPE           13      /**< Type mismatch */

/* Value types */
#define TB_T_NUMBER         0       /**< Value is a number */
#define TB_T_STRING         1       /**< Value is a string */

/* Comparison codes for the CMPR instruction */
#define TB_CMP_EQ           0       /**< Compare for equal to */
#define TB_CMP_LT           1       /**< Compare for less than */
#define TB_CMP_LE           2       /**< Compare for less than or equal to */
#define TB_CMP_NE           3       /**< Compare for not equal to */
#define TB_CMP_GT           4       /**< Compare for greater than */
#define TB_CMP_GE           5       /**< Compare for greater than or equal to */

/**
 * @brief Information about the IL program to run.
 */
typedef struct
{
    const uint8_t *start;   /**< Cold start of the IL program */
    const uint8_t *direct;  /**< Points to the top-level control loop */
    const uint8_t *error;   /**< Points to the error entry point */
    const uint8_t *next;    /**< Points to the next statement code */

} tb_il_program_t;

/**
 * @brief Maximum size of the program storage area.
 */
#define TB_MAX_PROGRAM      32768

/**
 * @brief Maximum number of variables.
 */
#define TB_MAX_VARS         26

/**
 * @brief Maximum size of the control stack for IL subroutine return addresses.
 */
#define TB_MAX_CTLSTK       256

/**
 * @brief Maximum size of the arithmetic expression stack.
 */
#define TB_MAX_AESTK        256

/**
 * @brief Maximum size of the subroutine return stack for GOSUB/RETURN.
 */
#define TB_MAX_SUBSTK       256

/**
 * @brief Maximum size of the input line in direct mode.
 */
#define TB_MAX_LINE         256

/**
 * @brief Maximum line number that is allowed; minimum is 1.
 */
#define TB_MAX_LINE_NUMBER  31999

/**
 * @brief Value type for the interpreter.
 */
typedef int16_t tb_value_t;

/**
 * @brief Saved information on the subroutine stack.
 */
typedef struct
{
    uint8_t *cursor;        /**< Program position to return back to */
    uint16_t line_number;   /**< Line number to return back to */

} tb_substk_item_t;

/**
 * @brief State of the Tiny BASIC interpreter.
 */
typedef struct
{
    uint8_t program[TB_MAX_PROGRAM];    /**< Program storage */
    unsigned program_size;              /**< Current program size */
    tb_value_t vars[TB_MAX_VARS];       /**< Variables */
    const uint8_t *ctlstk[TB_MAX_CTLSTK]; /**< Control stack */
    unsigned ctlstk_size;               /**< Current size of CTLSTK */
    tb_value_t aestk[TB_MAX_AESTK];     /**< Arithmetic expression stack */
    unsigned aestk_size;                /**< Current size of AESTK */
    tb_substk_item_t substk[TB_MAX_SUBSTK]; /**< Subroutine return stack */
    unsigned substk_size;               /**< Current size of SUBSTK */
    const uint8_t *pc;                  /**< IL program counter */
    uint8_t *cursor;                    /**< Cursor into the BASIC program */
    uint8_t line[TB_MAX_LINE];          /**< Input line in direct mode */
    const tb_il_program_t *il;          /**< IL program information */
    uint16_t line_number;               /**< Number of the current line */
    uint8_t colon_mode;                 /**< ":" separator seen during a DONE */
    uint8_t do_break;                   /**< BREAK has been detected */
    uint8_t eof_seen;                   /**< EOF has been seen, exit BASIC */
    uint8_t *input_cursor;              /**< Cursor for INPUT mode */
    uint8_t *search_cursor;             /**< Cursor for searching for a line */
    uint16_t search_line;               /**< Line number during a search */

} tb_state_t;

/**
 * @brief Initializes the Tiny BASIC state for the first time.
 *
 * @param[out] state Tiny BASIC state.
 *
 * This function must be followed by a call to tb_set_il().
 */
void tb_init(tb_state_t *state);

/**
 * @brief Set the IL code to use for implement Tiny BASIC.
 *
 * @param[in,out] state Tiny BASIC state.
 * @param[in] il Points to the IL code to use.
 *
 * The object @a il must persist for the lifetime of the @a state object.
 */
void tb_set_il(tb_state_t *state, const tb_il_program_t *il);

/**
 * @brief Clears the entire Tiny BASIC state for the "NEW" command.
 *
 * @param[in,out] state Tiny BASIC state.
 */
void tb_new(tb_state_t *state);

/**
 * @brief Initializes the Tiny BASIC state in preparation to execute the
 * next statement.
 *
 * @param[in,out] state Tiny BASIC state.
 */
void tb_xinit(tb_state_t *state);

/**
 * @brief Report an error and reset the state of the engine.
 *
 * @param[in,out] state Tiny BASIC state.
 * @param[in] error Error code.
 */
void tb_error(tb_state_t *state, uint8_t error);

/**
 * @brief End the program and return to direct mode.
 *
 * @param[in,out] state Tiny BASIC state.
 */
void tb_end(tb_state_t *state);

/**
 * @brief Determine if the Tiny BASIC engine is currently in direct mode.
 *
 * @param[in,out] state Tiny BASIC state.
 *
 * @return Non-zero for direct mode, zero if the program is running.
 */
int tb_is_direct(tb_state_t *state);

/**
 * @brief Move onto the next line in the program or return to direct mode.
 *
 * @param[in,out] state Tiny BASIC state.
 */
void tb_next(tb_state_t *state);

/**
 * @brief Starts running the BASIC program in memory.
 *
 * @param[in,out] state Tiny BASIC state.
 */
void tb_run(tb_state_t *state);

/**
 * @brief Push a value on the AESTK.
 *
 * @param[in,out] state Tiny BASIC state.
 * @param[in] value The value to push.
 *
 * This will call tb_error() and redirect IL program flow on stack overflow.
 */
void tb_push(tb_state_t *state, tb_value_t value);

/**
 * @brief Pop a value from the AESTK.
 *
 * @param[in,out] state Tiny BASIC state.
 *
 * @return The value that was popped.
 *
 * Stack underflow is unlikely due to the structure of the IL code.
 * If it does occur, then a default numeric value of 0 will be returned.
 */
tb_value_t tb_pop(tb_state_t *state);

/**
 * @brief Push the current location in the BASIC program onto SUBSTK.
 *
 * @param[in,out] state Tiny BASIC state.
 *
 * This will call tb_error() and redirect IL program flow on stack overflow.
 */
void tb_push_sub(tb_state_t *state);

/**
 * @brief Pop the current location in the BASIC program from SUBSTK.
 *
 * @param[in,out] state Tiny BASIC state.
 *
 * This will call tb_error() and redirect IL program flow on stack underflow.
 */
void tb_pop_sub(tb_state_t *state);

/**
 * @brief Determine if a character is whitespace.
 *
 * @param[in] ch The character.
 *
 * @return Non-zero if @a ch is whitespace, zero if not.
 */
int tb_is_whitespace(uint8_t ch);

/**
 * @brief Skip whitespace in the current line.
 *
 * @param[in,out] state Tiny BASIC state.
 */
void tb_skip_whitespace(tb_state_t *state);

/**
 * @brief Done with the current statement.  Check for a colon or end of line.
 * If neither are present, then report a syntax error.
 *
 * @param[in,out] state Tiny BASIC state.
 */
void tb_done(tb_state_t *state);

/**
 * @brief Transfer control to a new line number.
 *
 * @param[in,out] state Tiny BASIC state.
 * @param[in] line_number The line number.
 */
void tb_goto(tb_state_t *state, tb_value_t line_number);

/**
 * @brief Insert the current line into the program, replacing any
 * existing line with the same number.
 *
 * @param[in,out] state Tiny BASIC state.
 *
 * It is assumed that the line number has already been recognised with
 * TSTL and that it is a legal line number value.
 */
void tb_insert(tb_state_t *state);

/**
 * @brief Execute a single IL instruction.
 *
 * @param[in,out] state Tiny BASIC state.
 */
void tb_exec_one(tb_state_t *state);

/**
 * @brief Call an IL subroutine at a specific location.
 *
 * @param[in,out] state Tiny BASIC state.
 * @param[in] new_pc The new program counter for the subroutine.
 */
void tb_call(tb_state_t *state, const uint8_t *new_pc);

/**
 * @brief Return from the current IL subroutine.
 *
 * @param[in,out] state Tiny BASIC state.
 */
void tb_return(tb_state_t *state);

/**
 * @brief Start searching through the program line by line.
 *
 * @param[in,out] state Tiny BASIC state.
 *
 * @return Non-zero if the first line was found, zero if the program is empty.
 */
int tb_program_start(tb_state_t *state);

/**
 * @brief Search for the next line in the program.
 *
 * @param[in,out] state Tiny BASIC state.
 *
 * @return Non-zero if another line was found, zero at the end of the program.
 */
int tb_program_next(tb_state_t *state);

/**
 * @brief Compares the current search line number with a specific line number.
 *
 * @param[in,out] state Tiny BASIC state.
 * @param[in] line_number The line number to compare against.
 *
 * @return -1, 0, or 1 if @a line_number is less than, equal to, or
 * greater than the current search line number.
 *
 * For the purposes of this function, the end of the program is always
 * greater than any line number.
 */
int tb_program_cmp(tb_state_t *state, uint16_t line_number);

/**
 * @brief Find a specific line number in the program, or the next higher line.
 *
 * @param[in,out] state Tiny BASIC state.
 * @param[in] line_number The line number to compare against.
 *
 * @return 0 if the line was found or -1 if not.
 */
int tb_program_find(tb_state_t *state, uint16_t line_number);

/**
 * @brief Insert the input line into the program, or delete the existing
 * line if the text is empty.
 *
 * @param[in,out] state Tiny BASIC state.
 * @param[in] line_number The line number to insert at.
 *
 * @return Non-zero if OK, zero if out of memory.
 */
int tb_program_insert(tb_state_t *state, uint16_t line_number);

/**
 * @brief List the current line in the program.
 *
 * @param[in,out] state Tiny BASIC state.
 */
void tb_program_list_line(tb_state_t *state);

/**
 * @brief List the entire contents of the program.
 *
 * @param[in,out] state Tiny BASIC state.
 */
void tb_program_list(tb_state_t *state);

#ifdef __cplusplus
}
#endif

#endif
