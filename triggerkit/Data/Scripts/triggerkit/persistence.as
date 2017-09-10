namespace Persistence {
    const string PARAM_NAME = "TriggerKit/Triggers";

    string StatementTypeToString(ParseTree::StatementType type) {
        switch(type) {
            case STATEMENT_TYPE_DECLARATION: return "STATEMENT_TYPE_DECLARATION";
            case STATEMENT_TYPE_ASSIGNMENT: return "STATEMENT_TYPE_ASSIGNMENT";
            case STATEMENT_TYPE_FOR_LOOP: return "STATEMENT_TYPE_FOR_LOOP";
            case STATEMENT_TYPE_REPEAT_LOOP: return "STATEMENT_TYPE_REPEAT_LOOP";
            case STATEMENT_TYPE_CONDITION: return "STATEMENT_TYPE_CONDITION";
            case STATEMENT_TYPE_VARIABLE: return "STATEMENT_TYPE_VARIABLE";
            case STATEMENT_TYPE_LITERAL: return "STATEMENT_TYPE_LITERAL";
            case STATEMENT_TYPE_BI_FUNCTION: return "STATEMENT_TYPE_BI_FUNCTION";
            case STATEMENT_TYPE_FUNCTION_CALL: return "STATEMENT_TYPE_FUNCTION_CALL";
        }

        return "<none>";
    }

    JSONValue LiteralTypeToJSON(LiteralType@ type) {
        JSONValue result;
        result["basic"] = JSONValue(BasicTypeToString(type.basic));

        if (type.returnType !is null) {
            result["returnType"] = JSONValue(LiteralTypeToJSON(type.returnType));
        }

        if (type.parameters.length() > 0) {
            result["parameters"] = JSONValue();

            for (uint i = 0; i < type.parameters.length(); i++) {
                result["parameters"][i] = LiteralTypeToJSON(type.parameters[i]);
            }
        }

        return result;
    }

    ParseTree::StatementType StringToStatementType(string str) {
        for (int i = 0; i < STATEMENT_TYPE_LAST; i++) {
            if (StatementTypeToString(StatementType(i)) == str) {
                return StatementType(i);
            }
        }

        return STATEMENT_TYPE_LAST;
    } 

    LiteralType@ JSONToLiteralType(JSONValue value) {
        LiteralType result(StringToBasicType(value["basic"].asString()));

        if (value.isMember("parameters")) {
            for (uint i = 0; i < value["parameters"].size(); i++) {
                result.parameters.insertLast(JSONToLiteralType(value["parameters"][i]));
            }
        }

        if (value.isMember("returnType")) {
            @result.returnType = JSONToLiteralType(value["returnType"]);
        }

        return result;
    }

    JSONValue ToJSON(ParseTree::Statement@ statement) {
        JSONValue value;

        value["type"] = JSONValue(StatementTypeToString(statement.type));

        switch (statement.type) {
            case STATEMENT_TYPE_DECLARATION:
            case STATEMENT_TYPE_ASSIGNMENT:
            case STATEMENT_TYPE_VARIABLE:
            case STATEMENT_TYPE_FUNCTION_CALL:
            case STATEMENT_TYPE_BI_FUNCTION:
                value["name"] = JSONValue(statement.name);
                break;
        }

        switch (statement.type) {
            case STATEMENT_TYPE_DECLARATION:
            case STATEMENT_TYPE_LITERAL:
                value["literalType"] = JSONValue(LiteralTypeToJSON(statement.literalType));
                break;
        }

        switch (statement.type) {
            case STATEMENT_TYPE_FOR_LOOP:
            case STATEMENT_TYPE_REPEAT_LOOP:
            case STATEMENT_TYPE_BI_FUNCTION:
            case STATEMENT_TYPE_FUNCTION_CALL:
            case STATEMENT_TYPE_CONDITION:
                value["statements"] = FillStatements(statement.statements);
                break;
        }

        switch (statement.type) {
            case STATEMENT_TYPE_DECLARATION:
            case STATEMENT_TYPE_ASSIGNMENT:
            case STATEMENT_TYPE_CONDITION:
            case STATEMENT_TYPE_FOR_LOOP:
            case STATEMENT_TYPE_REPEAT_LOOP:
                if (statement.value !is null) {
                    value["value"] = ToJSON(statement.value);
                }
                
                break;
        }

        switch (statement.type) {
            case STATEMENT_TYPE_FOR_LOOP:
                if (statement.pre !is null) {
                    value["pre"] = ToJSON(statement.pre);
                }

                if (statement.post !is null) {
                    value["post"] = ToJSON(statement.post);
                }

                break;

            case STATEMENT_TYPE_CONDITION:
                if (statement.elseStatements !is null) {
                    value["elseStatements"] = FillStatements(statement.elseStatements);
                }

                break;

            case STATEMENT_TYPE_LITERAL:
                value["literalValue"] = LiteralValueToJSON(statement);
                break;
        }

        return value;
    }

    JSONValue FillStatements(ParseTree::Statement@[] statements) {
        JSONValue value;

        for (uint i = 0; i < statements.length(); i++) {
            value[i] = ToJSON(statements[i]);
        }

        return value;
    }

    ParseTree::Statement@[] ReadStatements(JSONValue value) {
        ParseTree::Statement@[] result;

        for (uint i = 0; i < value.size(); i++) {
            result.insertLast(FromJSON(value[i]));
        }

        return result;
    }

    ParseTree::Statement@ FromJSON(JSONValue value) {
        ParseTree::StatementType type = StringToStatementType(value["type"].asString());
        ParseTree::Statement statement(type);

        switch (type) {
            case STATEMENT_TYPE_DECLARATION:
            case STATEMENT_TYPE_ASSIGNMENT:
            case STATEMENT_TYPE_VARIABLE:
            case STATEMENT_TYPE_FUNCTION_CALL:
            case STATEMENT_TYPE_BI_FUNCTION:
                statement.name = value["name"].asString();
                break;
        }

        switch (statement.type) {
            case STATEMENT_TYPE_DECLARATION:
            case STATEMENT_TYPE_LITERAL:
                @statement.literalType = JSONToLiteralType(value["literalType"]);
                break;
        }

        switch (statement.type) {
            case STATEMENT_TYPE_FOR_LOOP:
            case STATEMENT_TYPE_REPEAT_LOOP:
            case STATEMENT_TYPE_BI_FUNCTION:
            case STATEMENT_TYPE_FUNCTION_CALL:
            case STATEMENT_TYPE_CONDITION:
                statement.statements = ReadStatements(value["statements"]);
                break;
        }

        switch (statement.type) {
            case STATEMENT_TYPE_DECLARATION:
            case STATEMENT_TYPE_ASSIGNMENT:
            case STATEMENT_TYPE_CONDITION:
            case STATEMENT_TYPE_FOR_LOOP:
            case STATEMENT_TYPE_REPEAT_LOOP:
                if (value.isMember("value")) {
                    @statement.value = FromJSON(value["value"]);
                }
                
                break;
        }

        switch (statement.type) {
            case STATEMENT_TYPE_FOR_LOOP:
                if (value.isMember("pre")) {
                    @statement.pre = FromJSON(value["pre"]);
                }

                if (value.isMember("post")) {
                    @statement.post = FromJSON(value["post"]);
                }

                break;

            case STATEMENT_TYPE_CONDITION:
                if (value.isMember("elseStatements")) {
                    statement.elseStatements = ReadStatements(value["elseStatements"]);
                }

                break;

            case STATEMENT_TYPE_LITERAL:
                LiteralValueFromJSON(statement, value["literalValue"]);
                break;
        }

        return statement;
    }

    void Save(Trigger@[] triggers) {
        JSON json;

        json.getRoot()["triggers"] = JSONValue();

        for (uint i = 0; i < triggers.length(); i++) {
            auto tr = JSONValue();
            tr["name"] = JSONValue(triggers[i].name);
            tr["description"] = JSONValue(triggers[i].description);
            tr["statement"] = ToJSON(triggers[i].triggerFunction);
            json.getRoot()["triggers"][i] = tr;
        }
        
        auto params = level.GetScriptParams();

        if (params.HasParam(PARAM_NAME)) {
            params.Remove(PARAM_NAME);
        }

        params.AddJSON(PARAM_NAME, json);
    }

    Trigger@[] Load() {
        Trigger@[] result;

        if (level.GetScriptParams().HasParam(PARAM_NAME)) {
            JSON json = level.GetScriptParams().GetJSON(PARAM_NAME);

            auto root = json.getRoot()["triggers"];

            for (uint i = 0; i < root.size(); i++) {
                Trigger tr(root[i]["name"].asString());
                tr.description = root[i]["description"].asString();
                @tr.triggerFunction = FromJSON(root[i]["statement"]);

                result.insertLast(tr);
            }            
        }

        return result;
    }
}