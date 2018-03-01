enum Literal_Type {
    LITERAL_TYPE_VOID,
    LITERAL_TYPE_NUMBER,
    LITERAL_TYPE_STRING,
    LITERAL_TYPE_BOOL,
    LITERAL_TYPE_VECTOR_3,
    LITERAL_TYPE_CAMERA,
    LITERAL_TYPE_CAMERA_INTERPOLATION_TYPE,

    // Not implemented
    LITERAL_TYPE_OBJECT,
    LITERAL_TYPE_ITEM,
    LITERAL_TYPE_HOTSPOT,
    LITERAL_TYPE_CHARACTER,
    LITERAL_TYPE_FUNCTION,
    LITERAL_TYPE_ARRAY,
    LITERAL_TYPE_LAST
}

enum Interpolation_Type {
    INTERPOLATION_LINEAR,
    INTERPOLATION_EASE_OUT_CIRCULAR,
    INTERPOLATION_LAST
}

class Enums {
    Enum@ serializeable_literal_type;
    Enum@ serializeable_interpolation_type;
    Enum@ serializeable_operator_type;
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

void fill_enums(Enums@ target) {
    @target.serializeable_literal_type = fill_serializeable_literal_types_enum();
    @target.serializeable_interpolation_type = fill_serializeable_interpolation_types_enum();
    @target.serializeable_operator_type = fill_serializeable_operator_types_enum();
}

Enum@ fill_serializeable_literal_types_enum() {
    Enum e(LITERAL_TYPE_LAST);

    e.value(LITERAL_TYPE_VOID, "Void");
    e.value(LITERAL_TYPE_NUMBER, "Number");
    e.value(LITERAL_TYPE_STRING, "String");
    e.value(LITERAL_TYPE_BOOL, "Bool");
    e.value(LITERAL_TYPE_OBJECT, "Object");
    e.value(LITERAL_TYPE_ITEM, "Item");
    e.value(LITERAL_TYPE_HOTSPOT, "Hotspot");
    e.value(LITERAL_TYPE_CHARACTER, "Character");
    e.value(LITERAL_TYPE_VECTOR_3, "Vector3");
    e.value(LITERAL_TYPE_FUNCTION, "Function");
    e.value(LITERAL_TYPE_CAMERA, "Camera");
    e.value(LITERAL_TYPE_ARRAY, "Array");
    e.value(LITERAL_TYPE_CAMERA_INTERPOLATION_TYPE, "InterpolationFunction");

    return e;
}

Enum@ fill_serializeable_operator_types_enum() {
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

Enum@ fill_serializeable_interpolation_types_enum() {
    Enum e(INTERPOLATION_LAST);

    e.value(INTERPOLATION_LINEAR, "Linear");
    e.value(INTERPOLATION_EASE_OUT_CIRCULAR, "EaseOutCircular");

    return e;
}

string literal_to_serializeable_string(Literal_Type literal_type, Memory_Cell@ literal_value) {
    switch (literal_type) {
        case LITERAL_TYPE_CAMERA:
        case LITERAL_TYPE_NUMBER:
            return literal_value.number_value + "";

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
        case LITERAL_TYPE_CAMERA_INTERPOLATION_TYPE: return "Interpolation Function";
    }

    return literal_type_to_serializeable_string(literal_type);
}

string literal_to_ui_string(Literal_Type literal_type, Memory_Cell@ value) {
    switch (literal_type) {
        case LITERAL_TYPE_CAMERA: return colored_literal("<") + camera_id_to_camera_name(int(value.number_value)) + colored_literal(">");
        case LITERAL_TYPE_NUMBER: return colored_literal(value.number_value + "");
        case LITERAL_TYPE_STRING: return string_color + "\"" + value.string_value + "\"" + default_color;
        case LITERAL_TYPE_BOOL: return colored_literal(number_to_bool(value.number_value) ? "True" : "False");
        case LITERAL_TYPE_CAMERA_INTERPOLATION_TYPE: {
            string name = interpolation_type_to_serializeable_string(Interpolation_Type(value.number_value));
            return colored_literal(name);
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

    switch (expression.literal_type) {
        case LITERAL_TYPE_CAMERA:
        case LITERAL_TYPE_CAMERA_INTERPOLATION_TYPE:
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
    switch (literal_type) {
        case LITERAL_TYPE_CAMERA:
            return make_handle_lit(literal_type, parseInt(parser_next_word(state)));

        case LITERAL_TYPE_CAMERA_INTERPOLATION_TYPE:
            return make_enum_lit(literal_type, uint(parseInt(parser_next_word(state))));

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
            array<Object@>@ camera_objects = list_camera_objects();
            array<string> camera_names;

            int selected_camera = -1;

            for (uint camera_index = 0; camera_index < camera_objects.length(); camera_index++) {
                Object@ camera_object = camera_objects[camera_index];

                // TODO a tad inefficient, could make a separate function which makes a name out of an object
                camera_names.insertLast(camera_id_to_camera_name(camera_object.GetID()));

                if (camera_object.GetID() == int(literal_value.number_value)) {
                    selected_camera = camera_index;
                }
            }

            if (ImGui_Combo(unique_id, selected_camera, camera_names)) {
                literal_value.number_value = camera_objects[selected_camera].GetID();
                return true;
            }

            return false;
        }

        case LITERAL_TYPE_CAMERA_INTERPOLATION_TYPE: {
            // TODO we need interpolation_type_to_ui_string
            array<string> data = { "Linear", "Ease out circular" };
            int selected_type = int(literal_value.number_value);

            if (ImGui_Combo(unique_id, selected_type, data)) {
                literal_value.number_value = selected_type;
                return true;
            }

            return false;
        }

        case LITERAL_TYPE_OBJECT:
            ImGui_Text("Object input here");
            break;
        case LITERAL_TYPE_ITEM:
            ImGui_Text("Item input here");
            break;
        case LITERAL_TYPE_HOTSPOT:
            ImGui_Text("Hotspot input here");
            break;
        case LITERAL_TYPE_CHARACTER:
            ImGui_Text("Character input here");
            break;
        case LITERAL_TYPE_VECTOR_3:
            return ImGui_InputFloat3(unique_id, literal_value.vec3_value, 2);
        case LITERAL_TYPE_ARRAY:
            ImGui_Text("Array input here");
            break;
    }

    return false;
}

string literal_type_to_serializeable_string(Literal_Type literal_type) {
    return enums.serializeable_literal_type.to_string(literal_type);
}

string interpolation_type_to_serializeable_string(Interpolation_Type interpolation_type) {
    return enums.serializeable_interpolation_type.to_string(interpolation_type);
}

string operator_type_to_serializeable_string(Operator_Type operator_type) {
    return enums.serializeable_operator_type.to_string(operator_type);
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

Interpolation_Type serializeable_string_to_interpolation_type(string text) {
    return Interpolation_Type(enums.serializeable_interpolation_type.to_value(text));
}

Operator_Type serializeable_string_to_operator_type(string text) {
    return Operator_Type(enums.serializeable_operator_type.to_value(text));
}

Literal_Type serializeable_string_to_literal_type(string text) {
    return Literal_Type(enums.serializeable_literal_type.to_value(text));
}