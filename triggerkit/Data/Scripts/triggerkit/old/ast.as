namespace AST {
    Literal@ ObjectLiteral(LiteralType@ type, uint id) {
        Literal result(type);
        result.valueObject = id;

        return result;
    }

    interface Node {
        void Execute(VM::ExecutionContext@ context);

        string ToString();
    }

    class Expression : Node {
        Literal@ Evaluate(VM::ExecutionContext@ context) {
            return null;
        }

        void Execute(VM::ExecutionContext@ context) override {
            Evaluate(context);
        }

        string ToString() override {
            return "Expression";
        }
    }

    class Declaration : Node {
        string name;
        LiteralType@ type;
        Expression@ value;

        Declaration(string name, LiteralType@ type, Expression@ value) {
            this.name = name;
            @this.type = type;
            @this.value = value;
        }

        void Execute(VM::ExecutionContext@ context) override {
            context.DeclareVariable(name, type);
            context.AssignVariable(name, value.Evaluate(context));
        }

        string ToString() override {
            return "Declaration(" + name + ":" + GetTypeName(type) + ")";
        }
    }

    class Assignment : Node {
        string name;
        Expression@ value;

        Assignment(string name, Expression@ value) {
            this.name = name;
            @this.value = value;
        }

        void Execute(VM::ExecutionContext@ context) override {
            context.AssignVariable(name, value.Evaluate(context));
        }

        string ToString() override {
            return "Assignment(" + name + " = ...)";
        }
    }

    class ForLoop : Node {
        Node@ pre;
        Node@ post;
        Expression@ condition;
        Node@[] nodes;

        ForLoop(Node@ pre, Expression@ condition, Node@ post, Node@[] nodes) {
            @this.pre = pre;
            @this.condition = condition;
            @this.post = post;
            this.nodes = nodes;
        }

        void Execute(VM::ExecutionContext@ context) override {
            context.Push();

            if (pre !is null) {
                pre.Execute(context);
            }

            while(true) {
                if (condition !is null) {
                    if (!condition.Evaluate(context).AsBool()) {
                        break;
                    }
                }

                context.Execute(nodes);

                if (post !is null) {
                    post.Execute(context);
                }
            }

            context.Pop();
        }

        string ToString() override {
            return "ForLoop(...)";
        }
    }

    class Condition : Node {
        Expression@ condition;
        Node@[] thenNodes;
        Node@[] elseNodes;

        Condition(Expression@ condition, Node@[] thenNodes, Node@[] elseNodes) {
            @this.condition = condition;
            this.thenNodes = thenNodes;
            this.elseNodes = elseNodes;
        }

        void Execute(VM::ExecutionContext@ context) override {
            if (condition.Evaluate(context).AsBool()) {
                context.Execute(thenNodes);
            } else {
                context.Execute(elseNodes);
            }
        }

        string ToString() override {
            return "Condition(...)";
        }
    }

    class Return : Node {
        Expression@ value;

        Return(Expression@ value) {
            @this.value = value;
        }

        void Execute(VM::ExecutionContext@ context) override {
            @context.Peek().returnValue = this.value.Evaluate(context);
        }

        string ToString() override {
            return "Return(" + value.ToString() + ")";
        }
    }

    class Variable : Expression {
        LiteralType@ type;
        string name;

        Variable(LiteralType@ type, string name) {
            @this.type = type;
            this.name = name;
        }

        Literal@ Evaluate(VM::ExecutionContext@ context) override {
            Log(info, "Variable access: " + name + ":" + GetTypeName(type));
            return context.LookupVariable(name, type).value;
        }

        string ToString() override {
            return "Variable(" + name + ":" + GetTypeName(type) + ")";
        }
    }

    class FunctionCall : Expression {
        Expression@ function;
        Expression@[] arguments;

        FunctionCall(Expression@ function, Expression@[] arguments) {
            @this.function = function;
            this.arguments = arguments;
        }

        Literal@ Evaluate(VM::ExecutionContext@ context) override {
            Literal@[] resolvedArguments;

            for (uint i = 0; i < arguments.length(); i++) {
                resolvedArguments.insertLast(arguments[i].Evaluate(context));
            }

            FunctionLiteral@ candidate = function.Evaluate(context).AsFunction();

            Log(info, "Call :: " + function.ToString());

            context.Push();

            for (uint i = 0; i < arguments.length(); i++) {
                Log(info, "Function argument :: " + i + " :: " + candidate.arguments[i].type.ToString() + " :: " + candidate.arguments[i].name);

                context.DeclareVariable(
                    candidate.arguments[i].name,
                    candidate.arguments[i].type
                );

                context.AssignVariable(
                    candidate.arguments[i].name,
                    resolvedArguments[i]
                );
            }

            auto value = context.ExecuteRaw(candidate.nodes);
            context.Pop();

            return value;
        }

        string ToString() override {
            return "FunctionCall(...)";
        }
    }

    class NativeFunctionCall : Expression {
        VM::FunctionExecutor@ executor;
        Expression@[] arguments;

        NativeFunctionCall(VM::FunctionExecutor@ executor, Expression@[] arguments) {
            @this.executor = executor;
            this.arguments = arguments;
        }

        Literal@ Evaluate(VM::ExecutionContext@ context) override {
            Literal@[] resolvedArguments;

            for (uint i = 0; i < arguments.length(); i++) {
                resolvedArguments.insertLast(arguments[i].Evaluate(context));
            }

            return executor(resolvedArguments, context);
        }

        string ToString() override {
            return "NativeFunctionCall(...)";
        }
    }

    class Literal : Expression {
        LiteralType@ type;

        int valueInt;
        bool valueBool;
        float valueFloat;
        string valueString;
        uint valueObject;
        vec3 valueVector;
        FunctionLiteral@ valueFunction;

        Literal(LiteralType@ type) {
            @this.type = type;
        }

        Literal(int value) {
            @this.type = LITERAL_TYPE_INT;
            this.valueInt = value;
        }

        Literal(string value) {
            @this.type = LITERAL_TYPE_STRING;
            this.valueString = value;
        }

        Literal(float value) {
            @this.type = LITERAL_TYPE_FLOAT;
            this.valueFloat = value;
        }

        Literal(bool value) {
            @this.type = LITERAL_TYPE_BOOL;
            this.valueBool = value;
        }

        Literal(vec3 value) {
            @this.type = LITERAL_TYPE_VECTOR;
            this.valueVector = value;
        }

        Literal(FunctionLiteral@ func) {
            @this.type = ArgumentsToLiteralType(func.arguments, func.returnType);
            @this.valueFunction = func;
        }

        int AsInt() {
            return valueInt;
        }

        bool AsBool() {
            return valueBool;
        }

        float AsFloat() {
            return valueFloat;
        }

        string AsString() {
            return valueString;
        }

        vec3 AsVector() {
            return valueVector;
        }

        FunctionLiteral@ AsFunction() {
            return valueFunction;
        }

        uint AsObject() {
            return valueObject;
        }

        Literal@ Evaluate(VM::ExecutionContext@ context) override {
            // Log(info, "Evaluating literal " + GetTypeName(type));

            return this;
        }

        string ToString() override {
            switch(type.basic) {
                case BASIC_TYPE_INT: return valueInt + "";
                case BASIC_TYPE_FLOAT: return valueFloat + "";
                case BASIC_TYPE_STRING: return valueString;
                case BASIC_TYPE_BOOL: return valueBool ? "true" : "false";
                case BASIC_TYPE_OBJECT: return "Object<" + valueObject + ">";
                case BASIC_TYPE_FUNCTION: return "Function";
            }

            return "";
        }
    }

}