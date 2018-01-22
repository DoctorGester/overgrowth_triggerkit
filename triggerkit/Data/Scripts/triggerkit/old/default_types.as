// Mainly to have all basic type related functions gathered in one place

enum BasicType {
    BASIC_TYPE_VOID,
    BASIC_TYPE_INT,
    BASIC_TYPE_FLOAT,
    BASIC_TYPE_STRING,
    BASIC_TYPE_BOOL,
    BASIC_TYPE_OBJECT,
    BASIC_TYPE_ITEM,
    BASIC_TYPE_HOTSPOT,
    BASIC_TYPE_CHARACTER,
    BASIC_TYPE_VECTOR,
    BASIC_TYPE_FUNCTION,
    BASIC_TYPE_ARRAY,
    BASIC_TYPE_LAST
}

LiteralType@ LITERAL_TYPE_VOID = LiteralType(BASIC_TYPE_VOID);
LiteralType@ LITERAL_TYPE_INT = LiteralType(BASIC_TYPE_INT);
LiteralType@ LITERAL_TYPE_FLOAT = LiteralType(BASIC_TYPE_FLOAT);
LiteralType@ LITERAL_TYPE_BOOL = LiteralType(BASIC_TYPE_BOOL);
LiteralType@ LITERAL_TYPE_STRING = LiteralType(BASIC_TYPE_STRING);
LiteralType@ LITERAL_TYPE_OBJECT = LiteralType(BASIC_TYPE_OBJECT);
LiteralType@ LITERAL_TYPE_ITEM = LiteralType(BASIC_TYPE_ITEM);
LiteralType@ LITERAL_TYPE_HOTSPOT = LiteralType(BASIC_TYPE_HOTSPOT);
LiteralType@ LITERAL_TYPE_CHARACTER = LiteralType(BASIC_TYPE_CHARACTER);
LiteralType@ LITERAL_TYPE_VECTOR = LiteralType(BASIC_TYPE_VECTOR);

string BasicTypeToString(BasicType type) {
    switch(type) {
        case BASIC_TYPE_VOID: return "BASIC_TYPE_VOID";
        case BASIC_TYPE_INT: return "BASIC_TYPE_INT";
        case BASIC_TYPE_FLOAT: return "BASIC_TYPE_FLOAT";
        case BASIC_TYPE_STRING: return "BASIC_TYPE_STRING";
        case BASIC_TYPE_BOOL: return "BASIC_TYPE_BOOL";
        case BASIC_TYPE_OBJECT: return "BASIC_TYPE_OBJECT";
        case BASIC_TYPE_ITEM: return "BASIC_TYPE_ITEM";
        case BASIC_TYPE_HOTSPOT: return "BASIC_TYPE_HOTSPOT";
        case BASIC_TYPE_CHARACTER: return "BASIC_TYPE_CHARACTER";
        case BASIC_TYPE_VECTOR: return "BASIC_TYPE_VECTOR";
        case BASIC_TYPE_FUNCTION: return "BASIC_TYPE_FUNCTION";
        case BASIC_TYPE_ARRAY: return "BASIC_TYPE_ARRAY";
    }

    return "unknown";
}

BasicType StringToBasicType(string str) {
    for (int i = 0; i < BASIC_TYPE_LAST; i++) {
        if (BasicTypeToString(BasicType(i)) == str) {
            return BasicType(i);
        }
    }

    return BASIC_TYPE_LAST;
} 

string TypeToUIString(ParseTree::Statement@ statement) {
    switch (statement.literalType.basic) {
        case BASIC_TYPE_INT:
            return formatInt(statement.valueInt);
        case BASIC_TYPE_FLOAT:
            return formatFloat(statement.valueFloat);
        case BASIC_TYPE_STRING:
            return "\"" + statement.valueString + "\"";
        case BASIC_TYPE_BOOL:
            return statement.valueBool ? "true" : "false";
        case BASIC_TYPE_OBJECT:
            return "<object>";
        case BASIC_TYPE_ITEM:
            return "<item>";
        case BASIC_TYPE_HOTSPOT:
            return "<hotspot>";
        case BASIC_TYPE_CHARACTER:
            return "<character>";
        case BASIC_TYPE_VECTOR:
            return "point(" + statement.valueVector.x + ", " + statement.valueVector.y + ", " + statement.valueVector.z + ")";
        case BASIC_TYPE_FUNCTION:
            return "<actions>";
        case BASIC_TYPE_ARRAY:
            return "<array>";
    }

    return "<unknown>";
}

void DrawBasicType(ParseTree::Statement@ statement, int index) {
    switch (statement.literalType.basic) {
        case BASIC_TYPE_INT:
            ImGui_InputInt("###LiteralInt" + index, statement.valueInt);
            break;
        case BASIC_TYPE_FLOAT:
            ImGui_InputFloat("###LiteralFloat" + index, statement.valueFloat, 2);
            break;
        case BASIC_TYPE_STRING:
            ImGui_SetTextBuf(statement.valueString);

            if (ImGui_InputText("###DeclarationInput" + index)) {
                statement.valueString = ImGui_GetTextBuf();
            }

            break;
        case BASIC_TYPE_BOOL:
            ImGui_Checkbox("###LiteralFloat" + index, statement.valueBool);
            break;
        case BASIC_TYPE_OBJECT:
            ImGui_Text("Object input here");
            break;
        case BASIC_TYPE_ITEM:
            ImGui_Text("Item input here");
            break;
        case BASIC_TYPE_HOTSPOT:
            ImGui_Text("Hotspot input here");
            break;
        case BASIC_TYPE_CHARACTER:
            ImGui_Text("Character input here");
            break;
        case BASIC_TYPE_VECTOR:
            ImGui_InputFloat3("###LiteralVector" + index, statement.valueVector, 2);
            break;
        case BASIC_TYPE_ARRAY:
            ImGui_Text("Array input here");
            break;
    }
}

string GetBasicTypeName(BasicType type) {
    switch(type) {
        case BASIC_TYPE_VOID: return "Void";
        case BASIC_TYPE_INT: return "Int";
        case BASIC_TYPE_FLOAT: return "Float";
        case BASIC_TYPE_STRING: return "String";
        case BASIC_TYPE_BOOL: return "Bool";
        case BASIC_TYPE_OBJECT: return "Object";
        case BASIC_TYPE_ITEM: return "Item";
        case BASIC_TYPE_HOTSPOT: return "Hotspot";
        case BASIC_TYPE_CHARACTER: return "Character";
        case BASIC_TYPE_VECTOR: return "Vector";
        case BASIC_TYPE_FUNCTION: return "Function";
        case BASIC_TYPE_ARRAY: return "Array";
    }

    return "unknown";
}

AST::Literal@ StatementToLiteral(ParseTree::Statement@ statement, VM::ExecutionContext@ context) {
    switch(statement.literalType.basic) {
        case BASIC_TYPE_INT: return AST::Literal(statement.valueInt);
        case BASIC_TYPE_FLOAT: return AST::Literal(statement.valueFloat);
        case BASIC_TYPE_STRING: return AST::Literal(statement.valueString);
        case BASIC_TYPE_BOOL: return AST::Literal(statement.valueBool);
        case BASIC_TYPE_OBJECT: return AST::ObjectLiteral(LITERAL_TYPE_OBJECT, statement.valueObject);
        case BASIC_TYPE_ITEM: return AST::ObjectLiteral(LITERAL_TYPE_ITEM, statement.valueObject);
        case BASIC_TYPE_HOTSPOT: return AST::ObjectLiteral(LITERAL_TYPE_HOTSPOT, statement.valueObject);
        case BASIC_TYPE_CHARACTER: return AST::ObjectLiteral(LITERAL_TYPE_CHARACTER, statement.valueObject);
        case BASIC_TYPE_VECTOR: return AST::Literal(statement.valueVector);
        case BASIC_TYPE_FUNCTION: return statement.ToFunctionLiteral(context);
        case BASIC_TYPE_ARRAY: return null; // TODO
    }

    return null;
}

JSONValue LiteralValueToJSON(ParseTree::Statement@ statement) {
    JSONValue value;

    switch(statement.literalType.basic) {
        case BASIC_TYPE_INT: value = JSONValue(statement.valueInt); break;
        case BASIC_TYPE_FLOAT: value = JSONValue(statement.valueFloat); break;
        case BASIC_TYPE_STRING: value = JSONValue(statement.valueString); break;
        case BASIC_TYPE_BOOL: value = JSONValue(statement.valueBool); break;
        case BASIC_TYPE_OBJECT:
        case BASIC_TYPE_ITEM:
        case BASIC_TYPE_HOTSPOT:
        case BASIC_TYPE_CHARACTER:
            value = JSONValue(statement.valueObject);
            break;
        case BASIC_TYPE_VECTOR: 
            value = JSONValue();
            value["x"] = JSONValue(statement.valueVector.x);
            value["y"] = JSONValue(statement.valueVector.y);
            value["z"] = JSONValue(statement.valueVector.z);
            break;
        case BASIC_TYPE_FUNCTION:
            value = JSONValue();
            value["arguments"] = JSONValue();

            for (uint i = 0; i < statement.functionArgumentNames.length(); i++) {
                value["arguments"][i] = JSONValue(statement.functionArgumentNames[i]);
            }

            value["statements"] = Persistence::FillStatements(statement.statements);
            break;
        case BASIC_TYPE_ARRAY:
            // TODO
            break;
    }

    return value;
}

void LiteralValueFromJSON(ParseTree::Statement@ statement, JSONValue value) {
    switch(statement.literalType.basic) {
        case BASIC_TYPE_INT: statement.valueInt = value.asInt(); break;
        case BASIC_TYPE_FLOAT: statement.valueFloat = value.asFloat(); break;
        case BASIC_TYPE_STRING: statement.valueString = value.asString(); break;
        case BASIC_TYPE_BOOL: statement.valueBool = value.asBool(); break;
        case BASIC_TYPE_OBJECT:
        case BASIC_TYPE_ITEM:
        case BASIC_TYPE_HOTSPOT:
        case BASIC_TYPE_CHARACTER:
            statement.valueObject = value.asInt();
            break;
        case BASIC_TYPE_VECTOR:
            statement.valueVector = vec3(value["x"].asFloat(), value["y"].asFloat(), value["z"].asFloat());
            break;
        case BASIC_TYPE_FUNCTION:
            statement.statements = Persistence::ReadStatements(value["statements"]);

            for (uint i = 0; i < value["arguments"].size(); i++) {
                statement.functionArgumentNames.insertLast(value["arguments"][i].asString());
            }

            break;
        case BASIC_TYPE_ARRAY:
            // TODO
            break;
    }
}

string GetImplicitCastTo(LiteralType@ fr, LiteralType@ to) {
    if (fr.basic == BASIC_TYPE_INT && to.basic == BASIC_TYPE_FLOAT) {
        return "I2F";
    }

    if (to.basic == BASIC_TYPE_OBJECT) {
        switch (fr.basic) {
            case BASIC_TYPE_ITEM:
                return "ItemToObject";
            case BASIC_TYPE_HOTSPOT:
                return "HotspotToObject";
            case BASIC_TYPE_CHARACTER:
                return "CharacterToObject";
        }
    }

    return "";
}