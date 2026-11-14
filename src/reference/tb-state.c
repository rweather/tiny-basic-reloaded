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
#include <string.h>

/*
 * Each line in the program is represented as follows:
 *
 * Bytes    Description
 * ---------------------------------------------------------------
 * 0,1      Little-endian 16-bit line number between 1 and 31999
 * 2        Length of the text that follows, excluding the NUL
 * 3-n      Text of the line
 * n+1      Terminating NUL on the line
 */

void tb_init(tb_state_t *state)
{
    memset(state, 0, sizeof(tb_state_t));
    tb_new(state);
}

void tb_set_il(tb_state_t *state, const tb_il_program_t *il)
{
    state->il = il;
    state->pc = il->start;
}

void tb_new(tb_state_t *state)
{
    state->program[0] = 0;
    state->program[1] = 0;
    state->program[2] = 0;
    state->program[3] = 0;
    state->program_size = 4;
    tb_clear_vars(state);
    tb_end(state);
}

void tb_xinit(tb_state_t *state)
{
    state->ctlstk_size = 0;
    state->aestk_size = 0;
    state->colon_mode = 0;
    state->input_cursor = 0;
}

void tb_error(tb_state_t *state, uint8_t error)
{
    static const char * const errors[] = {
        "NE", "NO ERROR",
        "NF", "NEXT WITHOUT FOR",
        "SN", "SYNTAX ERROR",
        "RG", "RETURN WITHOUT GOSUB",
        "OD", "OUT OF DATA",
        "FC", "ILLEGAL FUNCTION CALL",
        "OV", "OVERFLOW ERROR",
        "OM", "OUT OF MEMORY",
        "UL", "INVALID LINE NUMBER",
        "BS", "SUBSCRIPT OUT OF RANGE",
        "DD", "REDIMENSIONED ARRAY",
        "/0", "DIVISION BY ZERO",
        "ID", "ILLEGAL DIRECT",
        "TM", "TYPE MISMATCH",
        "OS", "OUT OF STRING SPACE",
        "LS", "STRING TOO LONG",
        "ST", "FORMULA TOO COMPLEX",
        "CN", "CANNOT CONTINUE",
        "NR", "NO RESUME",
        "RW", "RESUME WITHOUT ERROR",
        "UE", "UNPRINTABLE ERROR",
        "MO", "MISSING OPERAND",
        "FD", "BAD FILE DATA",
        "L3", "DISK BASIC ERROR",
        "TG", "TOO MANY GOSUBS",
        "TF", "TOO MANY FORS",
        "IA", "INVALID ARRAY DIMENSION",
        "NA", "NOT AN ARRAY",
        "IF", "INVALID FILENAME",
        "??", "UNKNOWN ERROR"     /* Must be last in the array */
    };
    unsigned err = ((unsigned)error) * 2;
    if (err >= (sizeof(errors) / sizeof(errors[0]))) {
        err = (sizeof(errors) / sizeof(errors[0])) - 1;
    }
    printf("\n%s", errors[err + 1]);
    if (state->line_number) {
        printf(" IN LINE %d\n", (int)(state->line_number));
    } else {
        printf("\n");
    }
    tb_end(state);
    state->pc = state->il->error;
}

void tb_end(tb_state_t *state)
{
    state->ctlstk_size = 0;
    state->aestk_size = 0;
    state->substk_size = 0;
    state->cursor = state->line;
    state->line_number = 0;
    state->colon_mode = 0;
    state->do_break = 0;
    state->input_cursor = 0;
    state->search_cursor = 0;
    state->search_line = 0;
    if (state->il) {
        state->pc = state->il->direct;
    }
}

int tb_is_direct(tb_state_t *state)
{
    return state->line_number == 0;
}

static void tb_move_to_next(tb_state_t *state)
{
    ++(state->cursor);
    state->line_number = state->cursor[0];
    state->line_number += ((uint16_t)(state->cursor[1])) << 8;
    state->cursor += 3;
    state->colon_mode = 0;
}

void tb_next(tb_state_t *state)
{
    if (state->line_number == 0 && !state->colon_mode) {
        /* We were in direct mode, so go back to that */
        tb_end(state);
    } else if (state->colon_mode) {
        /* The previous DONE saw a colon, so continue on this line */
        state->pc = state->il->next;
    } else {
        /* Find the end of the current line */
        while (*(state->cursor) != 0) {
            ++(state->cursor);
        }

        /* Move the cursor to the next line */
        tb_move_to_next(state);
        if (state->line_number == 0) {
            /* We have fallen off the end of the BASIC program */
            tb_end(state);
        } else {
            state->pc = state->il->next;
        }
    }
}

void tb_run(tb_state_t *state)
{
    tb_clear_vars(state);
    state->cursor = state->program;
    state->line_number = state->cursor[0];
    state->line_number += ((uint16_t)(state->cursor[1])) << 8;
    if (state->line_number != 0) {
        /* We have a program in memory */
        state->colon_mode = 0;
        state->cursor += 3;
        state->pc = state->il->next;
    } else {
        /* No program in memory, so do the same as "END" */
        tb_end(state);
    }
}

void tb_push(tb_state_t *state, tb_value_t value)
{
    if (state->aestk_size < TB_MAX_AESTK) {
        state->aestk[(state->aestk_size)++] = value;
    } else {
        tb_error(state, TB_E_EXPR);
    }
}

tb_value_t tb_pop(tb_state_t *state)
{
    if (state->aestk_size > 0) {
        return state->aestk[--(state->aestk_size)];
    } else {
        return 0;
    }
}

void tb_push_sub(tb_state_t *state)
{
    if (state->line_number == 0) {
        /* Cannot do a GOSUB in direct mode */
        tb_error(state, TB_E_DIRECT);
        return;
    }
    if (state->substk_size < TB_MAX_SUBSTK) {
        if (*(state->cursor) == 0) {
            /* At the end of the line, skip forward to the next one */
            tb_move_to_next(state);
            state->colon_mode = 1;
        }
        state->substk[state->substk_size].cursor = state->cursor;
        state->substk[state->substk_size].line_number = state->line_number;
        state->substk[state->substk_size].var = 0;
        ++(state->substk_size);
    } else {
        tb_error(state, TB_E_GOSUB);
    }
}

void tb_pop_sub(tb_state_t *state)
{
    while (state->substk_size > 0) {
        --(state->substk_size);
        if (state->substk[state->substk_size].var != 0) {
            /* This frame is for a "FOR" loop; ignore it */
            continue;
        }
        state->colon_mode = 0;
        state->cursor = state->substk[state->substk_size].cursor;
        state->line_number = state->substk[state->substk_size].line_number;
        if (state->line_number == 0) {
            /* GOSUB was at the end of the program previously */
            tb_end(state);
        } else {
            /* Continue executing from where we left off */
            state->pc = state->il->next;
        }
        return;
    }
    tb_error(state, TB_E_RETURN);
}

void tb_discard_sub(tb_state_t *state)
{
    while (state->substk_size > 0) {
        --(state->substk_size);
        if (state->substk[state->substk_size].var == 0) {
            return;
        }
    }
    tb_error(state, TB_E_RETURN);
}

void tb_for
    (tb_state_t *state, tb_value_t var, tb_value_t stop, tb_value_t step)
{
    tb_substk_item_t *item;
    if (state->line_number == 0) {
        /* Cannot do a FOR in direct mode */
        tb_error(state, TB_E_DIRECT);
        return;
    }
    if (state->substk_size < TB_MAX_SUBSTK) {
        if (*(state->cursor) == 0) {
            /* At the end of the line, skip forward to the next one */
            tb_move_to_next(state);
            state->colon_mode = 1;
        }
        item = &(state->substk[state->substk_size]);
        item->cursor = state->cursor;
        item->line_number = state->line_number;
        item->var = var;
        item->stop = stop;
        item->step = step;
        ++(state->substk_size);
    } else {
        tb_error(state, TB_E_FOR);
    }
}

/**
 * @brief Pop the current location in the BASIC program from SUBSTK
 * for a "GOSUB" statement.
 *
 * @param[in,out] state Tiny BASIC state.
 *
 * This will call tb_error() and redirect IL program flow on stack underflow.
 */
static void tb_pop_for(tb_state_t *state)
{
    if (state->substk_size > 0) {
        if (state->substk[state->substk_size - 1].var != 0) {
            --(state->substk_size);
        }
    }
}

/**
 * @brief Pop frames until a specific "FOR" loop is found on SUBSTK.
 *
 * @param[in,out] state Tiny BASIC state.
 * @param[in] var The variable of the "FOR" loop to find, or 0 for the
 * next outermost "FOR" loop.
 *
 * @return A pointer to the SUBSTK item for the "FOR" loop, or NULL
 * if the "FOR" loop corresponding to @a var could not be located.
 */
static tb_substk_item_t *tb_find_for(tb_state_t *state, tb_value_t var)
{
    tb_substk_item_t *item;
    while (state->substk_size > 0) {
        item = &(state->substk[state->substk_size - 1]);
        if (item->var == 0) {
            /* This frame is for a "RETURN".  "FOR" loop was not found. */
            break;
        }
        if (!var || item->var == var) {
            /* We found the "FOR" loop we were looking for. */
            return item;
        }
        --(state->substk_size);
    }
    return 0;
}

void tb_next_for(tb_state_t *state, tb_value_t var)
{
    tb_substk_item_t *item = tb_find_for(state, var);
    if (item) {
        /* Increment the loop variable by the step */
        tb_value_t value = tb_index(state, item->var);
        value += item->step;
        tb_store(state, item->var, value);

        /* Have we exceeded the maximum value for the loop? */
        if ((item->step >= 0 && value > item->stop) ||
                (item->step < 0 && value < item->stop)) {
            /* Last iteration of the "FOR" loop */
            tb_pop_for(state);
            tb_next(state);
        } else {
            /* Update the variable and do another iteration */
            state->cursor = item->cursor;
            state->line_number = item->line_number;
            state->colon_mode = 0;
            if (state->line_number == 0) {
                /* FOR was at the end of the program previously */
                tb_end(state);
            } else {
                /* Continue executing from where we left off */
                state->pc = state->il->next;
            }
        }
    } else {
        tb_error(state, TB_E_NEXTFOR);
    }
}

int tb_is_whitespace(uint8_t ch)
{
    return ch == ' ' || ch == '\t' || ch == '\f' ||
           ch == '\v' || ch == '\r' || ch == '\n';
}

void tb_skip_whitespace(tb_state_t *state)
{
    uint8_t ch;
    while ((ch = *(state->cursor)) != 0) {
        if (!tb_is_whitespace(ch)) {
            break;
        }
        ++(state->cursor);
    }
}

void tb_done(tb_state_t *state)
{
    tb_skip_whitespace(state);
    state->colon_mode = 0;
    if (*(state->cursor) == ':') {
        /* Allow ":" to separate statements on the line.  Technically,
         * this is not compatible with the original Tiny BASIC.
         * It is so useful that it would be a shame not to include it. */
        ++(state->cursor);
        state->colon_mode = 1;
    } else if (*(state->cursor) != 0) {
        tb_error(state, TB_E_SYNTAX);
    }
}

void tb_goto(tb_state_t *state, tb_value_t line_number)
{
    if (line_number > 0 && line_number <= TB_MAX_LINE_NUMBER) {
        if (tb_program_find(state, (uint16_t)line_number) == 0) {
            state->cursor = state->search_cursor + 3;
            state->line_number = (uint16_t)line_number;
            state->pc = state->il->next;
        } else {
            tb_error(state, TB_E_INVLINE);
        }
    } else {
        tb_error(state, TB_E_INVLINE);
    }
}

int tb_insert(tb_state_t *state)
{
    int ok = 1;

    /* Insert the line into the program */
    uint16_t line_number = tb_pop(state);
    if (!tb_program_insert(state, line_number)) {
        tb_error(state, TB_E_MEMORY);
        ok = 0;
    }

    /* Set up for direct mode again with an empty line */
    state->cursor = state->line;
    state->line_number = 0;
    state->line[0] = '\0';

    /* When the program changes size, we need to clear the variables
     * because arrays and other dynamic structures are stored just
     * beyond the end of the program. */
    tb_clear_vars(state);
    return ok;
}

void tb_call(tb_state_t *state, const uint8_t *new_pc)
{
    if (state->ctlstk_size < TB_MAX_CTLSTK) {
        /* Push the return address on the control stack and jump */
        state->ctlstk[(state->ctlstk_size)++] = state->pc;
        state->pc = new_pc;
    } else {
        /* Deep IL subroutine nesting usually occurs in expressions */
        tb_error(state, TB_E_EXPR);
    }
}

void tb_return(tb_state_t *state)
{
    if (state->ctlstk_size > 0) {
        --(state->ctlstk_size);
        state->pc = state->ctlstk[state->ctlstk_size];
    } else {
        tb_error(state, TB_E_ILLFUNC);
    }
}
