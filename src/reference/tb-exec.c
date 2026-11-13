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

#include "tb.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/**
 * @brief Match two characters.
 *
 * @param[in] ch1 The first character, which has already been
 * normalized to upper case.
 * @param[in] ch2 The second character, not yet normalized.
 *
 * @return Non-zero if the characters match, zero if they do not.
 */
static int tb_match_char(uint8_t ch1, uint8_t ch2)
{
    if (ch2 >= 'a' && ch2 <= 'z') {
        ch2 = ch2 - 'a' + 'A';
    }
    return ch1 == ch2;
}

/**
 * @brief Match a string in the IL program against the program text.
 *
 * @param[in,out] state Tiny BASIC state.
 *
 * @return Non-zero if there is a match, zero if no match.  In the case of a
 * match, the program position is advanced past the match.
 *
 * The match string in the IL program must be in uppercase and be
 * terminated with a character with the high bit set.
 */
static int tb_match_string(tb_state_t *state)
{
    uint8_t ch;
    unsigned offset = 0;
    while (((ch = *(state->pc)++) & 0x80) == 0) {
        if (ch == ' ') {
            /* Allow multiple whitespace characters between words.
             * This is not part of the original Tiny BASIC, but useful for
             * extensions that have "ON ERR" and other multi-word commands. */
            if (!tb_is_whitespace(state->cursor[offset])) {
                return 0;
            }
            ++offset;
            while (tb_is_whitespace(state->cursor[offset])) {
                ++offset;
            }
            continue;
        } else if (!tb_match_char(ch, state->cursor[offset])) {
            return 0;
        }
        ++offset;
    }
    ch &= 0x7F;
    if (!tb_match_char(ch, state->cursor[offset])) {
        return 0;
    }
    state->cursor += offset + 1;
    return 1;
}

/**
 * @brief Match a string in the IL program against the program text,
 * jumping to the destination if the match succeeds, continuing on failure.
 *
 * @param[in,out] state Tiny BASIC state.
 *
 * @return Non-zero if there is a match, zero if no match.  In the case of a
 * match, the program position is advanced past the match.
 *
 * The match string in the IL program must be in uppercase and be
 * terminated with a character with the high bit set.
 */
static int tb_match_string_inverse(tb_state_t *state)
{
    uint8_t ch;
    unsigned offset = 0;
    unsigned pc_offset = 0;
    unsigned end_offset = 0;
    while ((state->pc[end_offset] & 0x80) == 0) {
        ++end_offset;
    }
    ++end_offset;
    while (((ch = state->pc[pc_offset]) & 0x80) == 0) {
        if (ch == ' ') {
            /* Allow multiple whitespace characters between words.
             * This is not part of the original Tiny BASIC, but useful for
             * extensions that have "ON ERR" and other multi-word commands. */
            if (!tb_is_whitespace(state->cursor[offset])) {
                state->pc += end_offset;
                return 0;
            }
            ++offset;
            while (tb_is_whitespace(state->cursor[offset])) {
                ++offset;
            }
            continue;
        } else if (!tb_match_char(ch, state->cursor[offset])) {
            state->pc += end_offset;
            return 0;
        }
        ++offset;
        ++pc_offset;
    }
    ch &= 0x7F;
    if (!tb_match_char(ch, state->cursor[offset])) {
        state->pc += end_offset;
        return 0;
    }
    state->cursor += offset + 1;
    return 1;
}

/**
 * @brief Determine if the next token is a variable name.
 *
 * @param[in,out] state Tiny BASIC state.
 * @param[in] is_array Non-zero if testing for an array variable name.
 *
 * @return Non-zero if a variable, zero if not.
 */
static int tb_match_variable(tb_state_t *state, int is_array)
{
    uint8_t *cursor = state->cursor;
    uint8_t ch = cursor[0];
    if ((ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z')) {
        /* Variable names are A-Z only, calculate the index */
        tb_value_t index = (ch - 'A') & 0x1F;

        /* The next character must not be a letter or number.
         * This will be relaxed in the future for more variables.
         * For now, multi-letter words are considered keywords. */
        ++cursor;
        ch = *cursor;
        if ((ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') ||
                (ch >= '0' && ch <= '9')) {
            return 0;
        }

        /* Check for '(' if we are looking for an array variable */
        if (is_array) {
            while (tb_is_whitespace(ch)) {
                ++cursor;
                ch = *cursor;
            }
            if (ch != '(') {
                /* Not an array variable reference */
                return 0;
            }
        }

        /* Advance the program position past the variable name */
        state->cursor = cursor;

        /* Push the variable index onto the stack and return */
        if (is_array) {
            tb_push(state, tb_get_array_var(state, index));
        } else {
            tb_push(state, tb_get_plain_var(state, index));
        }
        return 1;
    }
    return 0;
}

/**
 * @brief Determine if the next token is a number.
 *
 * @param[in,out] state Tiny BASIC state.
 * @param[in] is_line_number Non-zero if looking for a line number.
 * @param[in] allow_sign Non-zero to allow a leading '-' or '+' sign.
 *
 * @return Positive if a number, zero if not, negative on error.
 *
 * If the next token is a number, then push it onto AESTK and
 * advance past the number.
 */
static int tb_match_number
    (tb_state_t *state, int is_line_number, int allow_sign)
{
    unsigned offset = 0;
    uint8_t ch = state->cursor[offset];
    uint32_t value;
    int is_neg = 0;
    int skip_ws = 0;
    if (ch == '-') {
        if (allow_sign) {
            is_neg = 1;
        } else {
            return 0;
        }
        ++offset;
        skip_ws = 1;
    } else if (ch == '+' && allow_sign) {
        ++offset;
        skip_ws = 1;
    }
    if (skip_ws) {
        /* We had a leading sign; skip whitespace after it */
        while ((ch = state->cursor[offset]) != 0) {
            if (!tb_is_whitespace(ch)) {
                break;
            }
            ++offset;
        }
    }
    ch = state->cursor[offset];
    if (ch < '0' || ch > '9') {
        return 0;
    }
    value = ch - '0';
    ++offset;
    while ((ch = state->cursor[offset]) != 0) {
        if (ch < '0' || ch > '9') {
            break;
        }
        value = value * 10 + (ch - '0');
        if (value > 32768U) {
            /* Value is too big to be a 16-bit integer.  We allow +32768
             * only so that it can be negated into -32768. */
            if (is_line_number) {
                tb_error(state, TB_E_INVLINE);
            } else {
                tb_error(state, TB_E_OVERFLOW);
            }
            return -1;
        }
        ++offset;
    }
    if (is_line_number) {
        /* Check if the number is valid as a line number */
        if (is_neg || value < 1 || value > TB_MAX_LINE_NUMBER) {
            tb_error(state, TB_E_INVLINE);
            return -1;
        }
    }
    if (allow_sign) {
        if (is_neg) {
            tb_push(state, -((tb_value_t)value));
        } else if (value == 32768U) {
            tb_error(state, TB_E_OVERFLOW);
            return -1;
        } else {
            tb_push(state, (tb_value_t)value);
        }
    } else {
        tb_push(state, (tb_value_t)value);
    }
    state->cursor += offset;
    return 1;
}

/**
 * @brief Print a string up until the next double-quote character.
 *
 * @param[in,out] state Tiny BASIC state.
 */
static void tb_print_string(tb_state_t *state)
{
    uint8_t ch;

    /* Print all characters until the next double-quote */
    while ((ch = *(state->cursor)) != 0) {
        ++(state->cursor);
        if (ch == '"') {
            fflush(stdout);
            return;
        }
        putc((int)ch, stdout);
    }

    /* Syntax error if the quoted string is unterminated */
    tb_error(state, TB_E_SYNTAX);
}

/**
 * @brief Perform a comparison.
 *
 * @param[in,out] state Tiny BASIC state.
 *
 * @return Non-zero if the comparison is true, zero if false.
 */
static tb_value_t tb_compare(tb_state_t *state)
{
    tb_value_t y = tb_pop(state);
    tb_value_t cmp = tb_pop(state);
    tb_value_t x = tb_pop(state);
    int result = 0;
    switch (cmp) {
    case TB_CMP_EQ: result = (x == y); break;
    case TB_CMP_LT: result = (x < y); break;
    case TB_CMP_LE: result = (x <= y); break;
    case TB_CMP_NE: result = (x != y); break;
    case TB_CMP_GT: result = (x > y); break;
    case TB_CMP_GE: result = (x >= y); break;
    default: break;
    }
    return result;
}

/**
 * @brief Gets a line of input.
 *
 * @param[in,out] state Tiny BASIC state.
 */
static void tb_getln(tb_state_t *state)
{
    size_t len;

    /* Restart input parsing on the next INPUT statement */
    state->input_cursor = 0;

    /* Get the line of input */
    if (!fgets((char *)(state->line), sizeof(state->line), stdin)) {
        /* EOF encountered on this host */
        state->exit_seen = 1;
        state->exit_code = 0;
        state->line[0] = '\0';
        return;
    }

    /* Remove CR and LF from the line and terminate with a NUL */
    len = strlen((char *)(state->line));
    while (len > 0) {
        uint8_t ch = state->line[len - 1];
        if (ch != '\r' && ch != '\n') {
            break;
        }
        --len;
    }
    state->line[len] = 0;
}

/**
 * @brief Input a value from the terminal.
 *
 * @param[in,out] state Tiny BASIC state.
 */
static void tb_input(tb_state_t *state, int type)
{
    int got_new_line = 0;
    uint8_t ch;
    uint8_t *save_cursor;
    int match;
    for (;;) {
        /* Do we have a partial line left-over from previous INPUT's? */
        if (!(state->input_cursor)) {
            /* No, get a new line */
            tb_getln(state);
            if (state->exit_seen) {
                /* Simulate an INPUT of empty/zero on EOF */
                if (type == TB_T_STRING) {
                    state->line[0] = '\0';
                } else {
                    tb_push(state, 0);
                }
                return;
            }
            state->input_cursor = state->line;
            got_new_line = 1;
        }

        /* If we wanted a string, then we are done */
        if (type == TB_T_STRING) {
            /* The string is in the "line" buffer, ready for the caller */
            state->input_cursor = 0;
            return;
        }

        /* Skip whitespace */
        while ((ch = *(state->input_cursor)) != 0) {
            if (!tb_is_whitespace(ch)) {
                break;
            }
        }
        if (ch == 0) {
            /* Reached the end of the line */
            if (got_new_line && type == TB_T_NUMBER) {
                /* User typed ENTER without entering a number */
                tb_error(state, TB_E_NODATA);
                state->input_cursor = 0;
                return;
            }

            /* We need a new line of input to continue */
            state->input_cursor = 0;
            continue;
        }

        /* Parse the next number */
        save_cursor = state->cursor;
        state->cursor = state->input_cursor;
        match = tb_match_number(state, 0, 1);
        state->cursor = save_cursor;
        if (match < 0) {
            /* Overflow error; discard the rest of the line */
            state->input_cursor = 0;
            break;
        } else if (match == 0) {
            /* No number found, which is a type mismatch error */
            tb_error(state, TB_E_TYPE);
            state->input_cursor = 0;
        }
        break;
    }
}

/**
 * @brief Pop a line number from AESTK and verify it.
 *
 * @param[in,out] state Tiny BASIC state.
 * @param[out] line_number Returns the line number.
 *
 * @return Non-zero if the line number is valid, zero on error.
 *
 * We allow a line number of zero to indicate "all", so that "LIST n-0"
 * will list "n" and all following lines, and so that "LIST 0-n" will
 * list all lines up to "n".  These can also be entered as "LIST n-" and
 * "LIST -n" as commands.
 */
static int tb_pop_line_number(tb_state_t *state, uint16_t *line_number)
{
    tb_value_t line = tb_pop(state);
    *line_number = (uint16_t)line;
    if (line < 0 || line > TB_MAX_LINE_NUMBER) {
        tb_error(state, TB_E_INVLINE);
        return 0;
    }
    return 1;
}

/**
 * @brief Apply a unary operator.
 *
 * @param[in,out] state Tiny BASIC state.
 * @param[in] opcode The operator to apply.
 * @param[in] x The operand to apply the operator to.
 *
 * @return The result of applying the operator.
 */
static tb_value_t tb_apply1(tb_state_t *state, uint8_t opcode, tb_value_t x)
{
    switch (opcode) {
    case TB_I_NEG:      return -x;
    case TB_I_BNOT:     return ~x;
    case TB_I_LNOT:     return !x;

    case TB_I_RND:
        if (x <= 0) {
            /* Random number between 0 (inclusive) and 1 (exclusive) */
            return 0;
        } else {
            /* Random number between 0 and x-1 */
            return rand() * ((int64_t)x) / RAND_MAX;
        }

    case TB_I_PEEK:
        /* This implementation ignores all PEEK's */
        return 0;

    default:
        tb_error(state, TB_E_SYNTAX);
        break;
    }
    return 0;
}

/**
 * @brief Apply a binary operator.
 *
 * @param[in,out] state Tiny BASIC state.
 * @param[in] opcode The operator to apply.
 * @param[in] x The first operand to apply the operator to.
 * @param[in] y The second operand to apply the operator to.
 *
 * @return The result of applying the operator.
 */
static tb_value_t tb_apply2
    (tb_state_t *state, uint8_t opcode, tb_value_t x, tb_value_t y)
{
    switch (opcode) {
    case TB_I_ADD:      return x + y;
    case TB_I_SUB:      return x - y;
    case TB_I_MPY:      return x * y;
    case TB_I_BAND:     return x & y;
    case TB_I_BOR:      return x | y;
    case TB_I_BXOR:     return x ^ y;
    case TB_I_LAND:     return x && y;
    case TB_I_LOR:      return x || y;
    case TB_I_SHL:      return x << y;
    case TB_I_SHR:      return x >> y;
    case TB_I_LSR:      return ((uint16_t)x) >> y;
    case TB_I_CMPEQ:    return x == y;
    case TB_I_CMPNE:    return x != y;
    case TB_I_CMPLT:    return x < y;
    case TB_I_CMPGT:    return x > y;
    case TB_I_CMPLE:    return x <= y;
    case TB_I_CMPGE:    return x >= y;

    case TB_I_DIV:
        if (y != 0) {
            return x / y;
        }
        tb_error(state, TB_E_DIVZERO);
        break;

    case TB_I_MOD:
        if (y != 0) {
            return x % y;
        }
        tb_error(state, TB_E_DIVZERO);
        break;

    default:
        tb_error(state, TB_E_SYNTAX);
        break;
    }
    return 0;
}

/**
 * @brief Parse a literal string and return the ASCII code for the
 * first character in it.
 *
 * @param[in,out] state Tiny BASIC state.
 *
 * @return The ASCII character.
 */
static uint8_t tb_asc(tb_state_t *state)
{
    uint8_t ch, ch2;
    tb_skip_whitespace(state);
    if (*(state->cursor) != '"') {
        tb_error(state, TB_E_SYNTAX);
        return 0;
    }
    ++(state->cursor);
    if (*(state->cursor) == '"') {
        /* Empty string, return NUL */
        ++(state->cursor);
        return 0;
    } else if (*(state->cursor) == 0) {
        /* Unexpected end of line */
        tb_error(state, TB_E_SYNTAX);
        return 0;
    }
    ch = *(state->cursor)++;

    /* Skip the rest of the string if more than one character */
    while ((ch2 = *(state->cursor)) != '"') {
        if (ch2 == 0) {
            tb_error(state, TB_E_SYNTAX);
            return 0;
        }
        ++(state->cursor);
    }
    ++(state->cursor);
    return ch;
}

void tb_exec_one(tb_state_t *state)
{
    uint8_t insn;
    int16_t offset;
    tb_value_t x, y;
    const uint8_t *start;

    /* If the break flag is set, then perform the break */
    if (state->do_break) {
        state->do_break = 0;
        if (state->line_number) {
            printf("\nBREAK AT LINE %d\n", (int)(state->line_number));
        } else {
            printf("\nBREAK\n");
        }
        tb_end(state);
    }

    /* Fetch the next instruction and advance the PC */
    start = state->pc;
    insn = *(state->pc)++;

    /* Dispatch the instruction */
    switch (insn) {

    /*
     * Classic Tiny BASIC instructions.
     */

    case TB_I_TST:
        /* Test the next token to see if it is a literal string */
        tb_skip_whitespace(state);
        offset = (int8_t)(*(state->pc)++);
        if (!tb_match_string(state)) {
            if (offset == 0) {
                /* When TST jumps back to itself, that means a syntax error */
                tb_error(state, TB_E_SYNTAX);
            } else {
                state->pc = start + offset;
            }
        }
        break;

    case TB_I_CALL:
        /* Call a subroutine at a 16-bit offset relative to this instruction */
        offset = *(state->pc)++;
        offset |= ((int16_t)(*(state->pc)++)) << 8;
        tb_call(state, start + offset);
        break;

    case TB_I_JMP:
        /* Jump to a 16-bit offset relative to this instruction */
        offset = *(state->pc)++;
        offset |= ((int16_t)(*(state->pc)++)) << 8;
        state->pc = start + offset;
        break;

    case TB_I_RTN:
        /* Return from the current IL subroutine */
        tb_return(state);
        break;

    case TB_I_DONE:
    case TB_I_DONEX:
        /* Check that we are at the end of the current statement.
         * A syntax error will occur if we are not. */
        tb_done(state);
        break;

    case TB_I_PRS:
        /* Print a string up until the next double-quote character */
        tb_print_string(state);
        break;

    case TB_I_PRN:
        /* Print the number at the top of the AESTK */
        printf("%d", (int)(tb_pop(state)));
        break;

    case TB_I_SPC:
        /* Space to the next field on the screen for "," in a PRINT statement */
        putc('\t', stdout);
        fflush(stdout);
        break;

    case TB_I_NLINE:
        /* Print a CRLF */
        putc('\n', stdout);
        break;

    case TB_I_NXT:
    case TB_I_NXTX:
        /* Go to the next line of the BASIC program */
        tb_next(state);
        break;

    case TB_I_RNXT:
        /* Start running the BASIC program */
        tb_run(state);
        break;

    case TB_I_XFER:
        /* Transfer to a specific line in the BASIC program */
        tb_goto(state, tb_pop(state));
        break;

    case TB_I_SAV:
        /* Push the current location in the BASIC program onto SUBSTK */
        tb_push_sub(state);
        break;

    case TB_I_RSTR:
        /* Restore the RETURN address from SUBSTK */
        tb_pop_sub(state);
        break;

    case TB_I_CMPR:
        /* Perform a comparison */
        if (!tb_compare(state)) {
            /* Comparison is false, so skip to the next line */
            tb_next(state);
        }
        break;

    case TB_I_INNUM:
        /* Input a number */
        if (state->line_number == 0) {
            /* Cannot do INNUM in direct mode */
            tb_error(state, TB_E_DIRECT);
            break;
        }
        tb_input(state, TB_T_NUMBER);
        break;

    case TB_I_FIN:
        /* End execution of the BASIC program */
        tb_end(state);
        break;

    case TB_I_ERR:
    case TB_I_CUSTOM:
        /* Report a syntax error and stop execution of the BASIC program */
        tb_error(state, TB_E_SYNTAX);
        break;

    case TB_I_ADD:
    case TB_I_SUB:
    case TB_I_MPY:
    case TB_I_DIV:
    case TB_I_MOD:
    case TB_I_BAND:
    case TB_I_BOR:
    case TB_I_BXOR:
    case TB_I_LAND:
    case TB_I_LOR:
    case TB_I_SHL:
    case TB_I_SHR:
    case TB_I_LSR:
    case TB_I_CMPEQ:
    case TB_I_CMPNE:
    case TB_I_CMPLT:
    case TB_I_CMPGT:
    case TB_I_CMPLE:
    case TB_I_CMPGE:
        /* Apply a binary operator */
        y = tb_pop(state);
        x = tb_pop(state);
        tb_push(state, tb_apply2(state, insn, x, y));
        break;

    case TB_I_NEG:
    case TB_I_BNOT:
    case TB_I_LNOT:
    case TB_I_RND:
        /* Apply a unary operator */
        tb_push(state, tb_apply1(state, insn, tb_pop(state)));
        break;

    case TB_I_LIT:
        /* Push a literal byte onto the AESTK */
        tb_push(state, *(state->pc)++);
        break;

    case TB_I_STORE:
        /* Store to a variable whose index is on the stack */
        y = tb_pop(state);
        x = tb_pop(state);
        tb_store(state, x, y);
        break;

    case TB_I_TSTV:
        /* Test the next token to see if it is a variable name */
        tb_skip_whitespace(state);
        offset = (int8_t)(*(state->pc)++);
        if (!tb_match_variable(state, 0)) {
            if (offset == 0) {
                /* When TSTV jumps back to itself, that means a syntax error */
                tb_error(state, TB_E_SYNTAX);
            } else {
                state->pc = start + offset;
            }
        }
        break;

    case TB_I_TSTN:
    case TB_I_TSTL:
        /* Test the next token to see if it is a number */
        tb_skip_whitespace(state);
        offset = (int8_t)(*(state->pc)++);
        if (!tb_match_number(state, insn == TB_I_TSTL, 0)) {
            if (offset == 0) {
                /* When TSTN jumps back to itself, that means a syntax error */
                tb_error(state, TB_E_SYNTAX);
            } else {
                state->pc = start + offset;
            }
        }
        break;

    case TB_I_INSRT:
        /* Insert the current line into the program */
        tb_insert(state);
        break;

    case TB_I_INIT:
        /* Re-initialize BASIC */
        tb_new(state);
        break;

    case TB_I_XINIT:
        /* Initialize the interpreter to execute the next statement */
        tb_xinit(state);
        break;

    case TB_I_GETLN:
        /* Get a line of input from the terminal in direct mode */
        tb_getln(state);
        state->cursor = state->line;
        state->line_number = 0;
        tb_normalize_line(state);
        break;

    case TB_I_LST:
        /* List the BASIC program */
        tb_program_list(state);
        break;

    case TB_I_IND:
        /* Index a variable to get its value */
        x = tb_pop(state);
        tb_push(state, tb_index(state, x));
        break;

    /*
     * Tiny BASIC Extended (TBX) instructions.
     */

    case TB_I_ARRAY1:
        /* Index into a 1D array to find a pointer to the element */
        y = tb_pop(state);
        x = tb_pop(state);
        tb_push(state, tb_get_1d_element(state, x, y));
        break;

    case TB_I_ARRAY2:
        /* Index into a 2D array to find a pointer to the element */
        y = tb_pop(state);
        x = tb_pop(state);
        tb_push(state, tb_get_2d_element(state, tb_pop(state), x, y));
        break;

    case TB_I_DIM1:
        /* Dimension a 1D array */
        x = tb_pop(state);
        tb_dim_1d(state, tb_pop(state), x);
        break;

    case TB_I_DIM2:
        /* Dimension a 2D array */
        y = tb_pop(state);
        x = tb_pop(state);
        tb_dim_2d(state, tb_pop(state), x, y);
        break;

    case TB_I_FOR:
        /* Mark the start of a "FOR" loop */
        y = tb_pop(state);
        x = tb_pop(state);
        tb_for(state, tb_pop(state), x, y);
        break;

    case TB_I_NEXT:
        /* "NEXT" at the end of a "FOR" loop */
        tb_next_for(state, tb_pop(state));
        break;

    case TB_I_LIST0:
        /* Set up to list the entire BASIC program when 'LST' is used */
        state->list1 = 0;
        state->list2 = 0;
        break;

    case TB_I_LIST1:
        /* Set up to list a single line when 'LST' is used */
        if (tb_pop_line_number(state, &(state->list1))) {
            state->list2 = state->list1;
        } else {
            state->list1 = 0;
            state->list2 = 0;
        }
        break;

    case TB_I_LIST2:
        /* Set up to list a range of lines when 'LST' is used */
        if (!tb_pop_line_number(state, &(state->list2)) ||
                !tb_pop_line_number(state, &(state->list1))) {
            state->list1 = 0;
            state->list2 = 0;
        }
        break;

    case TB_I_RANDOM:
        /* Generate a random number between 0 and 10000 and push onto AESTK */
        tb_push(state, rand() % 10001);
        break;

    case TB_I_SIZE:
        /* Print memory sizes */
        printf("PROG: %5u BYTES\n", tb_program_get_used_program(state));
        printf("VARS: %5u BYTES\n", tb_program_get_used_vars(state));
        printf("FREE: %5u BYTES\n", tb_program_get_free(state));
        break;

    case TB_I_SPCONE:
        /* Output a single space */
        fputc(' ', stdout);
        fflush(stdout);
        break;

    case TB_I_TAB:
        /* Output a number of spaces, as given by the value on AESTK */
        x = tb_pop(state);
        while (x > 0) {
            if (state->do_break) {
                break;
            }
            putc(' ', stdout);
            --x;
        }
        fflush(stdout);
        break;

    case TB_I_TSTA:
        /* Test if the next token is an array reference like "X(".
         * Get a pointer to the array and push it onto the stack. */
        tb_skip_whitespace(state);
        offset = (int8_t)(*(state->pc)++);
        if (!tb_match_variable(state, 1)) {
            if (offset == 0) {
                /* When TSTA jumps back to itself, that means a syntax error */
                tb_error(state, TB_E_SYNTAX);
            } else {
                state->pc = start + offset;
            }
        }
        break;

    case TB_I_TSTCR:
        /* Test for the end of the line */
        tb_skip_whitespace(state);
        offset = (int8_t)(*(state->pc)++);
        if (state->cursor[0] != 0) {
            if (offset == 0) {
                /* When TSTCR jumps back to itself, that means a syntax error */
                tb_error(state, TB_E_SYNTAX);
            } else {
                state->pc = start + offset;
            }
        }
        break;

    case TB_I_STOREV:
        /* Store to a variable, but don't pop the variable index */
        y = tb_pop(state);
        x = tb_pop(state);
        tb_push(state, x);
        tb_store(state, x, y);
        break;

    /*
     * Tiny BASIC Reloaded instructions.
     */

    case TB_I_END:
        /* Combines the effect of DONE and NXT */
        tb_done(state);
        tb_next(state);
        break;

    case TB_I_CHKSTK:
        /* Check the size of CTLSTK for deep recursion.  We don't
         * bother here because every "CALL" checks the stack depth.
         * On actual hardware, we only need to check for expressions. */
        break;

    case TB_I_TSTJ:
        /* Test the next token to see if it is a literal string; jump if true */
        tb_skip_whitespace(state);
        offset = *(state->pc)++;
        offset |= ((int16_t)(*(state->pc)++)) << 8;
        if (tb_match_string_inverse(state)) {
            state->pc = start + offset;
        }
        break;

    case TB_I_IF:
        /* Go to the next line if the condition on AESTK is false */
        if (tb_pop(state) == 0) {
            tb_next(state);
        }
        break;

    case TB_I_LIT16:
        /* Push a literal 16-bit value onto the AESTK */
        x = *(state->pc)++;
        x |= ((int16_t)(*(state->pc)++)) << 8;
        tb_push(state, x);
        break;

    case TB_I_PRC:
        /* Print a single character based on its integer code */
        fputc(tb_pop(state) & 0xFF, stdout);
        fflush(stdout);
        break;

    case TB_I_TSTEND:
        /* Test for the end of the statement */
        tb_skip_whitespace(state);
        offset = (int8_t)(*(state->pc)++);
        if (state->cursor[0] != 0 && state->cursor[0] != ':') {
            if (offset == 0) {
                /* When TSTEND jumps back to itself, report a syntax error */
                tb_error(state, TB_E_SYNTAX);
            } else {
                state->pc = start + offset;
            }
        }
        break;

    case TB_I_TSTOP:
        /* Test for an operator */
        tb_skip_whitespace(state);
        offset = (int8_t)(*(state->pc)++);
        insn = *(state->pc)++;
        if (tb_match_string_inverse(state)) {
            /* Push the opcode for APPLY* to use later and jump */
            tb_push(state, insn);
            state->pc = start + offset;
        }
        break;

    case TB_I_APPLY:
        /* Apply a binary operator */
        y = tb_pop(state);
        x = tb_pop(state);
        tb_push(state, tb_apply2(state, x, tb_pop(state), y));
        break;

    case TB_I_APPLYFN:
        /* Apply a unary function */
        x = tb_pop(state);
        tb_push(state, tb_apply1(state, tb_pop(state), x));
        break;

    case TB_I_CUSTFN:
        /* Parse custom functions; nothing to do except skip the label */
        ++(state->pc);
        break;

    case TB_I_ASC:
        /* Convert the first character in a string into an ASCII code */
        tb_push(state, tb_asc(state));
        break;

    case TB_I_POKE:
        /* This implementation ignores all POKE's */
        tb_pop(state);
        tb_pop(state);
        break;

    case TB_I_POP:
        /* Pop the top-most RETURN from the GOSUB stack */
        tb_discard_sub(state);
        break;

    case TB_I_MCALL:
        /* This implementation ignores all machine language calls */
        tb_pop(state);
        break;

    case TB_I_CLEAR:
        /* Clear all variables */
        tb_clear_vars(state);
        break;

    case TB_I_LOAD:
        /* Load program, not implemented yet */
        break;

    case TB_I_SAVE:
        /* Save program, not implemented yet */
        break;

    case TB_I_INKEY:
        /* Input a keystroke without waiting, not implemented yet */
        tb_push(state, -1);
        break;

    case TB_I_EXIT:
        /* Exit back to the operating system with the status on AESTK */
        state->exit_seen = 1;
        state->exit_code = (tb_pop(state) & 0xFF);
        break;

    default:
        /* Unknown IL bytecode */
        tb_error(state, TB_E_ILLFUNC);
        break;
    }
}
