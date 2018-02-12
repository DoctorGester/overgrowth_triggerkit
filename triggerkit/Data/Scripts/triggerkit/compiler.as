enum Expression_Type {
    EXPRESSION_LITERAL,
    EXPRESSION_DECLARATION,
    EXPRESSION_ASSIGNMENT,
    EXPRESSION_IDENTIFIER,
    EXPRESSION_OPERATOR,

    EXPRESSION_WHILE,
    EXPRESSION_REPEAT,
    EXPRESSION_IF,
    EXPRESSION_RETURN,

    EXPRESSION_CALL
}

enum Operator_Type {
    OPERATOR_OR,
    OPERATOR_AND,

    OPERATOR_ADD,
    OPERATOR_SUB,
    OPERATOR_MUL,
    OPERATOR_DIV,

    OPERATOR_EQ,
    OPERATOR_GT,
    OPERATOR_LT,

    OPERATOR_LAST
}

enum Literal_Type {
    LITERAL_TYPE_VOID,
    LITERAL_TYPE_NUMBER,
    LITERAL_TYPE_STRING,
    LITERAL_TYPE_BOOL,
    LITERAL_TYPE_OBJECT,
    LITERAL_TYPE_ITEM,
    LITERAL_TYPE_HOTSPOT,
    LITERAL_TYPE_CHARACTER,
    LITERAL_TYPE_VECTOR,
    LITERAL_TYPE_FUNCTION,
    LITERAL_TYPE_ARRAY,
    LITERAL_TYPE_LAST
}

class Translation_Context {
    array<Function_Definition@>@ function_definitions;

    dictionary native_function_indices;
    dictionary user_function_indices;
    array<Function_Translation_Unit> translation_stack;
    array<Native_Function_Executor@> function_executors;
    array<Memory_Cell> constants;
    array<Instruction> code;

    uint main_function_pointer = 0;

    uint expressions_translated = 0;
}

class Function_Translation_Unit {
    uint local_variable_index = 0;
    Variable_Scope@ variable_scope;
    Function_Definition@ definition;
}

class Variable_Scope {
    Variable_Scope@ parent_scope;

    dictionary local_variable_indices;
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

Function_Translation_Unit@ get_current_function_translation_unit(Translation_Context@ ctx) {
    return ctx.translation_stack[ctx.translation_stack.length() - 1];
}

void push_function_translation_unit(Translation_Context@ ctx, Function_Definition@ function_definition) {
    Function_Translation_Unit unit;

    @unit.definition = function_definition;

    ctx.translation_stack.insertLast(unit);
}

void push_variable_scope(Translation_Context@ ctx) {
    Function_Translation_Unit@ translation_unit = get_current_function_translation_unit(ctx);

    Variable_Scope new_scope;
    @new_scope.parent_scope = translation_unit.variable_scope;

    @translation_unit.variable_scope = new_scope;
}

void pop_variable_scope(Translation_Context@ ctx) {
    Function_Translation_Unit@ translation_unit = get_current_function_translation_unit(ctx);

    @translation_unit.variable_scope = translation_unit.variable_scope.parent_scope;
}

Function_Translation_Unit@ pop_function_translation_unit(Translation_Context@ ctx) {
    Function_Translation_Unit@ last_value = get_current_function_translation_unit(ctx);
    
    ctx.translation_stack.removeLast();

    return last_value;
}

uint get_local_index_and_advance(Translation_Context@ ctx) {
    return get_current_function_translation_unit(ctx).local_variable_index++;
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

Function_Definition@ find_function_definition(Translation_Context@ ctx, string name) {
    for (uint function_index = 0; function_index < ctx.function_definitions.length(); function_index++) {
        if (ctx.function_definitions[function_index].function_name == name) {
            return ctx.function_definitions[function_index];
        }
    }

    return null;
}

uint find_or_declare_native_function_index(Translation_Context@ ctx, Function_Definition@ function_definition) {
    string name = function_definition.function_name;

    if (ctx.native_function_indices.exists(name)) {
        return uint(ctx.native_function_indices[name]);
    }

    uint new_index = ctx.function_executors.length();

    ctx.native_function_indices[name] = new_index;
    ctx.function_executors.insertLast(function_definition.native_executor);

    return new_index;
}

uint find_user_function_index(Translation_Context@ ctx, Function_Definition@ function_definition) {
    string name = function_definition.function_name;

    if (ctx.user_function_indices.exists(name)) {
        return uint(ctx.user_function_indices[name]);
    }

    Log(error, "Function index not found: " + function_definition.function_name);
    assert(false);

    return 0;
}

uint declare_local_variable_and_advance(Translation_Context@ ctx, string name) {
    uint new_index = get_local_index_and_advance(ctx);

    get_current_function_translation_unit(ctx).variable_scope.local_variable_indices[name] = new_index;

    return new_index;
}

void emit_instruction(Instruction@ instruction, array<Instruction>@ target) {
    target.insertLast(instruction);
}

void emit_block(Translation_Context@ ctx, array<Expression@>@ expressions) {
    push_variable_scope(ctx);

    for (uint block_expr_index = 0; block_expr_index < expressions.length(); block_expr_index++) {
        emit_expression_bytecode(ctx, expressions[block_expr_index], true);
    }

    pop_variable_scope(ctx);
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

int find_variable_location_hierarchical(Variable_Scope@ in_scope, string name, bool& reached_root_scope) {
    if (in_scope.local_variable_indices.exists(name)) {
        if (in_scope.parent_scope is null) {
            reached_root_scope = true;
        }

        return int(uint(in_scope.local_variable_indices[name])); // TODO is double cast necessary? Need testing
    }

    if (in_scope.parent_scope is null) {
        return -1;
    } else {
        return find_variable_location_hierarchical(in_scope.parent_scope, name, reached_root_scope);
    }
}

uint find_variable_location(Translation_Context@ ctx, string name, bool& reached_root_scope) {
    Function_Translation_Unit@ current_function_translation_unit = get_current_function_translation_unit(ctx);

    int variable_location = find_variable_location_hierarchical(current_function_translation_unit.variable_scope, name, reached_root_scope);

    assert(variable_location != -1);

    return uint(variable_location);
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

uint emit_user_function(Translation_Context@ ctx, Function_Definition@ function_definition, array<Expression@>@ expressions) {
    uint function_location = ctx.code.length();

    push_function_translation_unit(ctx, function_definition);
    push_variable_scope(ctx);

    // TODO dirty, function can be anonymous but still contain arguments!
    if (function_definition !is null) {
        for (uint argument_index = 0; argument_index < function_definition.argument_names.length(); argument_index++) {
            declare_local_variable_and_advance(ctx, function_definition.argument_names[argument_index]);
        }
    }

    uint reserve_location = ctx.code.length();
    emit_instruction(make_instruction(INSTRUCTION_TYPE_RESERVE), ctx.code); 

    for (uint block_expr_index = 0; block_expr_index < expressions.length(); block_expr_index++) {
        emit_expression_bytecode(ctx, expressions[block_expr_index], true);
    }

    pop_variable_scope(ctx);
    Function_Translation_Unit@ popped_unit = pop_function_translation_unit(ctx);

    uint function_reserved_space = popped_unit.local_variable_index;
    emit_instruction(make_instruction(INSTRUCTION_TYPE_RESERVE, -function_reserved_space), ctx.code); 
    ctx.code[reserve_location].int_arg = function_reserved_space;

    emit_instruction(make_instruction(INSTRUCTION_TYPE_RET), ctx.code);

    return function_location;
}

void emit_expression_bytecode(Translation_Context@ ctx, Expression@ expression, bool is_parent_a_block = false) {
    ctx.expressions_translated++;

    array<Instruction>@ target = ctx.code;

    switch (expression.type) {
        case EXPRESSION_LITERAL: {
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
            bool is_global = false;
            uint slot = find_variable_location(ctx, expression.identifier_name, is_global);
            emit_instruction(make_load_instruction(slot), target);

            if (is_global) {
                emit_instruction(make_load_instruction(slot), target);
            } else {
                emit_instruction(make_global_load_instruction(slot), target);
            }

            break;
        }

        case EXPRESSION_DECLARATION: {
            uint slot = declare_local_variable_and_advance(ctx, expression.identifier_name);
            emit_expression_bytecode(ctx, expression.value_expression); // TODO make this optional?
            emit_instruction(make_store_instruction(slot), target);

            break;
        }

        case EXPRESSION_ASSIGNMENT: {
            bool is_global = false;
            uint slot = find_variable_location(ctx, expression.identifier_name, is_global);

            emit_expression_bytecode(ctx, expression.value_expression);

            if (is_global) {
                emit_instruction(make_store_instruction(slot), target);
            } else {
                emit_instruction(make_global_store_instruction(slot), target);
            }

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

        case EXPRESSION_CALL: {
            Function_Definition@ function_definition = find_function_definition(ctx, expression.identifier_name);

            if (function_definition is null) {
                Log(error, "Function not found in the API: " + expression.identifier_name);
                assert(false);
            }

            if (function_definition.native) {
                for (int argument_index = expression.arguments.length() - 1; argument_index >= 0; argument_index--) {
                    emit_expression_bytecode(ctx, expression.arguments[argument_index]);
                }

                uint function_index = find_or_declare_native_function_index(ctx, function_definition);

                // Log(info, "Declared native " + function_definition.function_name + " as " + function_index);

                emit_instruction(make_native_call_instruction(function_index), target);
            } else {
                uint function_index = find_user_function_index(ctx, function_definition);

                // Log(info, "Declared " + function_definition.function_name + " as " + function_index);

                // TODO Is this the right way to reserve space for a return value?
                if (function_definition.return_type != LITERAL_TYPE_VOID) {
                    emit_instruction(make_instruction(INSTRUCTION_TYPE_CONST_0), target);
                }

                for (int argument_index = expression.arguments.length() - 1; argument_index >= 0; argument_index--) {
                    emit_expression_bytecode(ctx, expression.arguments[argument_index]);
                }

                emit_instruction(make_user_call_instruction(function_index), target);
            }

            if (is_parent_a_block && function_definition.return_type != LITERAL_TYPE_VOID) {
                emit_instruction(make_instruction(INSTRUCTION_TYPE_POP), target);
            }

            break;
        }

        case EXPRESSION_RETURN: {
            // TODO also emit a RET instruction there!
            emit_expression_bytecode(ctx, expression.value_expression);
            emit_instruction(make_instruction(INSTRUCTION_TYPE_RETURN), target);

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

        case EXPRESSION_WHILE: {
            uint jmp_into_condition_location = emit_placeholder_jmp_instruction(target);
            uint while_block_start = target.length();

            emit_block(ctx, expression.block_body);

            target[jmp_into_condition_location].int_arg = target.length() - jmp_into_condition_location;

            emit_expression_bytecode(ctx, expression.value_expression);
            emit_instruction(make_jmp_if_instruction(while_block_start - target.length()), target);

            break;
        }

        default: {
            Log(error, "Ignored expression of type :: " + expression.type);
            break;
        }
    }
}

// TODO don't need extra versions of those!
Translation_Context@ translate_expressions_into_bytecode(array<Expression@>@ expressions) {
    return translate_expressions_into_bytecode(null, expressions);
}

Translation_Context@ translate_expressions_into_bytecode(Function_Definition@ entry_function_definition) {
    return translate_expressions_into_bytecode(entry_function_definition, entry_function_definition.user_code);
}

Translation_Context@ translate_expressions_into_bytecode(Function_Definition@ entry_function_definition, array<Expression@>@ expressions) {
    Translation_Context translation_context;

    Api_Builder@ api_builder = build_api();
    @translation_context.function_definitions = api_builder.functions;

    Log(info, "Compilation started");

    // TODO First emit dummy user function calls, then backpatch them to enable calling not defined functions!
    // TODO First emit dummy user function calls, then backpatch them to enable calling not defined functions!
    // TODO First emit dummy user function calls, then backpatch them to enable calling not defined functions!
    // TODO First emit dummy user function calls, then backpatch them to enable calling not defined functions!
    // TODO First emit dummy user function calls, then backpatch them to enable calling not defined functions!

    for (uint function_index = 0; function_index < translation_context.function_definitions.length(); function_index++) {
        Function_Definition@ function = translation_context.function_definitions[function_index];

        if (!function.native) {
            uint function_location = emit_user_function(translation_context, function, function.user_code);
            uint const_id = find_or_save_number_const(translation_context, function_location);

            // TODO Saving consts contigiously in memory, dirty! Possible solutions?
            translation_context.constants.insertLast(make_memory_cell(function.argument_types.length));

            translation_context.user_function_indices[function.function_name] = const_id;
        }
    }

    // Emit main
    translation_context.main_function_pointer = emit_user_function(translation_context, entry_function_definition, expressions);

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

Instruction@ make_instruction(Instruction_Type type, int int_arg) {
    Instruction instruction;
    instruction.type = type;
    instruction.int_arg = int_arg;

    return instruction;
}

Instruction@ make_native_call_instruction(uint func_id) {
    Instruction@ instruction = make_instruction(INSTRUCTION_TYPE_NATIVE_CALL);
    instruction.int_arg = func_id;

    return instruction;
}

Instruction@ make_user_call_instruction(uint func_id) {
    Instruction@ instruction = make_instruction(INSTRUCTION_TYPE_CALL);
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

Instruction@ make_global_load_instruction(uint from_location) {
    Instruction instruction = make_instruction(INSTRUCTION_TYPE_GLOBAL_LOAD);
    instruction.int_arg = from_location;

    return instruction;
}

Instruction@ make_global_store_instruction(uint to_location) {
    Instruction instruction = make_instruction(INSTRUCTION_TYPE_GLOBAL_STORE);
    instruction.int_arg = to_location;

    return instruction;
}