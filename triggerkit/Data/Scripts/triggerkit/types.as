enum Literal_Type {
    LITERAL_TYPE_VOID,
    LITERAL_TYPE_NUMBER,
    LITERAL_TYPE_STRING,
    LITERAL_TYPE_BOOL,
    LITERAL_TYPE_VECTOR_3,
    LITERAL_TYPE_CAMERA,
    LITERAL_TYPE_CHARACTER,
    LITERAL_TYPE_REGION,
    LITERAL_TYPE_POSE,

    // Enums
    LITERAL_TYPE_CAMERA_INTERPOLATION_TYPE,
    LITERAL_TYPE_CHARACTER_PLACEMENT_TYPE,

    // Not implemented
    LITERAL_TYPE_OBJECT,
    LITERAL_TYPE_ITEM,
    LITERAL_TYPE_FUNCTION,
    LITERAL_TYPE_ARRAY,
    LITERAL_TYPE_LAST
}

enum Interpolation_Type {
    INTERPOLATION_LINEAR,
    INTERPOLATION_EASE_OUT_CIRCULAR,
    INTERPOLATION_LAST
}

enum Placement_Type {
    PLACEMENT_PRECISE,
    PLACEMENT_ON_THE_GROUND,
    PLACEMENT_LAST
}

class Enums {
    Enum@ literal_type;
    Enum@ interpolation_type;
    Enum@ operator_type;
    Enum@ placement_type;
}

class Enum {
    array<string> enum_to_string;
    dictionary string_to_enum;

    Enum(uint last_value) {
        enum_to_string.resize(last_value);
    }

    void value(uint enum_value, string string_value) {
        enum_to_string[enum_value] = string_value;
        string_to_enum[string_value] = enum_value;
    }

    // TODO error checking, default values
    string to_string(uint value) {
        return enum_to_string[value];
    }

    uint to_value(string value) {
        return uint(string_to_enum[value]);
    }
}

funcdef string Name_Resolver(int handle_id); 

void fill_enums(Enums@ target) {
    @target.literal_type = fill_literal_types_enum();
    @target.interpolation_type = fill_interpolation_types_enum();
    @target.operator_type = fill_operator_types_enum();
    @target.placement_type = fill_placement_types_enum();
}

Enum@ fill_literal_types_enum() {
    Enum e(LITERAL_TYPE_LAST);

    e.value(LITERAL_TYPE_VOID, "Void");
    e.value(LITERAL_TYPE_NUMBER, "Number");
    e.value(LITERAL_TYPE_STRING, "String");
    e.value(LITERAL_TYPE_BOOL, "Bool");
    e.value(LITERAL_TYPE_ITEM, "Item");
    e.value(LITERAL_TYPE_REGION, "Region");
    e.value(LITERAL_TYPE_CHARACTER, "Character");
    e.value(LITERAL_TYPE_VECTOR_3, "Vector3");
    e.value(LITERAL_TYPE_CAMERA, "Camera");
    e.value(LITERAL_TYPE_POSE, "Pose");
    e.value(LITERAL_TYPE_CAMERA_INTERPOLATION_TYPE, "InterpolationFunction");
    e.value(LITERAL_TYPE_CHARACTER_PLACEMENT_TYPE, "PlacementType");

    e.value(LITERAL_TYPE_OBJECT, "Object");
    e.value(LITERAL_TYPE_FUNCTION, "Function");
    e.value(LITERAL_TYPE_ARRAY, "Array");

    return e;
}

Enum@ fill_operator_types_enum() {
    Enum e(OPERATOR_LAST);

    e.value(OPERATOR_AND, "and");
    e.value(OPERATOR_OR, "or");
    e.value(OPERATOR_EQ, "=");
    e.value(OPERATOR_NEQ, "~");
    e.value(OPERATOR_GT, ">");
    e.value(OPERATOR_LT, "<");
    e.value(OPERATOR_ADD, "+");
    e.value(OPERATOR_SUB, "-");
    e.value(OPERATOR_DIV, "/");
    e.value(OPERATOR_MUL, "*");
    e.value(OPERATOR_GE, ">=");
    e.value(OPERATOR_LE, "<=");

    return e;
}

Enum@ fill_interpolation_types_enum() {
    Enum e(INTERPOLATION_LAST);

    e.value(INTERPOLATION_LINEAR, "Linear");
    e.value(INTERPOLATION_EASE_OUT_CIRCULAR, "EaseOutCircular");

    return e;
}

Enum@ fill_placement_types_enum() {
    Enum e(PLACEMENT_LAST);

    e.value(PLACEMENT_PRECISE, "Precise");
    e.value(PLACEMENT_ON_THE_GROUND, "OnTheGround");

    return e;
}

string literal_to_serializeable_string(Literal_Type literal_type, Memory_Cell@ literal_value) {
    switch (literal_type) {
        // Enums and reference types go there
        case LITERAL_TYPE_CHARACTER:
        case LITERAL_TYPE_REGION:
        case LITERAL_TYPE_CAMERA:
        case LITERAL_TYPE_POSE:
        case LITERAL_TYPE_NUMBER:
            return literal_value.number_value + "";

        case LITERAL_TYPE_CHARACTER_PLACEMENT_TYPE:
            return placement_type_to_serializeable_string(Placement_Type(literal_value.number_value));

        case LITERAL_TYPE_CAMERA_INTERPOLATION_TYPE:
            return interpolation_type_to_serializeable_string(Interpolation_Type(literal_value.number_value));

        case LITERAL_TYPE_STRING: return serializeable_string(literal_value.string_value);
        case LITERAL_TYPE_BOOL: return number_to_bool(literal_value.number_value) ? "True" : "False";
        case LITERAL_TYPE_VECTOR_3: return literal_value.vec3_value.x + " " + literal_value.vec3_value.y + " " + literal_value.vec3_value.z;

        default: {
            Log(error, "Unsupported literal type " + literal_type_to_serializeable_string(literal_type));
        }
    }

    return "not_implemented";
}

string literal_type_to_ui_string(Literal_Type literal_type) {
    switch(literal_type) {
        case LITERAL_TYPE_STRING: return "Text";
        case LITERAL_TYPE_BOOL: return "Boolean";
        case LITERAL_TYPE_VECTOR_3: return "Point";
        case LITERAL_TYPE_POSE: return "Dialogue Pose";
        case LITERAL_TYPE_CAMERA_INTERPOLATION_TYPE: return "Interpolation Function";
        case LITERAL_TYPE_CHARACTER_PLACEMENT_TYPE: return "Placement";
    }

    return literal_type_to_serializeable_string(literal_type);
}

string literal_to_ui_string(Literal_Type literal_type, Memory_Cell@ value) {
    switch (literal_type) {
        case LITERAL_TYPE_REGION: return colored_literal("<") + region_id_to_region_name(int(value.number_value)) + colored_literal(">");
        case LITERAL_TYPE_CHARACTER: return colored_literal("<") + character_id_to_character_name(int(value.number_value)) + colored_literal(">");
        case LITERAL_TYPE_POSE: return colored_literal("<") + pose_id_to_pose_name(int(value.number_value)) + colored_literal(">");
        case LITERAL_TYPE_CAMERA: return colored_literal("<") + camera_id_to_camera_name(int(value.number_value)) + colored_literal(">");
        case LITERAL_TYPE_NUMBER: return colored_literal(value.number_value + "");
        case LITERAL_TYPE_STRING: return string_color + "\"" + value.string_value + "\"" + default_color;
        case LITERAL_TYPE_BOOL: return colored_literal(number_to_bool(value.number_value) ? "True" : "False");
        case LITERAL_TYPE_CHARACTER_PLACEMENT_TYPE: {
            return colored_literal(placement_type_to_ui_string(Placement_Type(value.number_value)));
        }

        case LITERAL_TYPE_CAMERA_INTERPOLATION_TYPE: {
            return colored_literal(interpolation_type_to_ui_string(Interpolation_Type(value.number_value)));
        }

        case LITERAL_TYPE_VECTOR_3:
            return "Point(" + 
                colored_literal(value.vec3_value.x + "") + ", " + 
                colored_literal(value.vec3_value.y + "") + ", " + 
                colored_literal(value.vec3_value.z + "") +
            ")";

        default: {
            Log(error, "Unsupported literal type " + literal_type_to_ui_string(literal_type));
        }
    }

    return "not_implemented";
}

void emit_literal_bytecode(Translation_Context@ ctx, Expression@ expression) {
    array<Instruction>@ target = ctx.code;

    bool is_valid = true;

    int handle_id = int(expression.literal_value.number_value);

    switch (expression.literal_type) {
        // Reference types
        case LITERAL_TYPE_CAMERA: is_valid = validate_hotspot_id(handle_id, HOTSPOT_CAMERA_TYPE); break;
        case LITERAL_TYPE_CHARACTER: is_valid = validate_character_id(handle_id); break;
        case LITERAL_TYPE_REGION: is_valid = validate_hotspot_id(handle_id, HOTSPOT_REGION_TYPE); break;
        case LITERAL_TYPE_POSE: is_valid = validate_hotspot_id(handle_id, HOTSPOT_DIALOGUE_POSE_TYPE); break;
    }

    if (!is_valid) {
        report_compiler_error(ctx, "Entity of type " + literal_type_to_ui_string(expression.literal_type) + " with id " + handle_id + " was not found");
        return;
    }

    switch (expression.literal_type) {
        // Enums and reference types go there
        case LITERAL_TYPE_CAMERA:
        case LITERAL_TYPE_CHARACTER:
        case LITERAL_TYPE_REGION:
        case LITERAL_TYPE_POSE:
        case LITERAL_TYPE_CAMERA_INTERPOLATION_TYPE:
        case LITERAL_TYPE_CHARACTER_PLACEMENT_TYPE:
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

        case LITERAL_TYPE_BOOL: {
            if (number_to_bool(expression.literal_value.number_value)) {
                emit_instruction(make_instruction(INSTRUCTION_TYPE_CONST_1), target);
            } else {
                emit_instruction(make_instruction(INSTRUCTION_TYPE_CONST_0), target);
            }

            break;
        }

        case LITERAL_TYPE_VECTOR_3: {
            uint const_id = find_or_save_vec3_const(ctx, expression.literal_value.vec3_value);
            emit_instruction(make_load_const_instruction(const_id), target);
            break;
        }

        default: {
            Log(error, "Unhandled literal of type " + literal_type_to_ui_string(expression.literal_type));
        }
    }
}

Expression@ parse_literal_value_from_string(Literal_Type literal_type, Parser_State@ state) {
    string first_word = parser_next_word(state);

    switch (literal_type) {
        case LITERAL_TYPE_CHARACTER:
        case LITERAL_TYPE_CAMERA:
        case LITERAL_TYPE_REGION:
        case LITERAL_TYPE_POSE:
            return make_handle_lit(literal_type, parseInt(first_word));

        case LITERAL_TYPE_CAMERA_INTERPOLATION_TYPE:
            return make_enum_lit(literal_type, serializeable_string_to_interpolation_type(first_word));

        case LITERAL_TYPE_CHARACTER_PLACEMENT_TYPE:
            return make_enum_lit(literal_type, serializeable_string_to_placement_type(first_word));

        case LITERAL_TYPE_NUMBER: return make_lit(parseFloat(first_word));
        case LITERAL_TYPE_STRING: return make_lit(first_word);
        case LITERAL_TYPE_BOOL: return make_lit("True" == first_word);
        case LITERAL_TYPE_VECTOR_3: {
            float x = parseFloat(first_word);
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

bool draw_handle_editor(Name_Resolver@ name_resolver, array<Object@>@ handles, Memory_Cell@ literal_value, string unique_id) {
    int selected_handle_id = int(literal_value.number_value);

    if (ImGui_BeginCombo(unique_id, name_resolver(current_type))) {
        for (uint handle_index = 0; handle_index < handles.length(); handle_index++) {
            Object@ handle_object = handles[handle_index];
            int handle_id = handle_object.GetID();

            // TODO a tad inefficient (we are requesting an object by id again inside name_resolver),
            //      could make a separate function which makes a name out of an object, but it's probably fine
            if (ImGui_Selectable(name_resolver(handle_id), handle_id == selected_handle_id)) {
                literal_value.number_value = handle_id;
                ImGui_EndCombo();
                return true;
            }
        }

        ImGui_EndCombo();
    }

    return false;
}

bool draw_enum_editor(Name_Resolver@ name_resolver, Memory_Cell@ literal_value, int last_member, string unique_id) {
    int current_type = int(literal_value.number_value);

    if (ImGui_BeginCombo(unique_id, name_resolver(current_type))) {
        for (int type = 0; type < last_member; type++) {
            if (ImGui_Selectable(name_resolver(type), type == current_type)) {
                literal_value.number_value = type;
                ImGui_EndCombo();
                return true;
            }
        }

        ImGui_EndCombo();
    }

    return false;
}

bool draw_editable_literal(Literal_Type literal_type, Memory_Cell@ literal_value, string unique_id) {
    switch (literal_type) {
        case LITERAL_TYPE_NUMBER:
            return ImGui_InputFloat(unique_id, literal_value.number_value, 1);
        case LITERAL_TYPE_STRING: {
            ImGui_SetTextBuf(literal_value.string_value);

            bool was_edited = ImGui_InputText(unique_id);

            if (was_edited) {
                literal_value.string_value = ImGui_GetTextBuf();
            }

            return was_edited;
        }

        case LITERAL_TYPE_BOOL: {
            bool value = number_to_bool(literal_value.number_value);
            bool was_edited = ImGui_Checkbox(value ? "True" : "False" + unique_id, value);

            if (was_edited) {
                literal_value.number_value = bool_to_number(value);
            }

            return was_edited;
        }

        case LITERAL_TYPE_CAMERA: {
            return draw_handle_editor(camera_id_to_camera_name, list_camera_objects(), literal_value, unique_id);
        }

        case LITERAL_TYPE_REGION: {
            return draw_handle_editor(region_id_to_region_name, list_region_objects(), literal_value, unique_id);
        }

        case LITERAL_TYPE_CHARACTER: {
            return draw_handle_editor(character_id_to_character_name, list_character_objects(), literal_value, unique_id);
        }

        case LITERAL_TYPE_POSE: {
            return draw_handle_editor(pose_id_to_pose_name, list_pose_objects(), literal_value, unique_id);
        }

        case LITERAL_TYPE_CAMERA_INTERPOLATION_TYPE: {
            Name_Resolver@ resolver = function(type_as_int) {
                return interpolation_type_to_ui_string(Interpolation_Type(type_as_int));
            };

            draw_enum_editor(resolver, literal_value, INTERPOLATION_LAST, unique_id);

            return false;
        }

        case LITERAL_TYPE_CHARACTER_PLACEMENT_TYPE: {
            Name_Resolver@ resolver = function(type_as_int) {
                return placement_type_to_ui_string(Placement_Type(type_as_int));
            };

            draw_enum_editor(resolver, literal_value, PLACEMENT_LAST, unique_id);

            return false;
        }

        case LITERAL_TYPE_OBJECT:
            ImGui_Text("Object input here");
            break;
        case LITERAL_TYPE_ITEM:
            ImGui_Text("Item input here");
            break;
        case LITERAL_TYPE_VECTOR_3:
            return ImGui_InputFloat3(unique_id, literal_value.vec3_value, 2);
        case LITERAL_TYPE_ARRAY:
            ImGui_Text("Array input here");
            break;
    }

    return false;
}

void fill_default_handle_id_if_available(Expression@ literal, array<Object@>@ handles) {
    if (handles.length() > 0) {
        literal.literal_value.number_value = handles[0].GetID();
    } else {
        literal.literal_value.number_value = -1;
    }
}

Expression@ make_default_literal(Literal_Type literal_type) {
    Expression expression;
    expression.type = EXPRESSION_LITERAL;
    expression.literal_type = literal_type;

    switch (literal_type) {
        case LITERAL_TYPE_CAMERA: {
            fill_default_handle_id_if_available(expression, list_camera_objects());
            break;
        }

        case LITERAL_TYPE_CHARACTER: {
            fill_default_handle_id_if_available(expression, list_character_objects());
            break;
        }

        case LITERAL_TYPE_REGION: {
            fill_default_handle_id_if_available(expression, list_region_objects());
            break;
        }

        case LITERAL_TYPE_POSE: {
            fill_default_handle_id_if_available(expression, list_pose_objects());
            break;
        }

        case LITERAL_TYPE_CHARACTER_PLACEMENT_TYPE: {
            expression.literal_value.number_value = PLACEMENT_ON_THE_GROUND;
            break;
        }
    }

    return expression;
}

string interpolation_type_to_ui_string(Interpolation_Type interpolation_type) {
    switch (interpolation_type) {
        case INTERPOLATION_LINEAR: return "Linear";
        case INTERPOLATION_EASE_OUT_CIRCULAR: return "Ease out circular";
    }

    return "unknown";
}

string placement_type_to_ui_string(Placement_Type placement_type) {
    switch (placement_type) {
        case PLACEMENT_PRECISE: return "precisely";
        case PLACEMENT_ON_THE_GROUND: return "on the ground";
    }

    return "unknown";
}

string literal_type_to_serializeable_string(Literal_Type literal_type) {
    return enums.literal_type.to_string(literal_type);
}

string interpolation_type_to_serializeable_string(Interpolation_Type interpolation_type) {
    return enums.interpolation_type.to_string(interpolation_type);
}

string operator_type_to_serializeable_string(Operator_Type operator_type) {
    return enums.operator_type.to_string(operator_type);
}

string placement_type_to_serializeable_string(Placement_Type placement_type) {
    return enums.placement_type.to_string(placement_type);
}

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

Placement_Type serializeable_string_to_placement_type(string text) {
    return Placement_Type(enums.placement_type.to_value(text));
}

Interpolation_Type serializeable_string_to_interpolation_type(string text) {
    return Interpolation_Type(enums.interpolation_type.to_value(text));
}

Operator_Type serializeable_string_to_operator_type(string text) {
    return Operator_Type(enums.operator_type.to_value(text));
}

Literal_Type serializeable_string_to_literal_type(string text) {
    return Literal_Type(enums.literal_type.to_value(text));
}