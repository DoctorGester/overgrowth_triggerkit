namespace ParseTree {

    LiteralType@ InferExpressionType(VM::ExecutionContext@ context, Statement@ expression) {
        switch (expression.type) {
            case STATEMENT_TYPE_VARIABLE:
                {
                    auto vars = context.LookupVariable(expression.name);

                    if (vars is null) {
                        return LITERAL_TYPE_VOID;
                    }

                    return vars[0].type;
                }
            case STATEMENT_TYPE_LITERAL:
                return expression.literalType;
            case STATEMENT_TYPE_FUNCTION_CALL:
            case STATEMENT_TYPE_BI_FUNCTION:
                {
                    auto result = expression.FindFittingFunction(context);

                    if (result is null) {
                        return LITERAL_TYPE_VOID;
                    }

                    return result.returnType;
                }
            default:
                TriggerKitException("Incorrect statement type passed to a function: " + GetStatementName(expression.type));
                return LITERAL_TYPE_VOID;
        }

        return LITERAL_TYPE_VOID;
    }

    funcdef Statement@ FunctionExecutor(array<Statement@> arguments);

    class Statement {
        StatementType type;

        // Variable
        // Declaration
        // Assignment
        // FunctionCall
        string name;

        // Assignment
        // Declaration
        // Condition (expression)
        // ForLoop (condition)
        Statement@ value;

        // Literal
        // Declaration
        LiteralType@ literalType = LITERAL_TYPE_VOID;

        // ForLoop
        // RepeatLoop
        // Condition (if true)
        // FunctionCall arguments
        // Function
        array<Statement@> statements;

        // Condition (if not true)
        array<Statement@> elseStatements;

        // ForLoop
        Statement@ pre;
        Statement@ post;

        // Literals
        int valueInt;
        bool valueBool;
        float valueFloat;
        string valueString;
        uint valueObject;
        vec3 valueVector;
        
        string[] functionArgumentNames;

        Statement(StatementType type) {
            this.type = type;
            @this.value = Statement();
        }

        Statement() {}

        AST::Node@ Transform(VM::ExecutionContext@ context) {
            Log(info, "Transforming " + GetStatementName(type));

            switch(type) {
                case STATEMENT_TYPE_LITERAL:
                    return StatementToLiteral(this, context);
                case STATEMENT_TYPE_VARIABLE:
                    {
                        auto literalType = context.LookupVariable(name)[0].type;
                        Log(info, "Variable type resolved to " + GetTypeName(literalType));
                        return AST::Variable(literalType, name);
                    }
                case STATEMENT_TYPE_BI_FUNCTION:
                case STATEMENT_TYPE_FUNCTION_CALL:
                    return ToFunctionCall(context);
                case STATEMENT_TYPE_DECLARATION:
                    Log(info, "Validation: declare " + name);
                    context.DeclareVariable(name, literalType);
                    //value.ResolveAndValidate(context);
                    return AST::Declaration(name, literalType, value.TransformToExpression(context));
                case STATEMENT_TYPE_ASSIGNMENT:
                    return AST::Assignment(name, value.TransformToExpression(context));
                    /*{
                        value.ResolveAndValidate(context);

                        auto var = context.LookupVariable(name);

                        if (var is null) {
                            TriggerKitException("Incorrect assignment to " + name + ", variable is not declared");
                        } else if (InferExpressionType(value) != var.type) {
                            TriggerKitException("Incorrect assignment to " + name + ", expected " + GetTypeName(var.type) + ", got " + GetTypeName(InferExpressionType(value)));
                        }

                        break;
                    }*/
                    //ResolveAndValidateAll(context.globalState.globalScope.CreateChildScope());
                case STATEMENT_TYPE_FOR_LOOP:
                    {
                        context.Push();
                        auto loop = AST::ForLoop(
                            pre !is null ? pre.Transform(context) : null,
                            value !is null ? value.TransformToExpression(context) : null,
                            post !is null ? post.Transform(context) : null,
                            TransformStatements(context)
                        );
                        context.Pop();

                        return loop;
                    }
                case STATEMENT_TYPE_REPEAT_LOOP:
                    return AST::ForLoop(
                        AST::Declaration("$it", LITERAL_TYPE_INT, AST::Literal(0)),
                        AST::FunctionCall(AST::Variable(LiteralType(LITERAL_TYPE_INT, LITERAL_TYPE_INT, LITERAL_TYPE_BOOL), "<"), array<AST::Expression@> = {
                            AST::Variable(LITERAL_TYPE_INT, "$it"),
                            value.TransformToExpression(context)
                        }),
                        AST::Assignment(
                            "$it",
                            AST::FunctionCall(AST::Variable(LiteralType(LITERAL_TYPE_INT, LITERAL_TYPE_INT, LITERAL_TYPE_INT), "+"), array<AST::Expression@> = {
                                AST::Variable(LITERAL_TYPE_INT, "$it"),
                                AST::Literal(1)
                            })
                        ),
                        TransformStatements(context)
                    );
                case STATEMENT_TYPE_CONDITION:
                    return AST::Condition(
                        value.TransformToExpression(context),
                        TransformStatements(context),
                        TransformStatements(context, elseStatements)
                    );
            }

            return null;
        }

        AST::Literal@ ToFunctionLiteral(VM::ExecutionContext@ context) {
            FunctionArgument@[] args;

            for (uint i = 0; i < literalType.parameters.length(); i++) {
                args.insertLast(FunctionArgument(literalType.parameters[i], functionArgumentNames[i]));
                context.DeclareVariable(functionArgumentNames[i], literalType.parameters[i]);
                Log(info, "Transforming :: " + functionArgumentNames[i]);
            }

            return AST::Literal(FunctionLiteral(
                args,
                literalType.returnType,
                TransformStatements(context)
            ));
        }

        AST::FunctionCall@ ToFunctionCall(VM::ExecutionContext@ context) {
            auto fittingType = FindFittingFunction(context);

            Log(info, "Name " + name + " " + (fittingType is null));

            return AST::FunctionCall(
                AST::Variable(fittingType, name),
                TransformStatementsWhileCasting(context, fittingType)
            );
        }

        LiteralType@ FindFittingFunction(VM::ExecutionContext@ context) {
            LiteralType@[] argumentTypes;

            for (uint i = 0; i < statements.length(); i++) {
                argumentTypes.insertLast(InferExpressionType(context, statements[i]));
            }

            auto candidates = context.LookupVariable(name);
            LiteralType@ fittingType = null;

            if (candidates is null) {
                return null;
            }

            //Log(info, "Candidates found " + candidates.length());

            for (uint i = 0; i < candidates.length(); i++) {
                auto candidateType = candidates[i].type;
                bool fits = argumentTypes.length() == candidateType.parameters.length();

                //Log(info, "Candidate " + GetTypeName(candidateType));

                if (fits) {
                    for (uint j = 0; j < candidateType.parameters.length(); j++) {
                        auto parameterType = candidateType.parameters[j];

                        //Log(info, GetTypeName(parameterType) + " - " + GetTypeName(argumentTypes[j]));

                        if (parameterType != argumentTypes[j]) {
                            auto castName = GetImplicitCastTo(argumentTypes[j], parameterType);

                            if (castName.length() == 0) {
                                fits = false;
                                break;
                            }
                        }
                    }
                }
                
                if (fits) {
                    if (fittingType is null) {
                        @fittingType = candidateType;
                    } else {
                        TriggerKitException("Ambigious function call, already had " + GetTypeName(fittingType) + ", but also found " + GetTypeName(candidateType));
                    }
                }
            }

            if (fittingType is null) {
                //TriggerKitException("Function not found: " + name);
                return null;
            }

            //Log(info, "Resolved function type to " + GetTypeName(fittingType));

            return fittingType;
        }

        AST::Expression@ TransformToExpression(VM::ExecutionContext@ context) {
            AST::Node@ node = Transform(context);
            AST::Expression@ result = cast<AST::Expression@>(node);

            if (result is null) {
                TriggerKitException("Statement is not an expression! " + GetStatementName(type));
            }

            return result;
        }

        AST::Node@[] TransformStatements(VM::ExecutionContext@ context, Statement@[] statements) {
            AST::Node@[] nodes;

            context.Push();

            for (uint i = 0; i < statements.length(); i++) {
                nodes.insertLast(statements[i].Transform(context));
            }

            context.Pop();

            return nodes;
        }

        AST::Node@[] TransformStatements(VM::ExecutionContext@ context) {
            return TransformStatements(context, statements);
        }

        AST::Expression@[] TransformStatementsToExpressions(VM::ExecutionContext@ context) {
            AST::Expression@[] result;

            for (uint i = 0; i < statements.length(); i++) {
                result.insertLast(statements[i].TransformToExpression(context));
            }

            return result;
        }

        AST::Expression@[] TransformStatementsWhileCasting(VM::ExecutionContext@ context, LiteralType@ castTo) {
            AST::Expression@[] result;

            for (uint i = 0; i < statements.length(); i++) {
                auto argumentType = InferExpressionType(context, statements[i]);
                auto expression = statements[i].TransformToExpression(context);

                if (castTo.parameters[i] != argumentType) {
                    auto castName = GetImplicitCastTo(argumentType, castTo.parameters[i]);
                    LiteralType@[] params = { argumentType };
                    LiteralType castType(params, castTo.parameters[i]);

                    @expression = AST::FunctionCall(
                        AST::Variable(castType, castName),
                        array<AST::Expression@> = { expression }
                    );
                }

                result.insertLast(expression);
            }

            return result;
        }
    }

    Statement@ DeclarationST(LiteralType@ type, string name, Statement@ value) {
        Statement statement(STATEMENT_TYPE_DECLARATION);
        statement.name = name;
        @statement.literalType = type;
        @statement.value = value;

        return statement;
    }

    Statement@ FunctionLiteralST() {
        Statement statement(STATEMENT_TYPE_LITERAL);
        @statement.literalType = LiteralType(LITERAL_TYPE_VOID);

        return statement;
    }

    Statement@ IntLiteral(int value) {
        Statement statement(STATEMENT_TYPE_LITERAL);
        @statement.literalType = LITERAL_TYPE_INT;
        statement.valueInt = value;

        return statement;
    }
}