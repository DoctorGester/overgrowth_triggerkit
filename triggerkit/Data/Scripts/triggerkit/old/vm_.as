namespace VM {
    funcdef AST::Literal@ FunctionExecutor(AST::Literal@[] arguments, ExecutionContext@ context);
    funcdef AST::Expression@[] MessageConverter(string[] args);

    class ScopeVariable {
        string name;
        LiteralType@ type;
        AST::Literal@ value;

        ScopeVariable(string name, LiteralType@ type, AST::Literal@ value) {
            this.name = name;
            @this.type = type;
            @this.value = value;
        }
    }

    class GlobalScriptState {
        ExecutionScope@ globalScope = ExecutionScope(false);
        ExecutionContext@[] scriptThreads;
        dictionary messageHandlers;
        dictionary messageConverters;

        GlobalScriptState() {
            @globalScope.globalState = this;
        }

        LiteralType@ RegisterNativeFunction(FunctionExecutor@ executor, string name, LiteralType@ returnType, FunctionArgument@[] args) {
            AST::Expression@[] resultArguments;

            for (uint i = 0; i < args.length(); i++) {
                resultArguments.insertLast(AST::Variable(args[i].type, args[i].name));
            }

            AST::Node@[] statements = { AST::Return(AST::NativeFunctionCall(executor, resultArguments)) };

            auto type = ArgumentsToLiteralType(args, returnType);

            globalScope.DeclareFunction(
                name,
                type,
                AST::Literal(FunctionLiteral(args, returnType, statements))
            );

            return type;
        }

        void RegisterMessageConverter(string type, MessageConverter@ converter) {
            @messageConverters[type] = converter;
        }

        void AddMessageHandler(string type, AST::Literal@ functionLiteral) {
            Log(info, "Add handler for '" + type + "' of type " + functionLiteral.ToString());

            AST::Expression@[] handlers;

            if (!messageHandlers.exists(type)) {
                handlers = array<AST::Expression@> = { functionLiteral };
                messageHandlers[type] = handlers;
            } else {
                handlers = cast<AST::Expression@[]>(messageHandlers[type]);
                handlers.insertLast(functionLiteral);
                messageHandlers[type] = handlers;
            }
        }

        void ReceiveMessage(string message) {
            string[] tokens;

            TokenIterator iterator;
            iterator.Init();

            while (iterator.FindNextToken(message)){
                tokens.insertLast(iterator.GetToken(message));
            }

            Log(info, "In receive " + message);

            if (tokens.length() == 0) {
                Log(info, "No tokens to process");
                return;
            }

            string messageType = tokens[0];
            string[] remainingTokens;

            Log(info, "Message type: '" + messageType + "' " + messageHandlers.exists(messageType));

            if (tokens.length() > 1) {
                remainingTokens = tokens;
                remainingTokens.removeAt(0);
            }

            if (!messageConverters.exists(messageType)) {
                Log(info, "Tried to process a message of unknown type '" + messageType + "'");
                return;
            }

            auto convertedValues = cast<MessageConverter@>(messageConverters[messageType])(remainingTokens);

            if (messageHandlers.exists(messageType)) {
                auto handlers = cast<AST::Expression@[]>(messageHandlers[messageType]);

                for (uint i = 0; i < handlers.length(); i++) {
                    Execute(AST::FunctionCall(
                        handlers[i],
                        convertedValues
                    ));
                }
            }
        }

        ExecutionContext@ CreateContext() {
            ExecutionContext context(this);

            //scriptThreads.insertLast(context);

            return context;
        }

        void Execute(AST::Node@[] nodes) {
            CreateContext().Execute(nodes);
        }

        void Execute(AST::Node@ node) {
            node.Execute(CreateContext());
        }
    }

    class ExecutionContext {
        GlobalScriptState@ globalState;
        array<ExecutionScope@> scopeStack;
        uint blockedAt;
        uint blockedUntil;

        //Node@[] currentExecutionQueue;
        int queuePosition;

        ExecutionContext(GlobalScriptState@ state) {
            @globalState = state;
            scopeStack.insertLast(state.globalScope);
        }

        void Push(bool disconnected = false) {
            ExecutionScope newScope(disconnected);

            scopeStack.insertLast(newScope);
        }

        void Pop() {
            scopeStack.removeLast();
        }

        ExecutionScope@ Peek() {
            return scopeStack[scopeStack.length() - 1];
        }

        ScopeVariable@[]@ LookupVariable(string name) {
            for (int i = int(scopeStack.length()) - 1; i >= 0; i--) {
                auto scope = scopeStack[i];
                auto found = scope.FindByName(name);

                if (found.length() > 0) {
                    return found;
                }

                if (scope.disconnected) {
                    i = 1;
                }
            }

            return null;
        }

        ScopeVariable@ LookupVariable(string name, LiteralType@ type) {
            auto found = LookupVariable(name);

            if (found !is null) {
                for (uint i = 0; i < found.length(); i++) {
                    if (found[i].type == type) {
                        return found[i];
                    }
                }
            }

            return null;
        }

        ScopeVariable@[]@ LookupAllByBasicType(BasicType type) {
            ScopeVariable@[] result;

            if (scopeStack.length() == 0) {
                return result;
            }

            for (int i = int(scopeStack.length()) - 1; i >= 0; i--) {
                auto scope = scopeStack[i];

                scope.LookupAllByBasicType(result, type);

                if (scope.disconnected) {
                    i = 1;
                }
            }

            return result;
        }

        ScopeVariable@[]@ LookupAllByType(LiteralType@ type) {
            ScopeVariable@[] result;

            if (scopeStack.length() == 0) {
                return result;
            }

            for (int i = int(scopeStack.length()) - 1; i >= 0; i--) {
                auto scope = scopeStack[i];

                scope.LookupAllByType(result, type);

                if (scope.disconnected) {
                    i = 1;
                }
            }

            return result;
        }

        ScopeVariable@[]@ LookupAllByReturnType(LiteralType@ type) {
            ScopeVariable@[] result;

            if (scopeStack.length() == 0) {
                return result;
            }

            for (int i = int(scopeStack.length()) - 1; i >= 0; i--) {
                auto scope = scopeStack[i];

                scope.LookupAllByReturnType(result, type);

                if (scope.disconnected) {
                    i = 1;
                }
            }

            return result;
        }

        bool AssignVariable(string name, AST::Literal@ value) {
            ScopeVariable@ found = LookupVariable(name, value.type);

            if (found !is null) {
                @found.value = value;
                
                return true;
            } else {
                TriggerKitException("Trying to assign to a non-existent variable " + name);
            }

            return false;
        }

        void DeclareFunction(string name, LiteralType@ type) {
            Peek().DeclareFunction(name, type);
        }

        void DeclareVariable(string name, LiteralType@ type) {
            Peek().DeclareVariable(name, type);
        }

        void Update() {
            for (uint i = 0; i < scopeStack.length(); i++) {

            }
        }

        AST::Literal@ Execute(AST::Node@[] nodes) {
            Push();
            auto result = ExecuteRaw(nodes);
            Pop();

            return result;
        }

        AST::Literal@ ExecuteRaw(AST::Node@[] nodes) {
            for (uint i = 0; i < nodes.length(); i++) {
                Log(info, nodes[i].ToString());
                nodes[i].Execute(this);

                if (Peek().returnValue !is null) {
                    return Peek().returnValue;
                }
            }

            return null;
        }
    }

    class ExecutionScope {
        GlobalScriptState@ globalState;
        ExecutionContext@ parent;
        ScopeVariable@[] variables = {};

        AST::Literal@ returnValue;

        bool disconnected;

        ExecutionScope(bool disconnected) {
            this.disconnected = disconnected;
        }

        ScopeVariable@[]@ FindByName(string name) {
            ScopeVariable@[] result;

            for (uint i = 0; i < variables.length(); i++) {
                if (variables[i].name == name) {
                    result.insertLast(variables[i]);
                }
            }

            return result;
        }

        void DeclareFunction(string name, LiteralType@ type, AST::Literal@ value = null) {
            variables.insertLast(ScopeVariable(name, type, value));
        }

        void DeclareVariable(string name, LiteralType@ type) {
            if (FindByName(name).length() == 0) {
                variables.insertLast(ScopeVariable(name, type, null));
            } else {
                //TriggerKitException("Attempted to redeclare an existing variable " + name);
            }
        }

        ScopeVariable@[]@ LookupAllByReturnType(ScopeVariable@[]@ result, LiteralType@ type) {
            for (uint i = 0; i < variables.length(); i++) {
                auto t = variables[i].type;
                if (t.basic == BASIC_TYPE_FUNCTION && (type is null || t.returnType == type)) {
                    result.insertLast(variables[i]);
                }
            }

            return result;
        }

        ScopeVariable@[]@ LookupAllByBasicType(ScopeVariable@[]@ result, BasicType type) {
            for (uint i = 0; i < variables.length(); i++) {
                if (variables[i].type.basic == type) {
                    result.insertLast(variables[i]);
                }
            }

            return result;
        }

        ScopeVariable@[]@ LookupAllByType(ScopeVariable@[]@ result, LiteralType@ type) {
            for (uint i = 0; i < variables.length(); i++) {
                if (type is null || (variables[i].type == type || GetImplicitCastTo(variables[i].type, type).length() > 0)) {
                    result.insertLast(variables[i]);
                }
            }

            return result;
        }
    }

}