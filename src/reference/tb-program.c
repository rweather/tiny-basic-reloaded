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

int tb_program_start(tb_state_t *state)
{
    state->search_cursor = state->program;
    state->search_line = state->search_cursor[0];
    state->search_line += ((uint16_t)(state->search_cursor[1])) << 8;
    return state->search_line != 0;
}

int tb_program_next(tb_state_t *state)
{
    if (state->search_line == 0) {
        return 0;
    }
    state->search_cursor += state->search_cursor[2] + 4;
    state->search_line = state->search_cursor[0];
    state->search_line += ((uint16_t)(state->search_cursor[1])) << 8;
    return state->search_line != 0;
}

int tb_program_cmp(tb_state_t *state, uint16_t line_number)
{
    if (state->search_line == 0) {
        return -1;
    } else if (line_number < state->search_line) {
        return -1;
    } else if (line_number == state->search_line) {
        return 0;
    } else {
        return 1;
    }
}

int tb_program_find(tb_state_t *state, uint16_t line_number)
{
    if (state->line_number != 0 && line_number > state->line_number) {
        /* We are executing the program and the new line number is
         * further along.  Start searching from the next line. */
        state->search_cursor = state->cursor;
        while (*(state->search_cursor) != 0) {
            ++(state->search_cursor);
        }
        ++(state->search_cursor);
        state->search_line = state->search_cursor[0];
        state->search_line += ((uint16_t)(state->search_cursor[1])) << 8;
        if (state->search_line == 0) {
            return -1;
        }
    } else {
        /* Rewind to the start of the program to start searching */
        if (!tb_program_start(state)) {
            return -1;
        }
    }
    do {
        int cmp = tb_program_cmp(state, line_number);
        if (cmp <= 0) {
            return cmp;
        }
    } while (tb_program_next(state));
    return -1;
}

size_t tb_normalize_line(tb_state_t *state)
{
    size_t size;
    size_t index;
    size_t out_index;
    uint8_t ch;
    int quote;

    /* Trim whitespace from the start and end of the line buffer */
    tb_skip_whitespace(state);
    size = strlen((const char *)(state->cursor));
    while (size > 0) {
        ch = state->cursor[size - 1];
        if (!tb_is_whitespace(ch)) {
            break;
        }
        --size;
    }

    /* Collapse multiple spaces and convert to uppercase */
    out_index = 0;
    quote = 0;
    for (index = 0; index < size; ++index) {
        ch = state->cursor[index];
        state->cursor[out_index] = ch;
        if (ch == '"') {
            quote = !quote;
        } else if (ch >= 'a' && ch <= 'z' && !quote) {
            /* Convert characters outside of quotes into uppercase */
            state->cursor[out_index] = ch - 'a' + 'A';
        } else if (ch == ' ' && !quote) {
            if (out_index > 0 && state->cursor[out_index - 1] == ' ') {
                /* Collapse multiple spaces into one */
                continue;
            }
        }
        ++out_index;
    }
    state->cursor[out_index] = 0;
    return out_index;
}

static int tb_program_do_insert
    (tb_state_t *state, uint16_t line_number, size_t size)
{
    size_t offset;
    if ((state->program_size + size) > (TB_MAX_PROGRAM - TB_MAX_RESERVED)) {
        return 0;
    }
    offset = state->search_cursor - state->program;
    memmove(state->search_cursor + size, state->search_cursor,
            state->program_size - offset);
    state->search_cursor[0] = (uint8_t)line_number;
    state->search_cursor[1] = (uint8_t)(line_number >> 8);
    state->search_cursor[2] = (uint8_t)(size - 4);
    memcpy(state->search_cursor + 3, state->cursor, size - 4);
    state->search_cursor[size - 1] = 0;
    state->search_line = line_number;
    state->program_size += size;
    return 1;
}

static void tb_program_do_delete(tb_state_t *state)
{
    size_t size = state->search_cursor[2] + 4;
    size_t offset = state->search_cursor - state->program;
    memmove(state->search_cursor, state->search_cursor + size,
            state->program_size - offset - size);
    state->program_size -= size;
}

int tb_program_insert(tb_state_t *state, uint16_t line_number)
{
    size_t size = tb_normalize_line(state);
    int cmp = tb_program_find(state, line_number);
    if (size == 0) {
        /* Delete the current line if the number matches */
        if (cmp == 0) {
            tb_program_do_delete(state);
        }
        return 1;
    } else {
        if (cmp == 0) {
            /* Delete the current line before inserting the new one */
            size_t old_size = state->search_cursor[2];
            if ((state->program_size + size - old_size) >
                    (TB_MAX_PROGRAM - TB_MAX_RESERVED)) {
                /* New line won't fit, so don't delete the old one */
                return 0;
            }
            tb_program_do_delete(state);
        }
        return tb_program_do_insert(state, line_number, size + 4);
    }
}

void tb_program_list_line(FILE *stream, tb_state_t *state)
{
    if (state->search_line != 0) {
        fprintf(stream, "%u %s\n", (unsigned)(state->search_line),
                (const char *)(state->search_cursor + 3));
    }
}

void tb_program_list(FILE *stream, tb_state_t *state)
{
    uint16_t first = state->list1;
    uint16_t last = state->list2;
    state->list1 = 0;
    state->list2 = 0;
    if (tb_program_start(state)) {
        if (first != 0) {
            while (state->search_line < first) {
                if (!tb_program_next(state)) {
                    return;
                }
            }
        }
        do {
            if (last != 0 && state->search_line > last) {
                break;
            }
            tb_program_list_line(stream, state);
        } while (!(state->do_break) && tb_program_next(state));
    }
}

unsigned tb_program_get_free(tb_state_t *state)
{
    return TB_MAX_PROGRAM - state->next_alloc;
}

unsigned tb_program_get_used_program(tb_state_t *state)
{
    return state->program_size;
}

unsigned tb_program_get_used_vars(tb_state_t *state)
{
    return state->next_alloc - state->program_size;
}

static int tb_ends_in_bas(const char *filename, size_t len, size_t size)
{
    if (len < 5) {
        return 0;
    }
    if (!memcmp(filename + len - 4, ".bas", 4) ||
            !memcmp(filename + len - 4, ".BAS", 4)) {
        return 1;
    }
    if ((len + 5) >= size) {
        /* Buffer is not big enough to add ".bas" */
        return 1;
    }
    return 0;
}

static int tb_get_filename(tb_state_t *state, char *filename, size_t size)
{
    size_t posn = 0;
    uint8_t ch;
    while ((ch = *(state->cursor)) != 0) {
        ++(state->cursor);
        if (ch == '"') {
            if (!posn) {
                return 0;
            }
            if (!tb_ends_in_bas(filename, posn, size)) {
                memcpy(filename + posn, ".bas", 4);
                posn += 4;
            }
            filename[posn] = '\0';
            return 1;
        }
        if ((posn + 1) >= size) {
            return 0;
        }
        filename[posn++] = (char)ch;
    }
    return 0;
}

int tb_program_load_from(tb_state_t *state, const char *filename)
{
    FILE *file = fopen(filename, "r");
    if (!file) {
        perror(filename);
        return 0;
    }
    tb_new(state);
    while (fgets((char *)(state->line), sizeof(state->line), file)) {
        /* Strip CR and LF from the end of the line */
        size_t len = strlen((const char *)(state->line));
        while (len > 0 && (state->line[len - 1] == '\r' ||
                           state->line[len - 1] == '\n')) {
            --len;
        }

        /* Set up to parse the line */
        state->line[len] = '\0';
        state->cursor = state->line;
        state->line_number = 0;

        /* Skip leading whitespace */
        tb_skip_whitespace(state);
        if (*(state->cursor) == 0) {
            /* Ignore empty lines */
            continue;
        }

        /* Parse the line number and push it onto AESTK */
        if (!tb_match_number(state, 1, 0)) {
            tb_error(state, TB_E_SYNTAX);
            fclose(file);
            return 0;
        }

        /* Insert the line into the program */
        if (!tb_insert(state)) {
            /* Ran out of memory trying to load the program */
            fclose(file);
            return 0;
        }
    }
    fclose(file);
    tb_end(state);
    return 1;
}

void tb_program_load(tb_state_t *state)
{
    char filename[TB_MAX_LINE];
    tb_skip_whitespace(state);
    if (state->cursor[0] == '"') {
        ++(state->cursor);
        if (!tb_get_filename(state, filename, sizeof(filename))) {
            tb_error(state, TB_E_INVFILENAME);
        } else {
            tb_program_load_from(state, filename);
        }
    } else if (state->cursor[0] != 0) {
        tb_error(state, TB_E_SYNTAX);
    } else {
        tb_error(state, TB_E_MISSING);
    }
}

int tb_program_save_to(tb_state_t *state, const char *filename)
{
    FILE *file = fopen(filename, "w");
    if (!file) {
        perror(filename);
        return 0;
    }
    tb_program_list(file, state);
    fclose(file);
    return 1;
}

void tb_program_save(tb_state_t *state)
{
    char filename[TB_MAX_LINE];
    tb_skip_whitespace(state);
    if (state->cursor[0] == '"') {
        ++(state->cursor);
        if (!tb_get_filename(state, filename, sizeof(filename))) {
            tb_error(state, TB_E_INVFILENAME);
        } else {
            tb_program_save_to(state, filename);
        }
        tb_end(state);
    } else if (state->cursor[0] != 0) {
        tb_error(state, TB_E_SYNTAX);
    } else {
        tb_error(state, TB_E_MISSING);
    }
}
