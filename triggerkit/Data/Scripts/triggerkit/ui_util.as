funcdef bool Function_Predicate(Function_Definition@ f);

namespace icons {
    TextureAssetRef image_blank = LoadTexture("Data/Images/triggerkit/ui/image_blank.png", TextureLoadFlags_NoMipmap);

    TextureAssetRef action_variable = LoadTexture("Data/Images/triggerkit/ui/icons/Actions-SetVariables.png", TextureLoadFlags_NoMipmap);
    TextureAssetRef action_logical = LoadTexture("Data/Images/triggerkit/ui/icons/Actions-Logical.png", TextureLoadFlags_NoMipmap);
    TextureAssetRef action_other = LoadTexture("Data/Images/triggerkit/ui/icons/Actions-Nothing.png", TextureLoadFlags_NoMipmap);
    TextureAssetRef action_wait = LoadTexture("Data/Images/triggerkit/ui/icons/Actions-Wait.png", TextureLoadFlags_NoMipmap);
    TextureAssetRef action_dialogue = LoadTexture("Data/Images/triggerkit/ui/icons/Actions-Quest.png", TextureLoadFlags_NoMipmap);
}

string operator_type_to_ui_string(Operator_Type operator_type) {
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

string literal_type_to_ui_string(Literal_Type literal_type) {
    switch(literal_type) {
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

const string default_color = "\x1BFFFFFFFF";
const string keyword_color = "\x1BFFD800FF";
const string type_color = "\x1BB6FF00FF";
const string literal_color = "\x1BFF7FEDFF";
const string string_color = "\x1BFFB27FFF";
const string identifier_color = "\x1BC0C0C0FF";

string colored_keyword(const string keyword) {
    return keyword_color + keyword + default_color;
}

string colored_literal_type(Literal_Type literal_type) {
    return type_color + literal_type_to_ui_string(literal_type) + default_color;
}

string colored_identifier(string identifier_name) {
    return identifier_color + identifier_name + default_color;
}

string literal_to_ui_string(Expression@ literal) {
    switch (literal.literal_type) {

        case LITERAL_TYPE_NUMBER: return literal_color + literal.literal_value.number_value + default_color;
        case LITERAL_TYPE_STRING: return string_color + "\"" + literal.literal_value.string_value + "\"" + default_color;
        case LITERAL_TYPE_BOOL: return literal_color + (number_to_bool(literal.literal_value.number_value) ? "True" : "False") + default_color;

        default: {
            Log(error, "Unsupported literal type " + literal_type_to_ui_string(literal.literal_type));
        }
    }

    return "not_implemented";
}

string function_call_to_string_simple(Expression@ expression) {
    array<string> arguments;
    arguments.resize(expression.arguments.length());

    for (uint argument_index = 0; argument_index < expression.arguments.length(); argument_index++) {
        arguments[argument_index] = expression_to_string(expression.arguments[argument_index]);
    }

    return expression.identifier_name + "(" + join(arguments, ", ") + ")";
}

// TODO speed, can DEFINITELY be cached
// TODO speed, can DEFINITELY be cached
// TODO speed, can DEFINITELY be cached
array<string>@ split_function_format_string_into_pieces(string format) {
    array<string> result;

    int character_index = 0;

    while (true) {
        int new_character_index = format.findFirst("{}", character_index);

        if (new_character_index != -1) {
            result.insertLast(format.substr(character_index, new_character_index - character_index));
        } else {
            if (character_index == 0) {
                result.insertLast(format);
            } else {
                result.insertLast(format.substr(character_index));
            }

            break;
        }

        character_index = new_character_index + 2;
    }

    return result;
}

Function_Definition@ find_function_definition_by_function_name(string function_name) {
    for (uint function_index = 0; function_index < state.function_definitions.length(); function_index++) {
        if (state.function_definitions[function_index].function_name == function_name) {
            return state.function_definitions[function_index];
        }
    }

    return null;
}

string function_call_to_string(Expression@ expression) {
    Function_Definition@ function_definition = find_function_definition_by_function_name(expression.identifier_name);

    if (function_definition is null) {
        return function_call_to_string_simple(expression);
    }

    string result = "";

    array<string>@ pieces = split_function_format_string_into_pieces(function_definition.format);

    for (uint argument_index = 0; argument_index < function_definition.argument_types.length(); argument_index++) {
        result += pieces[argument_index];

        string argument_as_string = literal_type_to_ui_string(function_definition.argument_types[argument_index]);

        if (expression.arguments.length() > argument_index) {
            Expression@ argument_expression = expression.arguments[argument_index];

            if (argument_expression !is null) {
                argument_as_string = expression_to_string(argument_expression);

                if (argument_expression.type != EXPRESSION_LITERAL && argument_expression.type != EXPRESSION_IDENTIFIER) {
                    argument_as_string = "(" + argument_as_string + ")";
                }
            }
        }

        result += argument_as_string;
    }

    result += pieces[pieces.length() - 1];

    return result;
    //return expression.identifier_name + "(" + join(arguments, ", ") + ")";
}

string expression_to_string(Expression@ expression) {
    if (expression is null) {
        return "<ERROR>";
    }

    switch (expression.type) {
        case EXPRESSION_OPERATOR: {
            string result = join(array<string> = {
                expression_to_string(expression.left_operand),
                operator_type_to_ui_string(expression.operator_type),
                expression_to_string(expression.right_operand)
            }, " ");

            if (expression.left_operand.type == EXPRESSION_OPERATOR || expression.right_operand.type == EXPRESSION_OPERATOR) {
                result = "(" + result + ")";
            } 

            return result;
        }

        case EXPRESSION_DECLARATION: {
            return join(array<string> = {
                colored_literal_type(expression.literal_type),
                colored_identifier(expression.identifier_name),
                "=",
                expression_to_string(expression.value_expression)
            }, " ");
        }
            
        case EXPRESSION_ASSIGNMENT:
            return join(array<string> = {
                colored_keyword("Set"),
                colored_identifier(expression.identifier_name),
                "=",
                expression_to_string(expression.value_expression)
            }, " ");
        case EXPRESSION_IDENTIFIER: return colored_identifier(expression.identifier_name);
        case EXPRESSION_LITERAL: return literal_to_ui_string(expression);
        case EXPRESSION_CALL: return function_call_to_string(expression);
        case EXPRESSION_REPEAT: {
            return join(array<string> = {
                colored_keyword("Repeat"),
                expression_to_string(expression.value_expression),
                "times"
            }, " ");
        }

        case EXPRESSION_WHILE: {
            return join(array<string> = {
                colored_keyword("While"),
                expression_to_string(expression.value_expression),
                "is " + literal_color + "true" + default_color + ", do"
            }, " ");
        }

        case EXPRESSION_IF: return colored_keyword("If ") + expression_to_string(expression.value_expression);
    }

    return "not_implemented (" + expression.type + ")";
}

bool icon_button(string text, string id, TextureAssetRef icon) {
    const float size_y = 28.0f;
    float text_width = ImGui_CalcTextSize(text, hide_text_after_double_hash: true).x;

    vec2 cursor_position = ImGui_GetCursorPos();
    vec2 image_size(16, 16);
    float image_padding = size_y / 2.0f - (image_size.y / 2.0f);
    vec2 size(image_padding * 3 + image_size.x + text_width, size_y);
    vec2 image_position(image_padding, image_padding);

    bool activated = ImGui_InvisibleButton(id, size);

    vec2 cursor_position_after_button = ImGui_GetCursorPos();
    vec4 color(0.35f, 0.40f, 0.61f, 0.62f);

    if (ImGui_IsItemActive()) {
        color = vec4(0.46f, 0.54f, 0.80f, 1.00f);
    } else if (ImGui_IsItemHovered()) {
        color = vec4(0.40f, 0.48f, 0.71f, 0.79f);
    }

    ImGui_SetCursorPos(cursor_position);
    ImGui_Image(icons::image_blank, size, tint_color: color);

    ImGui_SetCursorPos(cursor_position + image_position);
    ImGui_Image(icon, image_size);

    ImGui_SameLine();
    ImGui_Text(text);

    ImGui_SetCursorPos(cursor_position_after_button);

    return activated;
}

// TODO speed! Could be array indexed
// We could also just store Function_Definition references in expressions
TextureAssetRef get_call_icon(Expression@ expression) {
    for (uint function_index = 0; function_index < state.function_definitions.length(); function_index++) {
        Function_Definition@ function_definition = state.function_definitions[function_index];
        if (function_definition.function_name == expression.identifier_name) {
            if (function_definition.return_type == LITERAL_TYPE_BOOL) {
                return icons::action_logical;
            }
            
            switch (function_definition.function_category) {
                case CATEGORY_WAIT: return icons::action_wait;
                case CATEGORY_DIALOGUE: return icons::action_dialogue;

                default: return icons::action_other;
            }

            break;
        }
    }

    return icons::action_other;
}

void draw_expression_image(Expression@ expression) {
    ImGui_SetCursorPosY(ImGui_GetCursorPosY() + 1);

    switch (expression.type) {
        case EXPRESSION_IF:
        case EXPRESSION_WHILE:
        case EXPRESSION_REPEAT: {
            ImGui_Image(icons::action_logical, vec2(16, 16));
            break;
        }

        case EXPRESSION_CALL: {
            ImGui_Image(get_call_icon(expression), vec2(16, 16));

            break;
        }

        default: {
            ImGui_Image(icons::action_variable, vec2(16, 16));
        }
    }

    ImGui_SameLine();

    ImGui_SetCursorPosY(ImGui_GetCursorPosY() - 1);
}

void fill_function_call_expression_from_function_definition(Expression@ expression, Function_Definition@ function_definition) {
    expression.identifier_name = function_definition.function_name;
    expression.arguments.resize(function_definition.argument_types.length());

    for (uint argument_index = 0; argument_index < function_definition.argument_types.length(); argument_index++) {
        Literal_Type argument_type = function_definition.argument_types[argument_index];

        @expression.arguments[argument_index] = make_empty_lit(argument_type);
    }
}

string get_function_name_for_list(Function_Definition@ function_definition) {
    string name = function_definition.pretty_name;

    if (name.isEmpty()) {
        return function_definition.function_name;
    }

    return name;
}

string find_vacant_trigger_name() {
    string trigger_name;
    uint trigger_id = 0;

    while (true) {
        bool found = false;
        trigger_name = "Trigger " + (trigger_id + 1);

        for (uint i = 0; i < state.triggers.length(); i++) {
            if (state.triggers[i].name == trigger_name) {
                trigger_id++;
                found = true;
                break;
            }
        }

        if (!found) {
            break;
        }
    }

    return trigger_name;
}

array<Function_Definition@> filter_function_definitions_by_predicate(Function_Predicate@ predicate) {
    array<Function_Definition@> filter_result;

    for (uint index = 0; index < state.function_definitions.length(); index++) {
        Function_Definition@ function_description = state.function_definitions[index];

        if (predicate(function_description)) {
            filter_result.insertLast(function_description);
        }
    }

    return filter_result;
}

array<Function_Definition@> filter_function_definitions_by_return_type(Literal_Type limit_to) {
    array<Function_Definition@> filter_result;

    for (uint index = 0; index < state.function_definitions.length(); index++) {
        Function_Definition@ function_definition = state.function_definitions[index];

        if (function_definition.return_type == limit_to) {
            filter_result.insertLast(function_definition);
        }
    }

    return filter_result;
}

void open_expression_editor_popup(Expression@ expression, Ui_Frame_State@ frame) {
    ImGui_OpenPopup("Edit###Popup" + frame.popup_stack_level + frame.line_counter);
    state.edited_expressions.insertLast(expression);
}