class Variable {
    Literal_Type type;
    Memory_Cell value;
    string name;
}

Variable@ make_variable(Literal_Type type, string name, Memory_Cell@ value = null) {
    Variable variable;
    variable.type = type;
    variable.name = name;
    variable.value = value;

    return variable;
}

void collect_scope_variables(Variable_Scope@ from_scope, array<Variable@>@ target, Literal_Type limit_to = LITERAL_TYPE_VOID) {
    // TODO Variable shadowing duplicates variables!
    for (uint variable_index = 0; variable_index < from_scope.variables.length(); variable_index++) {
        if (limit_to == LITERAL_TYPE_VOID || limit_to == from_scope.variables[variable_index].type) {
            target.insertLast(from_scope.variables[variable_index]);
        }
    }

    if (from_scope.parent_scope !is null) {
        collect_scope_variables(from_scope.parent_scope, target, limit_to);
    }
}

bool validate_hotspot_id(int hotspot_id, string expected_type) {
    if (!ObjectExists(hotspot_id)) {
        return false;
    }

    Object@ hotspot = ReadObjectFromID(hotspot_id);

    if (hotspot.GetType() != _hotspot_object) {
        return false;
    }

    if (cast<Hotspot@>(hotspot).GetTypeString() != expected_type) {
        return false;
    }

    return true;
}

bool validate_character_id(int character_id) {
    if (!ObjectExists(character_id)) {
        return false;
    }

    Object@ object = ReadObjectFromID(character_id);

    if (object.GetType() != _movement_object) {
        return false;
    }

    if (object.IsExcludedFromSave()) {
        return false;
    }

    return true;
}

Literal_Type determine_expression_literal_type(Expression@ expression, Variable_Scope@ variable_scope) {
    switch (expression.type) {
        case EXPRESSION_LITERAL: return expression.literal_type;
        case EXPRESSION_IDENTIFIER: {
            bool found_variable;
            Variable@ variable = find_scope_variable_by_name(expression.identifier_name, variable_scope, found_variable);

            if (found_variable) {
                return variable.type;
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