class Parser_State {
    array<string> words;
    uint current_word = 0;
}

string parser_next_word(Parser_State@ state) {
    return state.words[state.current_word++];
}

bool has_finished_parsing(Parser_State@ state) {
    return state.current_word >= state.words.length(); 
}

// Serialization
const string KEYWORD_TRIGGER = "trigger";
const string KEYWORD_DESCRIPTION = "description";
const string KEYWORD_EVENT = "event";
const string KEYWORD_ACTIONS = "actions";
const string KEYWORD_CONDITIONS = "conditions";
const string KEYWORD_VARIABLES = "variables";

// Actual syntax
const string KEYWORD_LITERAL = "$";
const string KEYWORD_IDENTIFIER = "@";
const string KEYWORD_OPERATOR = "op";
const string KEYWORD_DECLARE = "declare";
const string KEYWORD_ASSIGN = "assign";
const string KEYWORD_CALL = "call";
const string KEYWORD_REPEAT = "repeat";
const string KEYWORD_WHILE = "while";
const string KEYWORD_FORK = "fork";
const string KEYWORD_IF = "if";
const string KEYWORD_ELSE = "else";
const string KEYWORD_RETURN = "return";
const string KEYWORD_START_BLOCK = "(";
const string KEYWORD_END_BLOCK = ")";

// TODO Performance!
Event_Type serializeable_string_to_event_type(string text) {
    for (uint type_as_int = 0; type_as_int < EVENT_LAST; type_as_int++) {
        if (event_type_to_serializeable_string(Event_Type(type_as_int)) == text) {
            return Event_Type(type_as_int);
        }
    }

    Log(error, "Can't deserialize " + text + " to event type");

    return EVENT_LAST;
}

// TODO Performance!
Operator_Type serializeable_string_to_operator_type(string text) {
    for (uint type_as_int = 0; type_as_int < OPERATOR_LAST; type_as_int++) {
        if (operator_type_to_serializeable_string(Operator_Type(type_as_int)) == text) {
            return Operator_Type(type_as_int);
        }
    }

    Log(error, "Can't deserialize " + text + " to operator type");

    return OPERATOR_LAST;
}

// TODO Performance!
Literal_Type serializeable_string_to_literal_type(string text) {
    for (uint type_as_int = 0; type_as_int < LITERAL_TYPE_LAST; type_as_int++) {
        if (literal_type_to_serializeable_string(Literal_Type(type_as_int)) == text) {
            return Literal_Type(type_as_int);
        }
    }

    Log(error, "Can't deserialize " + text + " to literal type");

    return LITERAL_TYPE_LAST;
}

// Does not support strings starting with a space, does it need to?
array<string> split_into_words_and_quoted_pieces(string text) {
    array<string> result;
    string buffer = "";
    bool inside_quotes = false;
    bool last_character_was_backslash = false;
    bool was_in_quotes = false;

    const uint8 space = " "[0];
    const uint8 double_quote = "\""[0];
    const uint8 back_slash = "\\"[0];
    const uint8 line_break = "\n"[0];
    const uint8 tab = "\t"[0];

    for (uint index = 0; index < text.length(); index++) {
        bool should_append_this_character = true;
        uint8 character = text[index];

        if (inside_quotes) {
            if (character == double_quote && !last_character_was_backslash) {
                inside_quotes = false;
                should_append_this_character = false;
            }

            if (character == back_slash && index < text.length() - 1 && text[index + 1] == double_quote) { 
                should_append_this_character = false;
            }
        } else {
            if (character == double_quote && !last_character_was_backslash) {
                inside_quotes = true;
                was_in_quotes = true;
                should_append_this_character = false;
            }

            if (character == space || character == line_break || character == tab) {
                if (buffer.length() > 0 || was_in_quotes) {
                    result.insertLast(buffer);
                    buffer = "";
                }

                was_in_quotes = false;
                should_append_this_character = false;
            }
        }

        last_character_was_backslash = (character == back_slash);

        if (should_append_this_character) {
            string character_holder('0');
            character_holder[0] = text[index]; // What a language
            buffer += character_holder;
        }
    }

    if (buffer.length() > 0 || was_in_quotes) {
        result.insertLast(buffer);
    }

    return result;
}

Expression@ parse_literal_value_from_string(Literal_Type literal_type, Parser_State@ state) {
    switch (literal_type) {
        case LITERAL_TYPE_NUMBER: return make_lit(parseFloat(parser_next_word(state)));
        case LITERAL_TYPE_STRING: return make_lit(parser_next_word(state));
        case LITERAL_TYPE_BOOL: return make_lit("True" == parser_next_word(state));
        case LITERAL_TYPE_VECTOR_3: {
            float x = parseFloat(parser_next_word(state));
            float y = parseFloat(parser_next_word(state));
            float z = parseFloat(parser_next_word(state));

            return make_lit(vec3(x, y, z));
        }

        default: {
            Log(error, "Unsupported literal type " + literal_type_to_serializeable_string(literal_type));
        }
    }

    return null;
}

Expression@ parse_words_into_expression(Parser_State@ state) {
    string word = parser_next_word(state);

    if (word == KEYWORD_DECLARE) {
        string type_name = parser_next_word(state);
        string identifier_name = parser_next_word(state);

        Expression@ value_expression = parse_words_into_expression(state);

        return make_declaration(serializeable_string_to_literal_type(type_name), identifier_name, value_expression);
    } else if (word == KEYWORD_LITERAL) {
        Literal_Type literal_type = serializeable_string_to_literal_type(parser_next_word(state));

        return parse_literal_value_from_string(literal_type, state);
    } else if (word == KEYWORD_IDENTIFIER) {
        string identifier_name = parser_next_word(state);

        return make_ident(identifier_name);
    } else if (word == KEYWORD_ASSIGN) {
        string identifier_name = parser_next_word(state);
        Expression@ value_expression = parse_words_into_expression(state);

        return make_assignment(identifier_name, value_expression);
    } else if (word == KEYWORD_OPERATOR) {
        string operator_as_string = parser_next_word(state);
        Expression@ left_operand = parse_words_into_expression(state);
        Expression@ right_operand = parse_words_into_expression(state);

        return make_op_expr(serializeable_string_to_operator_type(operator_as_string), left_operand, right_operand);
    } else if (word == KEYWORD_CALL) {
        string identifier_name = parser_next_word(state);

        Expression@ call = make_function_call(identifier_name);
        parse_words_into_expression_array(state, call.arguments);

        return call;
    } else if (word == KEYWORD_RETURN) {
        Expression@ value_expression = parse_words_into_expression(state);

        return make_return(value_expression);
    } else if (word == KEYWORD_IF) {
        Expression@ value_expression = parse_words_into_expression(state);
        Expression@ if_statement = make_if(value_expression);

        parse_words_into_expression_array(state, if_statement.block_body);
        parser_next_word(state); // Else

        parse_words_into_expression_array(state, if_statement.else_block_body);

        return if_statement;
    } else if (word == KEYWORD_REPEAT) {
        Expression@ value_expression = parse_words_into_expression(state);

        Expression@ repeat = Expression();
        repeat.type = EXPRESSION_REPEAT;
        @repeat.value_expression = value_expression;

        parse_words_into_expression_array(state, repeat.block_body);

        return repeat;
    } else if (word == KEYWORD_WHILE) {
        Expression@ value_expression = parse_words_into_expression(state);

        Expression@ expression_while = Expression();
        expression_while.type = EXPRESSION_WHILE;
        @expression_while.value_expression = value_expression;

        parse_words_into_expression_array(state, expression_while.block_body);

        return expression_while;
    } else if (word == KEYWORD_FORK) {
        Expression@ fork = Expression();
        fork.type = EXPRESSION_FORK;

        parse_words_into_expression_array(state, fork.block_body);

        return fork;
    }

    return make_ident(word);
}

void parse_words_into_expression_array(Parser_State@ state, array<Expression@>@ target) {
    parser_next_word(state);

    if (state.words[state.current_word] == KEYWORD_END_BLOCK) {
        state.current_word++;
        return;
    }

    while (true) {
        target.insertLast(parse_words_into_expression(state));

        if (state.words[state.current_word] == KEYWORD_END_BLOCK) {
            state.current_word++;
            break;
        }
    }
}