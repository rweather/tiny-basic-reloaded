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

void tb_clear_vars(tb_state_t *state)
{
    memset(state->program + state->program_size, 0,
           sizeof(tb_value_t) * TB_MAX_PLAIN_VARS +
           sizeof(tb_array_t) * TB_MAX_ARRAY_VARS);
    state->next_alloc = state->program_size + TB_MAX_RESERVED;
}

tb_value_t tb_get_plain_var(tb_state_t *state, int var_num)
{
    if (var_num >= 0 && var_num < TB_MAX_PLAIN_VARS) {
        return state->program_size + var_num * sizeof(tb_value_t);
    }
    return 0;
}

tb_value_t tb_get_array_var(tb_state_t *state, int var_num)
{
    if (var_num >= 0 && var_num < TB_MAX_ARRAY_VARS) {
        return state->program_size + sizeof(tb_value_t) * TB_MAX_PLAIN_VARS +
               var_num * sizeof(tb_array_t);
    }
    return 0;
}

tb_value_t tb_index(tb_state_t *state, tb_value_t ref)
{
    uint16_t refu = (uint16_t)ref;
    if (refu >= state->program_size &&
            refu <= (TB_MAX_PROGRAM - sizeof(tb_value_t))) {
        return *((tb_value_t *)(state->program + refu));
    } else {
        return 0;
    }
}

void tb_store(tb_state_t *state, tb_value_t ref, tb_value_t value)
{
    uint16_t refu = (uint16_t)ref;
    if (refu >= state->program_size &&
            refu <= (TB_MAX_PROGRAM - sizeof(tb_value_t))) {
        *((tb_value_t *)(state->program + refu)) = value;
    }
}

static tb_array_t *tb_get_array(tb_state_t *state, tb_value_t ref)
{
    uint16_t refu = (uint16_t)ref;
    if (refu < (state->program_size + TB_MAX_PLAIN_VARS * sizeof(tb_value_t))) {
        return 0;
    }
    if (refu >= (TB_MAX_PROGRAM - sizeof(tb_array_t))) {
        return 0;
    }
    return (tb_array_t *)(state->program + ref);
}

tb_value_t tb_get_1d_element
    (tb_state_t *state, tb_value_t ref, tb_value_t index)
{
    tb_array_t *array = tb_get_array(state, ref);
    if (array && array->dim1 != 0 && array->dim2 == 0) {
        if (index >= 0 && index <= ((tb_value_t)(array->dim1))) {
            return array->offset + index * sizeof(tb_value_t);
        } else {
            tb_error(state, TB_E_SUBSCRIPT);
        }
    } else {
        tb_error(state, TB_E_NOTARRAY);
    }
    return 0;
}

tb_value_t tb_get_2d_element
    (tb_state_t *state, tb_value_t ref, tb_value_t index1, tb_value_t index2)
{
    tb_array_t *array = tb_get_array(state, ref);
    if (array && array->dim1 != 0 && array->dim2 != 0) {
        if (index1 >= 0 && index1 <= ((tb_value_t)(array->dim1)) &&
                index2 >= 0 && index2 <= ((tb_value_t)(array->dim2))) {
            return array->offset +
                   index1 * (sizeof(tb_value_t) * (array->dim1 + 1)) +
                   index2 * sizeof(tb_value_t);
        } else {
            tb_error(state, TB_E_SUBSCRIPT);
        }
    } else {
        tb_error(state, TB_E_NOTARRAY);
    }
    return 0;
}

static uint16_t tb_allocate(tb_state_t *state, int64_t size)
{
    uint16_t offset = state->next_alloc;
    int64_t avail = ((int64_t)TB_MAX_PROGRAM) - offset;
    size *= sizeof(tb_value_t);
    if (size > avail) {
        return 0;
    }
    state->next_alloc += (uint16_t)size;
    memset(state->program + offset, 0, (size_t)size);
    return offset;
}

void tb_dim_1d(tb_state_t *state, tb_value_t ref, tb_value_t dim)
{
    tb_array_t *array = tb_get_array(state, ref);
    if (!array) {
        tb_error(state, TB_E_IL);
    } else if (array->dim1 != 0) {
        tb_error(state, TB_E_REDIM);
    } else if (dim <= 0) {
        tb_error(state, TB_E_INVDIM);
    } else if ((array->offset = tb_allocate
                    (state, ((int64_t)dim) + 1)) == 0) {
        tb_error(state, TB_E_MEMORY);
    } else {
        array->dim1 = dim;
        array->dim2 = 0;
    }
}

void tb_dim_2d
    (tb_state_t *state, tb_value_t ref, tb_value_t dim1, tb_value_t dim2)
{
    tb_array_t *array = tb_get_array(state, ref);
    if (!array) {
        tb_error(state, TB_E_IL);
    } else if (array->dim1 != 0) {
        tb_error(state, TB_E_REDIM);
    } else if (dim1 <= 0 || dim2 <= 0) {
        tb_error(state, TB_E_INVDIM);
    } else if ((array->offset = tb_allocate
                    (state, (((int64_t)dim1) + 1) *
                            (((int64_t)dim2) + 1))) == 0) {
        tb_error(state, TB_E_MEMORY);
    } else {
        array->dim1 = dim1;
        array->dim2 = dim2;
    }
}
