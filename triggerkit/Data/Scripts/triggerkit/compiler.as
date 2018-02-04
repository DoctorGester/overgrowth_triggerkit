class Translation_Context {
    dictionary api;

    dictionary native_function_indices;
    dictionary local_variable_indices; // TODO this is incorrect because it's not hierarchical, this should be remade into a stack
    uint local_variable_index = 0;
    array<Native_Function_Executor@> native_functions;
    array<Memory_Cell> constants;
    array<Instruction> code;

    uint expressions_translated = 0;
}

Memory_Cell@ make_memory_cell(float number_value) {
    Memory_Cell cell;
    cell.number_value = number_value;

    return cell;
}

Memory_Cell@ make_memory_cell(bool bool_value) {
    Memory_Cell cell;
    cell.number_value = bool_to_number(bool_value);

    return cell;
}

Memory_Cell@ make_memory_cell(string string_value) {
    Memory_Cell cell;
    cell.string_value = string_value;

    return cell;
}

uint get_local_index_and_advance(Translation_Context@ ctx) {
    return ctx.local_variable_index++;
}

uint find_or_save_number_const(Translation_Context@ ctx, float value) {
    for (uint index = 0; index < ctx.constants.length(); index++) {
        if (ctx.constants[index].number_value == value) {
            return index;
        }
    }

    uint new_index = ctx.constants.length();
    ctx.constants.insertLast(make_memory_cell(value));

    return new_index;
}

uint find_or_save_string_const(Translation_Context@ ctx, string value) {
    for (uint index = 0; index < ctx.constants.length(); index++) {
        if (ctx.constants[index].string_value == value) {
            return index;
        }
    }

    uint new_index = ctx.constants.length();
    ctx.constants.insertLast(make_memory_cell(value));

    return new_index;
}

uint find_or_declare_native_function(Translation_Context@ ctx, string name) {
    if (!ctx.api.exists(name)) {
        Log(error, "Function not found in the API: " + name);
        assert(false);
    }

    if (ctx.native_function_indices.exists(name)) {
        return uint(ctx.native_function_indices[name]);
    }

    uint new_index = ctx.native_functions.length();

    ctx.native_function_indices[name] = new_index;
    ctx.native_functions.insertLast(cast<Native_Function_Executor@>(ctx.api[name]));

    return new_index;
}

uint declare_local_variable_and_advance(Translation_Context@ ctx, string name) {
    uint new_index = get_local_index_and_advance(ctx);

    ctx.local_variable_indices[name] = new_index;

    return new_index;
}

void emit_instruction(Instruction@ instruction, array<Instruction>@ target) {
    target.insertLast(instruction);
}

void emit_block(Translation_Context@ ctx, array<Expression@>@ expressions) {
    for (uint block_expr_index = 0; block_expr_index < expressions.length(); block_expr_index++) {
        emit_expression_bytecode(ctx, expressions[block_expr_index], true);
    }
}

uint emit_placeholder_jmp_instruction(array<Instruction>@ target) {
    uint location = target.length();
    emit_instruction(make_jmp_instruction(0), target);

    return location;
}

uint emit_placeholder_jmp_if_instruction(array<Instruction>@ target) {
    uint location = target.length();
    emit_instruction(make_jmp_if_instruction(0), target);

    return location;
}

uint find_variable_location(Translation_Context@ ctx, string name) {
    assert(ctx.local_variable_indices.exists(name));

    return uint(ctx.local_variable_indices[name]);;
}

Instruction_Type operator_type_to_instruction_type(Operator_Type operator_type) {
    switch (operator_type) {
        case OPERATOR_EQ: return INSTRUCTION_TYPE_EQ;
        case OPERATOR_GT: return INSTRUCTION_TYPE_GT;
        case OPERATOR_LT: return INSTRUCTION_TYPE_LT;
        case OPERATOR_ADD: return INSTRUCTION_TYPE_ADD;
        case OPERATOR_SUB: return INSTRUCTION_TYPE_SUB;
    }

    Log(error, "Unhandled operator type " + operator_type);
    return INSTRUCTION_TYPE_ADD;
}

void emit_expression_bytecode(Translation_Context@ ctx, Expression@ expression, bool is_parent_a_block = false) {
    ctx.expressions_translated++;

    array<Instruction>@ target = ctx.code;

    switch (expression.type) {
        case EXPRESSION_LITERAL: {
            // TODO if literal type == double/string then storeconst and load
            switch (expression.literal_type) {
                case LITERAL_TYPE_NUMBER: {
                    float value = expression.literal_value.number_value;

                    if (value == 0) {
                        emit_instruction(make_instruction(INSTRUCTION_TYPE_CONST_0), target);
                    } else if (value == 1) {
                        emit_instruction(make_instruction(INSTRUCTION_TYPE_CONST_1), target);
                    } else {
                        uint const_id = find_or_save_number_const(ctx, value);
                        emit_instruction(make_load_const_instruction(const_id), target);
                    }

                    break;
                }

                case LITERAL_TYPE_STRING: {
                    uint const_id = find_or_save_string_const(ctx, expression.literal_value.string_value);
                    emit_instruction(make_load_const_instruction(const_id), target);

                    break;
                }

                default: {
                    Log(error, "Unhandled literal of type " + literal_type_to_ui_string(expression.literal_type));
                }
            }

            break;
        }

        case EXPRESSION_IDENTIFIER: {
            uint slot = find_variable_location(ctx, expression.identifier_name);
            emit_instruction(make_load_instruction(slot), target);

            break;
        }

        case EXPRESSION_DECLARATION: {
            uint slot = declare_local_variable_and_advance(ctx, expression.identifier_name);
            emit_expression_bytecode(ctx, expression.value_expression); // TODO make this optional?
            emit_instruction(make_store_instruction(slot), target);

            break;
        }

        case EXPRESSION_ASSIGNMENT: {
            uint slot = find_variable_location(ctx, expression.identifier_name);

            emit_expression_bytecode(ctx, expression.value_expression);
            emit_instruction(make_store_instruction(slot), target);

            break;
        }

        case EXPRESSION_OPERATOR: {
            switch (expression.operator_type) {
                case OPERATOR_OR: {
                    emit_expression_bytecode(ctx, expression.left_operand);
                    emit_instruction(make_instruction(INSTRUCTION_TYPE_EQ_NOT_ZERO), target); // if true
                    uint jmp_into_true_location = emit_placeholder_jmp_if_instruction(target);

                    emit_expression_bytecode(ctx, expression.right_operand);
                    emit_instruction(make_instruction(INSTRUCTION_TYPE_EQ_ZERO), target); // if false
                    uint jmp_into_false_location = emit_placeholder_jmp_if_instruction(target);

                    target[jmp_into_true_location].int_arg = target.length() - jmp_into_true_location;
                    emit_instruction(bool_to_load_const(true), target);
                    uint jmp_over_location = emit_placeholder_jmp_instruction(target);

                    target[jmp_into_false_location].int_arg = target.length() - jmp_into_false_location;
                    emit_instruction(bool_to_load_const(false), target);

                    target[jmp_over_location].int_arg = target.length() - jmp_over_location;
                    break;
                }

                case OPERATOR_AND: {
                    emit_expression_bytecode(ctx, expression.left_operand);
                    emit_instruction(make_instruction(INSTRUCTION_TYPE_EQ_ZERO), target); // if false
                    uint jmp_into_false_location = emit_placeholder_jmp_if_instruction(target);

                    emit_expression_bytecode(ctx, expression.right_operand);
                    emit_instruction(make_instruction(INSTRUCTION_TYPE_EQ_NOT_ZERO), target); // if true
                    uint jmp_into_true_location = emit_placeholder_jmp_if_instruction(target);

                    target[jmp_into_false_location].int_arg = target.length() - jmp_into_false_location;
                    emit_instruction(bool_to_load_const(false), target);
                    uint jmp_over_location = emit_placeholder_jmp_instruction(target);

                    target[jmp_into_true_location].int_arg = target.length() - jmp_into_true_location;
                    emit_instruction(bool_to_load_const(true), target);

                    target[jmp_over_location].int_arg = target.length() - jmp_over_location;
                    break;
                }

                default: {
                    emit_expression_bytecode(ctx, expression.left_operand);
                    emit_expression_bytecode(ctx, expression.right_operand);
                    emit_instruction(make_instruction(operator_type_to_instruction_type(expression.operator_type)), target);
                }
            }

            break;
        }

        case EXPRESSION_IF: {
            emit_expression_bytecode(ctx, expression.value_expression);

            uint jmp_into_if_location = emit_placeholder_jmp_if_instruction(target);

            emit_block(ctx, expression.else_block_body);

            uint jmp_over_the_whole_if_location = emit_placeholder_jmp_instruction(target);

            target[jmp_into_if_location].int_arg = target.length() - jmp_into_if_location;

            emit_block(ctx, expression.block_body);

            target[jmp_over_the_whole_if_location].int_arg = target.length() - jmp_over_the_whole_if_location;

            break;
        }

        case EXPRESSION_NATIVE_CALL: {
            uint function_id = find_or_declare_native_function(ctx, expression.identifier_name);

            for (int argument_index = expression.arguments.length() - 1; argument_index >= 0; argument_index--) {
                emit_expression_bytecode(ctx, expression.arguments[argument_index]);
            }

            emit_instruction(make_native_call_instruction(function_id), target);

            if (is_parent_a_block) {
                // TODO emit a POP if a function has a return value
            }

            break;
        }

        case EXPRESSION_REPEAT: {
            uint counter_location = get_local_index_and_advance(ctx);

            emit_expression_bytecode(ctx, expression.value_expression);
            emit_instruction(make_store_instruction(counter_location), target); // save counter

            uint repeat_block_start = target.length();

            emit_block(ctx, expression.block_body);

            emit_instruction(make_load_instruction(counter_location), target); // load counter
            emit_instruction(make_instruction(INSTRUCTION_TYPE_DEC), target); // counter--
            emit_instruction(make_instruction(INSTRUCTION_TYPE_DUP), target);
            emit_instruction(make_store_instruction(counter_location), target); // save counter back
            emit_instruction(make_instruction(INSTRUCTION_TYPE_EQ_ZERO), target); // counter != 0
            emit_instruction(make_instruction(INSTRUCTION_TYPE_NOT), target);
            emit_instruction(make_jmp_if_instruction(repeat_block_start - target.length()), target);

            break;
        }

        default: {
            Log(error, "Ignored expression of type :: " + expression.type);
            break;
        }
    }
}

Translation_Context@ translate_expressions_into_bytecode(array<Expression@>@ expressions) {
    Translation_Context translation_context;
    populate_native_functions(translation_context.api);

    emit_block(translation_context, expressions);

    return translation_context;
}

Instruction@ bool_to_load_const(bool value) {
    return value ? make_instruction(INSTRUCTION_TYPE_CONST_1) : make_instruction(INSTRUCTION_TYPE_CONST_0);
}

Instruction@ make_instruction(Instruction_Type type) {
    Instruction instruction;
    instruction.type = type;

    return instruction;
}

Instruction@ make_native_call_instruction(uint func_id) {
    Instruction@ instruction = make_instruction(INSTRUCTION_TYPE_NATIVE_CALL);
    instruction.int_arg = func_id;

    return instruction;
}

Instruction@ make_load_const_instruction(uint const_id) {
    Instruction@ instruction = make_instruction(INSTRUCTION_TYPE_LOAD_CONST);
    instruction.int_arg = const_id;

    return instruction;
}

Instruction@ make_jmp_instruction(int to) {
    Instruction instruction = make_instruction(INSTRUCTION_TYPE_JMP);
    instruction.int_arg = to;

    return instruction;
}

Instruction@ make_jmp_if_instruction(int to) {
    Instruction instruction = make_instruction(INSTRUCTION_TYPE_JMP_IF);
    instruction.int_arg = to;

    return instruction;
}

Instruction@ make_load_instruction(uint from_location) {
    Instruction instruction = make_instruction(INSTRUCTION_TYPE_LOAD);
    instruction.int_arg = from_location;

    return instruction;
}

Instruction@ make_store_instruction(uint to_location) {
    Instruction instruction = make_instruction(INSTRUCTION_TYPE_STORE);
    instruction.int_arg = to_location;

    return instruction;
}