funcdef bool Function_Predicate(Function_Definition@ f);

namespace icons {
    const string icons_folder = "Data/Images/triggerkit/ui/icons/";
    TextureAssetRef image_blank = LoadTexture("Data/Images/triggerkit/ui/image_blank.png", TextureLoadFlags_NoMipmap);

    TextureAssetRef event = LoadTexture(icons_folder + "Editor-TriggerEvent.png", TextureLoadFlags_NoMipmap);
    TextureAssetRef trigger = LoadTexture(icons_folder + "Editor-Trigger.png", TextureLoadFlags_NoMipmap);
    TextureAssetRef action_variable = LoadTexture(icons_folder + "Actions-SetVariables.png", TextureLoadFlags_NoMipmap);
    TextureAssetRef action_logical = LoadTexture(icons_folder + "Actions-Logical.png", TextureLoadFlags_NoMipmap);
    TextureAssetRef action_other = LoadTexture(icons_folder + "Actions-Nothing.png", TextureLoadFlags_NoMipmap);
    TextureAssetRef action_wait = LoadTexture(icons_folder + "Actions-Wait.png", TextureLoadFlags_NoMipmap);
    TextureAssetRef action_dialogue = LoadTexture(icons_folder + "Actions-Quest.png", TextureLoadFlags_NoMipmap);
    TextureAssetRef action_camera = LoadTexture(icons_folder + "Actions-Camera.png", TextureLoadFlags_NoMipmap);
}

string operator_type_to_ui_string(Operator_Type operator_type) {
    switch (operator_type) {
        case OPERATOR_AND: return "and";
        case OPERATOR_OR: return "or";
        case OPERATOR_EQ: return "is";
        case OPERATOR_NEQ: return "is not";
        case OPERATOR_GT: return "is greater than";
        case OPERATOR_LT: return "is lesser than";
        case OPERATOR_GE: return "is greater or equals to";
        case OPERATOR_LE: return "is lesser or equals to";
        case OPERATOR_ADD: return "+";
        case OPERATOR_SUB: return "-";
        case OPERATOR_DIV: return "/";
        case OPERATOR_MUL: return "*";
    }

    return "undefined";
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

string colored_literal(string value) {
    return literal_color + value + default_color;
}

string camera_id_to_camera_name(int camera_id) {
    if (!ObjectExists(camera_id)) {
        return "None";
    }

    Object@ camera_object = ReadObjectFromID(camera_id);
    return camera_object.GetName() + " (#" + camera_id + ")";
}

string region_id_to_region_name(int region_id) {
    if (!ObjectExists(region_id)) {
        return "None";
    }

    Object@ region_object = ReadObjectFromID(region_id);
    string region_name = region_object.GetName();

    if (region_name.isEmpty()) {
        return "Region #" + region_id;
    }

    return region_name;
}

// TODO this function name is a bit ambigious, we really rely that this is a Character object
string object_id_to_object_name(int object_id) {
    Object@ object = ReadObjectFromID(object_id);
    string object_name = object.GetName();

    if (object_name.isEmpty()) {
        string character_path = ReadCharacterID(object_id).char_path;
        int last_slash_index = character_path.findLast("/");

        if (last_slash_index != -1) {
            character_path = character_path.substr(last_slash_index + 1);
        }

        return character_path + " (#" + object_id + ")";
    }

    return object_name;
}

array<Object@>@ list_objects_by_type_string(string type_string) {
    array<Object@> result;

    int amount_of_hotspots = GetNumHotspots();

    for (int hotspot_index = 0; hotspot_index < amount_of_hotspots; hotspot_index++) {
        Hotspot@ hotspot = ReadHotspot(hotspot_index);

        if (hotspot.GetTypeString() == type_string) {
            result.insertLast(ReadObjectFromID(hotspot.GetID()));
        }
    }

    return result;
}

array<Object@>@ list_camera_objects() {
    return list_objects_by_type_string(HOTSPOT_CAMERA_TYPE);
}

array<Object@>@ list_region_objects() {
    return list_objects_by_type_string(HOTSPOT_REGION_TYPE);
}

array<Object@>@ list_character_objects() {
    array<int> character_ids;

    GetCharacters(character_ids);

    array<Object@> result;

    for (uint id_index = 0; id_index < character_ids.length(); id_index++) {
        // TODO gotta check if the object is deleted
        result.insertLast(ReadObjectFromID(character_ids[id_index]));
    }

    return result;
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

// TODO this shouldn't be in ui_util.as
Literal_Type determine_expression_literal_type(Expression@ expression, Variable_Scope@ variable_scope) {
    switch (expression.type) {
        case EXPRESSION_LITERAL: return expression.literal_type;
        case EXPRESSION_IDENTIFIER: {
            array<Variable@> scope_variables;
            collect_scope_variables(variable_scope, scope_variables);

            for (uint variable_index = 0; variable_index < scope_variables.length(); variable_index++) {
                if (scope_variables[variable_index].name == expression.identifier_name) {
                    return scope_variables[variable_index].type;
                }
            }

            break;
        }

        case EXPRESSION_CALL: {
            Function_Definition@ definition = find_function_definition_by_function_name(expression.identifier_name);

            return definition is null ? LITERAL_TYPE_VOID : definition.return_type;
        }

        case EXPRESSION_OPERATOR: {
            Operator_Definition@ definition = find_operator_definition_by_expression_in_context(expression, variable_scope);

            return definition is null ? LITERAL_TYPE_VOID : definition.parent_group.return_type;
        }

        default: {
            Log(error, "Not an expression: " + expression.type);
        }
    }

    return LITERAL_TYPE_VOID;
}

Function_Definition@ find_function_definition_by_function_name(string function_name) {
    for (uint function_index = 0; function_index < state.function_definitions.length(); function_index++) {
        if (state.function_definitions[function_index].function_name == function_name) {
            return state.function_definitions[function_index];
        }
    }

    return null;
}

Operator_Definition@ find_operator_definition_by_expression_in_context(Expression@ expression, Variable_Scope@ variable_scope) {
    if (expression.left_operand is null || expression.right_operand is null) {
        return null;
    }

    Literal_Type l_type = determine_expression_literal_type(expression.left_operand, variable_scope);
    Literal_Type r_type = determine_expression_literal_type(expression.right_operand, variable_scope);

    return find_operator_definition_by_operator_type_and_operand_types(expression.operator_type, l_type, r_type);
}

Operator_Definition@ find_operator_definition_by_operator_type_and_operand_types(Operator_Type operator_type, Literal_Type l_type, Literal_Type r_type) {
    for (uint group_index = 0; group_index < state.operator_groups.length(); group_index++) {
        Operator_Group@ group = state.operator_groups[group_index];

        for (uint operator_index = 0; operator_index < group.operators.length(); operator_index++) {
            Operator_Definition@ operator = group.operators[operator_index];

            if (operator.left_operand_type == l_type && operator.right_operand_type == r_type && operator.operator_type == operator_type) {
                return operator;
            }
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

            //if (expression.left_operand.type == EXPRESSION_OPERATOR || expression.right_operand.type == EXPRESSION_OPERATOR) {
                //result = "(" + result + ")";
            //} 

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
        case EXPRESSION_LITERAL: return literal_to_ui_string(expression.literal_type, expression.literal_value);
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
                expression_to_string(expression.value_expression) + ", do"
            }, " ");
        }

        case EXPRESSION_FORK: return colored_keyword("Run in parallel");

        case EXPRESSION_IF: return colored_keyword("If ") + expression_to_string(expression.value_expression);
    }

    return "not_implemented (" + expression.type + ")";
}

bool icon_button(string text, string id, TextureAssetRef icon) {
    const float size_y = 24.0f;
    float text_width = ImGui_CalcTextSize(text, hide_text_after_double_hash: true).x;

    vec2 cursor_position = ImGui_GetCursorPos();
    vec2 image_size(16, 16);
    float image_padding = size_y / 2.0f - (image_size.y / 2.0f);
    vec2 button_size(image_padding * 3 + image_size.x + text_width, size_y);
    vec2 image_position(image_padding, image_padding);

    vec2 pre = ImGui_GetCursorPos();

    bool activated = ImGui_InvisibleButton(id, button_size);

    vec2 cursor_position_after_button = ImGui_GetCursorPos();
    vec4 color(0.35f, 0.40f, 0.61f, 0.62f);

    if (ImGui_IsItemActive()) {
        color = vec4(0.46f, 0.54f, 0.80f, 1.00f);
    } else if (ImGui_IsItemHovered()) {
        color = vec4(0.40f, 0.48f, 0.71f, 0.79f);
    }

    ImGui_SetCursorPos(cursor_position);
    ImGui_Image(icons::image_blank, button_size, tint_color: color);

    ImGui_SetCursorPos(cursor_position + image_position);
    ImGui_Image(icon, image_size);

    ImGui_SameLine();
    ImGui_SetCursorPosX(cursor_position.x + image_size.x + image_padding * 2);
    ImGui_Text(text);

    ImGui_SetCursorPos(cursor_position);

    ImGui_Dummy(button_size); // For proper alignment

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
                case CATEGORY_CAMERA: return icons::action_camera;

                default: return icons::action_other;
            }

            break;
        }
    }

    return icons::action_other;
}

string function_category_to_string(Function_Category function_category) {
    switch (function_category) {
        case CATEGORY_NONE: return "All";
        case CATEGORY_OTHER: return "Other";
        case CATEGORY_WAIT: return "Waiting";
        case CATEGORY_DIALOGUE: return "Dialogue";
        case CATEGORY_CAMERA: return "Camera";
    }

    return "Category " + function_category;
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

// TODO do we really want left_operand and right_operand at all?
array<Expression@>@ get_expression_arguments_as_array(Expression@ expression) {
    return expression.type == EXPRESSION_OPERATOR ?
            array<Expression@> = { expression.left_operand, expression.right_operand } :
            expression.arguments;
}

Expression@ previous_argument_or_default(Literal_Type argument_type, array<Expression@>@ previous_arguments, uint argument_index, Variable_Scope@ variable_scope) {
    if (argument_index < previous_arguments.length()) {
        Expression@ old_argument = previous_arguments[argument_index];
        Literal_Type old_argument_type = determine_expression_literal_type(old_argument, variable_scope);

        if (old_argument_type == argument_type) {
            return old_argument;
        }
    }

    return make_default_literal(argument_type);
}

void fill_function_call_expression_from_function_definition(Expression@ expression, Function_Definition@ function_definition, Variable_Scope@ variable_scope) {
    array<Expression@>@ previous_arguments = get_expression_arguments_as_array(expression);

    expression.identifier_name = function_definition.function_name;
    expression.arguments.resize(function_definition.argument_types.length());

    for (uint argument_index = 0; argument_index < function_definition.argument_types.length(); argument_index++) {
        Literal_Type argument_type = function_definition.argument_types[argument_index];

        @expression.arguments[argument_index] = previous_argument_or_default(argument_type, previous_arguments, argument_index, variable_scope);
    }

    expression.type = EXPRESSION_CALL;
}

void fill_operator_expression_from_operator_definition(Expression@ expression, Operator_Definition@ operator_definition, Variable_Scope@ variable_scope) {
    array<Expression@>@ previous_arguments = get_expression_arguments_as_array(expression);

    expression.operator_type = operator_definition.operator_type;
    @expression.left_operand = previous_argument_or_default(operator_definition.left_operand_type, previous_arguments, 0, variable_scope);
    @expression.right_operand = previous_argument_or_default(operator_definition.right_operand_type, previous_arguments, 1, variable_scope);

    expression.type = EXPRESSION_OPERATOR;
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

// TODO unused?
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

array<Function_Definition@> filter_function_definitions_by_category(Function_Category category) {
    array<Function_Definition@> filter_result;

    for (uint index = 0; index < state.function_definitions.length(); index++) {
        Function_Definition@ function_definition = state.function_definitions[index];

        if (function_definition.function_category == category || category == CATEGORY_NONE) {
            filter_result.insertLast(function_definition);
        }
    }

    return filter_result;
}

array<Operator_Group@> filter_operator_groups_by_return_type(Literal_Type limit_to) {
    array<Operator_Group@> filter_result;

    for (uint index = 0; index < state.operator_groups.length(); index++) {
        Operator_Group@ operator_group = state.operator_groups[index];

        if (operator_group.return_type == limit_to) {
            filter_result.insertLast(operator_group);
        }
    }

    return filter_result;
}

void open_expression_editor_popup(Expression@ expression, Ui_Frame_State@ frame) {
    ImGui_OpenPopup("Edit###Popup" + frame.popup_stack_level + frame.line_counter + frame.argument_counter);
    state.edited_expressions.insertLast(expression);
    state.selected_categories.insertLast(CATEGORY_NONE);
}