API::Operator(
    symbol: "+",
    returnType: LITERAL_TYPE_INT,
    type: LITERAL_TYPE_INT,
    executor: function(arguments, context) {
        return AST::Literal(arguments[0].AsInt() + arguments[1].AsInt());
    }
);

API::Operator(
    symbol: "<",
    format: "%s less than %s",
    pretty: "Less than",
    returnType: LITERAL_TYPE_BOOL,
    type: LITERAL_TYPE_INT,
    executor: function(arguments, context) {
        return AST::Literal(arguments[0].AsInt() < arguments[1].AsInt());
    }
);

API::Operator(
    symbol: ">",
    format: "%s greater than %s",
    pretty: "Greater than",
    returnType: LITERAL_TYPE_BOOL,
    type: LITERAL_TYPE_INT,
    executor: function(arguments, context) {
        return AST::Literal(arguments[0].AsInt() > arguments[1].AsInt());
    }
);

API::Operator(
    symbol: "<=",
    format: "%s less than or equal %s",
    pretty: "Less than or equal",
    returnType: LITERAL_TYPE_BOOL,
    type: LITERAL_TYPE_INT,
    executor: function(arguments, context) {
        return AST::Literal(arguments[0].AsInt() <= arguments[1].AsInt());
    }
);

API::Operator(
    symbol: ">=",
    format: "%s greater than or equal %s",
    pretty: "Greater than or equal",
    returnType: LITERAL_TYPE_BOOL,
    type: LITERAL_TYPE_INT,
    executor: function(arguments, context) {
        return AST::Literal(arguments[0].AsInt() >= arguments[1].AsInt());
    }
);

API::Operator(
    symbol: "==",
    format: "%s equal to %s",
    pretty: "Equal to",
    returnType: LITERAL_TYPE_BOOL,
    type: LITERAL_TYPE_STRING,
    executor: function(arguments, context) {
        //Log(info, "OPERATOR " + arguments[0].AsString() + " :: " + arguments[1].AsString());
        //return AST::Literal(arguments[0].AsString() == arguments[1].AsString());
        return AST::Literal(true);
    }
);

API::Native(
    name: "Print",
    pretty: "Print a string",
    format: "Print %s to console",
    returnType: LITERAL_TYPE_VOID,
    arg1: FunctionArgument(LITERAL_TYPE_STRING, "value"),
    executor: function(args, context) {
        Log(info, args[0].AsString());
        return null;
    }
);

API::Native(
    name: "Print",
    pretty: "Print a number",
    format: "Print %s to console",
    returnType: LITERAL_TYPE_VOID,
    arg1: FunctionArgument(LITERAL_TYPE_FLOAT, "value"),
    executor: function(args, context) {
        Log(info, args[0].AsFloat() + "");
        return null;
    }
);

API::Native(
    name: "CreateItem",
    pretty: "Create an item at location",
    format: "Create an item from %s at %s",
    returnType: LITERAL_TYPE_ITEM,
    arg1: FunctionArgument(LITERAL_TYPE_STRING, "file"),
    arg2: FunctionArgument(LITERAL_TYPE_VECTOR, "location"),
    executor: function(args, context) {
        auto pos = args[1].AsVector();
        auto index = CreateObject(args[0].AsString(), true);
        auto item = ReadItemID(index);

        auto mat = mat4();
        mat.SetTranslationPart(pos);

        item.SetPhysicsTransform(mat);

        return AST::ObjectLiteral(LITERAL_TYPE_ITEM, index);
    }
);

API::Native(
    name: "GetHotspotTranslation",
    pretty: "Center of a hotspot",
    format: "Center of %s",
    returnType: LITERAL_TYPE_VECTOR,
    arg1: FunctionArgument(LITERAL_TYPE_HOTSPOT, "object"),
    executor: function(args, context) {
        auto obj = ReadObjectFromID(args[0].AsObject());

        return AST::Literal(obj.GetTranslation());
    }
);

API::Native(
    name: "GetCharacterTranslation",
    pretty: "Location of a character",
    format: "Location of %s",
    returnType: LITERAL_TYPE_VECTOR,
    arg1: FunctionArgument(LITERAL_TYPE_CHARACTER, "object"),
    executor: function(args, context) {
        auto obj = ReadCharacterID(args[0].AsObject());

        return AST::Literal(obj.position);
    }
);

API::Native(
    name: "AttachWeapon",
    pretty: "Give a weapon to a character",
    format: "Give %s to the %s",
    returnType: LITERAL_TYPE_VOID,
    arg1: FunctionArgument(LITERAL_TYPE_ITEM, "weapon"),
    arg2: FunctionArgument(LITERAL_TYPE_CHARACTER, "character"),
    executor: function(args, context) {
        auto character = ReadCharacterID(args[1].AsObject());
        character.Execute("AttachWeapon(" + args[0].AsObject() + ")");
        //character.GetPlayer();

        return null;
    }
);

API::Native(
    name: "GetName",
    pretty: "Object name",
    format: "Name of %s",
    returnType: LITERAL_TYPE_STRING,
    arg1: FunctionArgument(LITERAL_TYPE_OBJECT, "object"),
    executor: function(args, context) {
        auto obj = ReadObjectFromID(args[0].AsObject());

        return AST::Literal(/*obj.GetName()*/"");
    }
);

API::Native(
    name: "IsControlled",
    pretty: "A character is a player",
    format: "%s is a player",
    returnType: LITERAL_TYPE_BOOL,
    arg1: FunctionArgument(LITERAL_TYPE_CHARACTER, "character"),
    executor: function(args, context) {
        auto character = ReadCharacterID(args[1].AsObject());

        return AST::Literal(character.controlled);;
    }
);

API::Native(
    name: "LaunchItem",
    pretty: "Launch an item",
    format: "Launch %s towards %s with the speed of %s",
    returnType: LITERAL_TYPE_VOID,
    arg1: FunctionArgument(LITERAL_TYPE_ITEM, "item"),
    arg2: FunctionArgument(LITERAL_TYPE_VECTOR, "target"),
    arg3: FunctionArgument(LITERAL_TYPE_FLOAT, "speed"),
    executor: function(args, context) {
        auto item = ReadItemID(args[0].AsObject());
        item.ActivatePhysics();
        vec3 pos = item.GetPhysicsPosition();
        Log(info, "" + pos.x + " " + pos.y + " " + pos.z);
        item.SetThrown();
        item.SetThrownStraight();
        
        item.SetLinearVelocity(normalize(args[1].AsVector() - pos) * args[2].AsFloat());

        return null;
    }
);

// :: Implicit cast natives ::

API::Native(
    name: "I2F",
    pretty: "Integer to Decimal",
    format: "Convert %s to decimal",
    returnType: LITERAL_TYPE_FLOAT,
    arg1: FunctionArgument(LITERAL_TYPE_INT, "value"),
    executor: function(args, context) {
        return AST::Literal(float(args[0].AsInt()));
    }
);

API::Native(
    name: "HotspotToObject",
    pretty: "Convert Hotspot to Object",
    format: "Convert %s to an Object",
    returnType: LITERAL_TYPE_OBJECT,
    arg1: FunctionArgument(LITERAL_TYPE_HOTSPOT, "hotspot"),
    executor: function(args, context) {
        return AST::ObjectLiteral(LITERAL_TYPE_OBJECT, args[0].AsObject());
    }
);

API::Native(
    name: "CharacterToObject",
    pretty: "Convert Character to Object",
    format: "Convert %s to an Object",
    returnType: LITERAL_TYPE_OBJECT,
    arg1: FunctionArgument(LITERAL_TYPE_CHARACTER, "character"),
    executor: function(args, context) {
        return AST::ObjectLiteral(LITERAL_TYPE_OBJECT, args[0].AsObject());
    }
);

// :: Events ::

API::Native(
    name: "OnRegionEntered",
    pretty: "Character enters a region",
    format: "When a character enters a region, do",
    isDefaultEvent: true,
    returnType: LITERAL_TYPE_VOID,
    arg1: FunctionArgument(LiteralType(LITERAL_TYPE_CHARACTER, LITERAL_TYPE_HOTSPOT, LITERAL_TYPE_VOID), "actions"),
    executor: function(args, context) {
        context.globalState.AddMessageHandler("region_enter", args[0]);

        return null;
    }
);

// :: Converters ::

API::Converter("region_enter", function(tokens) {
    AST::Expression@[] result = {
        AST::ObjectLiteral(LITERAL_TYPE_CHARACTER, atoi(tokens[0])),
        AST::ObjectLiteral(LITERAL_TYPE_HOTSPOT, atoi(tokens[1]))
    };

    return result;
});