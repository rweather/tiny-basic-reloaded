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
#include <time.h>
#include <signal.h>

/* IL bytecode programs for the Tiny BASIC variants */
#include "tb-bytecode-original.h"
#include "tb-bytecode-extended.h"
#include "tb-bytecode-reloaded.h"

static tb_state_t tb;

static void tb_sigint(int signum)
{
    (void)signum;
    tb.do_break = 1;
}

int main(int argc, char **argv)
{
    const tb_il_program_t *il = &tb_reloaded;
    const char *name = "TINY BASIC RELOADED";

    /* Parse the command-line arguments */
    if (argc > 1) {
        if (!strcmp(argv[1], "-x")) {
            /* "-x" selects the Tiny BASIC Extended (TBX) version */
            il = &tb_extended;
            name = "TINY BASIC EXTENDED";
        } else if (!strcmp(argv[1], "-o")) {
            /* "-o" selects the original Tiny BASIC version */
            il = &tb_original;
            name = "TINY BASIC";
        }
    }

    /* Install a SIGINT handler to handle BREAK */
    signal(SIGINT, tb_sigint);

    /* Initialize the Tiny BASIC engine */
    tb_init(&tb);
    tb_set_il(&tb, il);

    /* Print the header */
    printf("%s V1.0\n", name);
    printf("%u BYTES FREE\n\n", tb_program_get_free(&tb));

    /* Seed the libc system random number generator */
    srand(time(0));

    /* Run the Tiny BASIC engine */
    while (!tb.exit_seen) {
        tb_exec_one(&tb);
    }
    return tb.exit_code;
}
