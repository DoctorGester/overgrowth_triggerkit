class LiteralType {
    BasicType basic;
    LiteralType@[] parameters;
    LiteralType@ returnType;
    string token;

    LiteralType(BasicType basic) {
        this.basic = basic;
    }

    LiteralType(string token) {
        this.token = token;
    }

    LiteralType(BasicType basic, string token) {
        this.basic = basic;
        parameters.insertLast(LiteralType(token));
    }

    LiteralType(LiteralType@[] parameters, LiteralType@ returnType) {
        basic = BASIC_TYPE_FUNCTION;
        this.parameters = parameters;
        @this.returnType = returnType;
    }

    LiteralType(LiteralType@ param1, LiteralType@ param2, LiteralType@ returnType) {
        basic = BASIC_TYPE_FUNCTION;
        parameters.insertLast(param1);
        parameters.insertLast(param2);
        @this.returnType = returnType;
    }

    LiteralType(LiteralType@ returnType) {
        basic = BASIC_TYPE_FUNCTION;
        @this.returnType = returnType;
    }

    string ToString() {
        string basic = GetBasicTypeName(this.basic);

        if (parameters.length() == 0) {
            return basic;
        }

        string[] parameters;

        for (uint i = 0; i < this.parameters.length(); i++) {
            parameters.insertLast(this.parameters[i].ToString());
        }

        return basic + "<" + join(parameters, ", ") + "> -> " + returnType.ToString();
    }

    bool opEquals(LiteralType@ to) {
        if (to is null) {
            return false;
        }

        if (basic != to.basic) {
            return false;
        }

        if (parameters.length() != to.parameters.length()) {
            return false;
        }

        for (uint i = 0; i < parameters.length(); i++) {
            if (parameters[i] != to.parameters[i]) {
                return false;
            }
        }

        return true;
    }
}

enum StatementType {
    STATEMENT_TYPE_NONE,

    // Statements
    STATEMENT_TYPE_DECLARATION,
    STATEMENT_TYPE_ASSIGNMENT,
    STATEMENT_TYPE_FOR_LOOP,
    STATEMENT_TYPE_REPEAT_LOOP,
    STATEMENT_TYPE_CONDITION,

    // Expressions
    STATEMENT_TYPE_VARIABLE,
    STATEMENT_TYPE_LITERAL,
    STATEMENT_TYPE_BI_FUNCTION,
    STATEMENT_TYPE_FUNCTION_CALL,

    STATEMENT_TYPE_LAST
}

class FunctionArgument {
    LiteralType@ type;
    string name;

    FunctionArgument(LiteralType@ type, string name) {
        @this.type = type;
        this.name = name;
    }
}

class FunctionLiteral {
    FunctionArgument@[] arguments;
    AST::Node@[] nodes;
    LiteralType@ returnType;

    FunctionLiteral(FunctionArgument@[] arguments, LiteralType@ returnType, AST::Node@[] nodes = array<AST::Node@>()) {
        this.arguments = arguments;
        this.nodes = nodes;
        @this.returnType = returnType;
    }
}

LiteralType@ ArgumentsToLiteralType(FunctionArgument@[] arguments, LiteralType@ returnType) {
    LiteralType@[] params;

    for (uint i = 0; i < arguments.length(); i++) {
        params.insertLast(arguments[i].type);
    }

    return LiteralType(params, returnType);
}

string GetTypeName(LiteralType@ type) {
    if (type is null) {
        //PrintCallstack();
        return "<unknown type>";
    }

    return type.ToString();
}

string GetStatementName(StatementType type) {
    switch(type) {
        case STATEMENT_TYPE_NONE: return "Nothing";
        case STATEMENT_TYPE_DECLARATION: return "Declaration";
        case STATEMENT_TYPE_ASSIGNMENT: return "Assignment";
        case STATEMENT_TYPE_FOR_LOOP: return "For Loop";
        case STATEMENT_TYPE_REPEAT_LOOP: return "Repeat";
        case STATEMENT_TYPE_CONDITION: return "If/Then/Else";
        case STATEMENT_TYPE_VARIABLE: return "Variable";
        case STATEMENT_TYPE_LITERAL: return "Literal";
        case STATEMENT_TYPE_BI_FUNCTION: return "Operator";
        case STATEMENT_TYPE_FUNCTION_CALL: return "Action";
    }

    return "<none>";
}

void TriggerKitException(string error) {
    //PrintCallstack();
    DisplayError("TriggerKit", error);
}

string StringTrim(string value) {
    for (int i = 0; i < int(value.length()); i++) {
        if (value[i] == " "[0] && (i == 0 || i == int(value.length()) - 1)) {
            value.erase(i, 1);
            i--;
        }
    }

    return value;
}
