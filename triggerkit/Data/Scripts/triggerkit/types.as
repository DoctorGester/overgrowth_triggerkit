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
        case LITERAL_TYPE_VECTOR_3: return "Vector3";
        case LITERAL_TYPE_FUNCTION: return "Function";
        case LITERAL_TYPE_CAMERA: return "Camera";
        case LITERAL_TYPE_ARRAY: return "Array";
    }

    return "unknown";
}

string literal_to_serializeable_string(Literal_Type literal_type, Memory_Cell@ literal_value) {
    switch (literal_type) {
        case LITERAL_TYPE_CAMERA:
        case LITERAL_TYPE_NUMBER:
            return literal_value.number_value + "";

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
    }

    return literal_type_to_serializeable_string(literal_type);
}

string literal_to_ui_string(Literal_Type literal_type, Memory_Cell@ value) {
    switch (literal_type) {
        case LITERAL_TYPE_CAMERA: return colored_literal("<") + camera_id_to_camera_name(int(value.number_value)) + colored_literal(">");
        case LITERAL_TYPE_NUMBER: return colored_literal(value.number_value + "");
        case LITERAL_TYPE_STRING: return string_color + "\"" + value.string_value + "\"" + default_color;
        case LITERAL_TYPE_BOOL: return colored_literal(number_to_bool(value.number_value) ? "True" : "False");
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