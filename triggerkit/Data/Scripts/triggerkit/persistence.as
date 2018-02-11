const string LEVEL_PARAM_WITH_TRIGGER_CONTENT_NAME = "TriggerKit/Triggers";

string serialize_triggers_into_string(array<Trigger@>@ triggers) {
    array<string> triggers_as_text;

    for (uint trigger_index = 0; trigger_index < state.triggers.length(); trigger_index++) {
        Trigger@ trigger = state.triggers[trigger_index];
        array<Expression@>@ code = trigger.actions;

        string trigger_metadata = KEYWORD_TRIGGER + " " + serializeable_string(trigger.name) + "\n" + serializeable_string(trigger.description);
        string trigger_as_text = join(array<string> = {
            KEYWORD_TRIGGER + " " + serializeable_string(trigger.name),
            KEYWORD_DESCRIPTION + " " + serializeable_string(trigger.description),
            KEYWORD_CODE + " " + serialize_expression_block(code, "")
        }, "\n");

        triggers_as_text.insertLast(trigger_as_text);
    }

    return join(triggers_as_text, "\n\n"); 
}

array<Trigger@> parse_triggers_from_string(string from_text) {
    Parser_State state;
    state.words = split_into_words_and_quoted_pieces(from_text);

    array<Trigger@> triggers;
    Trigger@ current_trigger;

    while (!has_finished_parsing(state)) {
        string word = parser_next_word(state);

        if (word == KEYWORD_TRIGGER) {
            @current_trigger = Trigger(parser_next_word(state));
        } else {
            assert(current_trigger !is null);

            if (word == KEYWORD_DESCRIPTION) {
                current_trigger.description = parser_next_word(state);
            } else if (word == KEYWORD_CODE) {
                parse_words_into_expression_array(state, current_trigger.actions);
                triggers.insertLast(current_trigger);
            }
        }
    }

    return triggers;
}

void save_trigger_state_into_level_params(Trigger_Kit_State@ state) {
    ScriptParams@ params = level.GetScriptParams();

    if (params.HasParam(LEVEL_PARAM_WITH_TRIGGER_CONTENT_NAME)) {
        params.Remove(LEVEL_PARAM_WITH_TRIGGER_CONTENT_NAME);
    }

    params.AddString(LEVEL_PARAM_WITH_TRIGGER_CONTENT_NAME, serialize_triggers_into_string(state.triggers));
}

Trigger_Kit_State@ load_trigger_state_from_level_params() {
    Trigger_Kit_State@ state = make_trigger_kit_state();

    ScriptParams@ params = level.GetScriptParams();

    if (params.HasParam(LEVEL_PARAM_WITH_TRIGGER_CONTENT_NAME)) {
        string text = params.GetString(LEVEL_PARAM_WITH_TRIGGER_CONTENT_NAME);

        state.triggers = parse_triggers_from_string(text);
    }

    return state;
}

array<Trigger@> load_triggers_from_level_params() {
    ScriptParams@ params = level.GetScriptParams();

    if (params.HasParam(LEVEL_PARAM_WITH_TRIGGER_CONTENT_NAME)) {
        string text = params.GetString(LEVEL_PARAM_WITH_TRIGGER_CONTENT_NAME);

        return parse_triggers_from_string(text);
    }

    return array<Trigger@>();
}

string operator_type_to_serializeable_string(Operator_Type operator_type) {
    switch (operator_type) {
        case OPERATOR_AND: return "and";
        case OPERATOR_OR: return "or";
        case OPERATOR_EQ: return "is";
        case OPERATOR_GT: return ">";
        case OPERATOR_LT: return "<";
        case OPERATOR_ADD: return "+";
        case OPERATOR_SUB: return "-";
    }

    return "undefined";
}

string literal_type_to_serializeable_string(Literal_Type literal_type) {
    switch (literal_type) {
        case LITERAL_TYPE_VOID: return "Void";
        case LITERAL_TYPE_NUMBER: return "Number";
        case LITERAL_TYPE_STRING: return "String";
        case LITERAL_TYPE_BOOL: return "Bool";
        case LITERAL_TYPE_OBJECT: return "Object";
        case LITERAL_TYPE_ITEM: return "Item";
        case LITERAL_TYPE_HOTSPOT: return "Hotspot";
        case LITERAL_TYPE_CHARACTER: return "Character";
        case LITERAL_TYPE_VECTOR: return "Vector";
        case LITERAL_TYPE_FUNCTION: return "Function";
        case LITERAL_TYPE_ARRAY: return "Array";
    }

    return "unknown";
}

string literal_to_serializeable_string(Expression@ literal) {
    switch (literal.literal_type) {
        case LITERAL_TYPE_NUMBER: return literal.literal_value.number_value + "";
        case LITERAL_TYPE_STRING: return serializeable_string(literal.literal_value.string_value);

        default: {
            Log(error, "Unsupported literal type " + literal_type_to_serializeable_string(literal.literal_type));
        }
    }

    return "not_implemented";
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
            return join(array<string> = {
                KEYWORD_OPERATOR,
                operator_type_to_ui_string(expression.operator_type),
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
                literal_to_serializeable_string(expression)
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
