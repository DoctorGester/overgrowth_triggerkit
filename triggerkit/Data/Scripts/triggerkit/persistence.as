const string LEVEL_PARAM_WITH_TRIGGER_CONTENT_NAME = "TriggerKit/Triggers";

string serialize_trigger_state_into_text(Trigger_Kit_State@ state) {
    array<Trigger@>@ triggers = state.triggers;
    array<string> text_blocks;

    uint total_variables = state.global_variables.length();
    string global_variables_block = KEYWORD_VARIABLES + " " + KEYWORD_START_BLOCK;

    global_variables_block += (total_variables == 0 ? "" : "\n");

    for (uint variable_index = 0; variable_index < total_variables; variable_index++) {
        Variable@ variable = state.global_variables[variable_index];
        global_variables_block = global_variables_block + "\t"
            + literal_type_to_serializeable_string(variable.type) + " "
            + serializeable_string(variable.name) + " "
            + literal_to_serializeable_string(variable.type, variable.value) + "\n";
    }

    global_variables_block += (total_variables == 0 ? " " : "") + KEYWORD_END_BLOCK;

    text_blocks.insertLast(global_variables_block);

    for (uint trigger_index = 0; trigger_index < state.triggers.length(); trigger_index++) {
        Trigger@ trigger = state.triggers[trigger_index];

        string trigger_metadata = KEYWORD_TRIGGER + " " + serializeable_string(trigger.name) + "\n" + serializeable_string(trigger.description);
        string trigger_as_text = join(array<string> = {
            KEYWORD_TRIGGER + " " + serializeable_string(trigger.name) + " " + KEYWORD_START_BLOCK,
            "\t" + KEYWORD_DESCRIPTION + " " + serializeable_string(trigger.description),
            "\t" + KEYWORD_EVENT + " " + event_type_to_serializeable_string(trigger.event_type),
            "\t" + KEYWORD_CONDITIONS + " " + serialize_expression_block(trigger.conditions, "\t"),
            "\t" + KEYWORD_ACTIONS + " " + serialize_expression_block(trigger.actions, "\t"),
            KEYWORD_END_BLOCK
        }, "\n");

        text_blocks.insertLast(trigger_as_text);
    }

    return join(text_blocks, "\n\n"); 
}

void parse_trigger_members(Parser_State@ state, Trigger@ for_trigger) {
    parser_next_word(state);

    if (state.words[state.current_word] == KEYWORD_END_BLOCK) {
        state.current_word++;
        return;
    }

    while (true) {
        string word = parser_next_word(state);

        if (word == KEYWORD_DESCRIPTION) {
            for_trigger.description = parser_next_word(state);
        } else if (word == KEYWORD_ACTIONS) {
            parse_words_into_expression_array(state, for_trigger.actions);
        } else if (word == KEYWORD_CONDITIONS) {
            parse_words_into_expression_array(state, for_trigger.conditions);
        } else if (word == KEYWORD_EVENT) {
            for_trigger.event_type = serializeable_string_to_event_type(parser_next_word(state));
        }

        if (word == KEYWORD_END_BLOCK) {
            break;
        }
    }
}

void parse_variables(Parser_State@ state, array<Variable>@ variables) {
    parser_next_word(state);

    if (state.words[state.current_word] == KEYWORD_END_BLOCK) {
        state.current_word++;
        return;
    }

    while (true) {
        string first_word = parser_next_word(state);

        if (first_word == KEYWORD_END_BLOCK) {
            break;
        }

        Literal_Type literal_type = serializeable_string_to_literal_type(first_word);
        string identifier_name = parser_next_word(state);
        Memory_Cell@ value = parse_literal_value_from_string(literal_type, state).literal_value;

        // TODO make_variable
        Variable variable;
        variable.type = literal_type;
        variable.name = identifier_name;
        variable.value = value;

        variables.insertLast(variable);
    }
}

void parse_text_into_trigger_state(string from_text, Trigger_Kit_State@ state) {
    Parser_State parser;
    parser.words = split_into_words_and_quoted_pieces(from_text);

    while (!has_finished_parsing(parser)) {
        string word = parser_next_word(parser);

        if (word == KEYWORD_VARIABLES) {
            parse_variables(parser, state.global_variables);
        }

        if (word == KEYWORD_TRIGGER) {
            Trigger@ new_trigger = Trigger(parser_next_word(parser));

            parse_trigger_members(parser, new_trigger);

            state.triggers.insertLast(new_trigger);
        }
    }
}

array<Expression@>@ parse_text_into_expression_array(string text) {
    array<Expression@> result;

    Parser_State parser;
    parser.words = split_into_words_and_quoted_pieces(text);

    while (!has_finished_parsing(parser)) {
        result.insertLast(parse_words_into_expression(parser));
    }

    return result;
}

void save_trigger_state_into_level_params(Trigger_Kit_State@ state) {
    ScriptParams@ params = level.GetScriptParams();

    if (params.HasParam(LEVEL_PARAM_WITH_TRIGGER_CONTENT_NAME)) {
        params.Remove(LEVEL_PARAM_WITH_TRIGGER_CONTENT_NAME);
    }

    params.AddString(LEVEL_PARAM_WITH_TRIGGER_CONTENT_NAME, serialize_trigger_state_into_text(state));
}

Trigger_Kit_State@ load_trigger_state_from_level_params() {
    Trigger_Kit_State@ state = make_trigger_kit_state();

    ScriptParams@ params = level.GetScriptParams();

    if (params.HasParam(LEVEL_PARAM_WITH_TRIGGER_CONTENT_NAME)) {
        string text = params.GetString(LEVEL_PARAM_WITH_TRIGGER_CONTENT_NAME);

        parse_text_into_trigger_state(text, state);
    }

    return state;
}

string serializeable_string(string text) {
    const uint8 double_quote = "\""[0];

    for (uint index = 0; index < text.length(); index++) {
        if (text[index] == double_quote) {
            text.insert(index, "\\");
            index++;
        }
    }

    return "\"" + text + "\""; 
}

string serialize_expression_block(array<Expression@>@ block_body, string indent, bool multi_line = true) {
    string block_indent = multi_line ? indent + "    " : "";
    string result;
    string line_break = multi_line ? "\n" : " ";

    result += KEYWORD_START_BLOCK + line_break;

    for (uint expression_index = 0; expression_index < block_body.length(); expression_index++) {
        result += serialize_expression_to_string(block_body[expression_index], block_indent, true) + line_break;
    }

    result += (multi_line ? indent : "") + KEYWORD_END_BLOCK;

    return result;
}

string serialize_expression_to_string(Expression@ expression, string indent, bool from_block = false) {
    string real_indent = from_block ? indent : "";

    if (expression is null) {
        return "not_implemented (n)";
    }

    switch (expression.type) {
        case EXPRESSION_OPERATOR: {
            return real_indent + join(array<string> = {
                KEYWORD_OPERATOR,
                operator_type_to_serializeable_string(expression.operator_type),
                serialize_expression_to_string(expression.left_operand, indent),
                serialize_expression_to_string(expression.right_operand, indent)
            }, " ");
        }

        case EXPRESSION_DECLARATION: {
            return real_indent + join(array<string> = {
                KEYWORD_DECLARE,
                literal_type_to_serializeable_string(expression.literal_type),
                serializeable_string(expression.identifier_name),
                serialize_expression_to_string(expression.value_expression, indent)
            }, " ");
        }
            
        case EXPRESSION_ASSIGNMENT: {
            return real_indent + join(array<string> = {
                KEYWORD_ASSIGN,
                serializeable_string(expression.identifier_name),
                serialize_expression_to_string(expression.value_expression, indent)
            }, " ");
        }

        case EXPRESSION_IDENTIFIER: return KEYWORD_IDENTIFIER + " " + serializeable_string(expression.identifier_name);
        case EXPRESSION_LITERAL: {
            return join(array<string> = {
                KEYWORD_LITERAL,
                literal_type_to_serializeable_string(expression.literal_type),
                literal_to_serializeable_string(expression.literal_type, expression.literal_value)
            }, " ");
        }

        case EXPRESSION_CALL: {
            return real_indent + join(array<string> = {
                KEYWORD_CALL,
                expression.identifier_name,
                serialize_expression_block(expression.arguments, indent, false)
            }, " ");
        }

        case EXPRESSION_RETURN: {
            return real_indent + join(array<string> = {
                KEYWORD_RETURN,
                serialize_expression_to_string(expression.value_expression, indent)
            }, " ");
        }

        case EXPRESSION_REPEAT: {
            return real_indent + join(array<string> = {
                KEYWORD_REPEAT,
                serialize_expression_to_string(expression.value_expression, indent),
                serialize_expression_block(expression.block_body, indent)
            }, " ");
        }

        case EXPRESSION_WHILE: {
            return real_indent + join(array<string> = {
                KEYWORD_WHILE,
                serialize_expression_to_string(expression.value_expression, indent),
                serialize_expression_block(expression.block_body, indent)
            }, " ");
        }

        case EXPRESSION_FORK: {
            return real_indent + join(array<string> = {
                KEYWORD_FORK,
                serialize_expression_block(expression.block_body, indent)
            }, " ");
        }

        case EXPRESSION_IF: {
            return real_indent + join(array<string> = {
                KEYWORD_IF,
                serialize_expression_to_string(expression.value_expression, indent),
                serialize_expression_block(expression.block_body, indent)
            }, " ") + "\n" + real_indent + KEYWORD_ELSE + " " + serialize_expression_block(expression.else_block_body, indent);
        }
    }

    return "not_implemented";
}
