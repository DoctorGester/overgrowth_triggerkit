#include "triggerkit/common.as"
#include "triggerkit/default_types.as"
#include "triggerkit/vm.as"
#include "triggerkit/ast.as"
#include "triggerkit/parse_tree.as"
#include "triggerkit/persistence.as"
#include "triggerkit/styles.as"
#include "triggerkit/dictionary.as"


VM::GlobalScriptState@ script;
TriggerKitState@ state;
UIStyle@ style = UIStyle();

// TODO
// Extensive type checking
// Check that all paths return a value (compute function code into a list of lists, using permutations for branches)
// break and continue
// generic types:
// Add a TypeToken into literal type
// When first encountered in a function call token type is resolved to the actual literal/variable type
// ... and then stored in the context type hints
// All next encounters replace the type token with the actual type in Infer
// array types
// vector types
// thread sleep!
// operators in UI
// assignment in UI
// for loop in UI
// Error messages, a separate validation context?
// Global variables in UI
// Nicer function format in UI

class TypedVariable {
    LiteralType@ type;
    string name;

    TypedVariable(LiteralType@ type, string name) {
        @this.type = type;
        this.name = name;
    }
}

class Trigger {
    string name;
    string description;
    ParseTree::Statement@ triggerFunction;

    Trigger(string name) {
        this.name = name;
        @triggerFunction = ParseTree::Statement(STATEMENT_TYPE_FUNCTION_CALL);
    }
}

class FunctionDescription {
    LiteralType@ type;
    string prettyName;
    string format;
    string name;
    bool isDefaultEvent;
    bool isOperator;

    FunctionDescription(LiteralType@ type, string name, string prettyName, string format, bool isDefaultEvent, bool isOperator) {
        @this.type = type;
        this.name = name;
        this.prettyName = prettyName;
        this.format = format;
        this.isDefaultEvent = isDefaultEvent;
        this.isOperator = isOperator;
    }

    int opCmp(FunctionDescription@ description) {
        return prettyName.opCmp(description.name);
    }
}

funcdef bool FunctionPredicate(FunctionDescription@ f);

class TriggerKitState {
    ParseTree::Statement@[] editedStatements = {};
    int currentStackLevel = 0;
    int selectedActionCategory = 0;
    int selectedTrigger;
    bool showJSON = false;

    dictionary functionDescriptions;

    Trigger@[] triggers;

    void Push(ParseTree::Statement@ statement) {
        editedStatements.insertLast(statement);
    }


    void Pop() {
        editedStatements.removeLast();
    }

    void Persist() {
        Persistence::Save(triggers);
    }

    FunctionDescription@[] FindEventHandlers() {
        return FindFunctions(function(f) {
            return f.isDefaultEvent;
        });
    }

    FunctionDescription@[] FindFunctions(FunctionPredicate@ predicate) {
        auto keys = functionDescriptions.getKeys();
        FunctionDescription@[] result;

        for (uint i = 0; i < keys.length(); i++) {
            auto key = keys[i];
            auto values = cast<FunctionDescription@[]>(functionDescriptions[key]);

            for (uint j = 0; j < values.length(); j++) {
                if (predicate(values[j])) {
                    result.insertLast(values[j]);
                }
            }
        }

        return result;
    }

    FunctionDescription@ FindFunctionDescription(string name, LiteralType@ type) {
        if (functionDescriptions.exists(name)) {
            auto descriptions = cast<FunctionDescription@[]>(functionDescriptions[name]);

            for (uint i = 0; i < descriptions.length(); i++) {
                if (descriptions[i].type == type) {
                    return descriptions[i];
                }
            }
        }

        return null;
    }

    void AddDescription(string name, string pretty, string format, LiteralType@ type, bool isDefaultEvent, bool isOperator) {
        FunctionDescription@[] descriptions;

        if (functionDescriptions.exists(name)) {
            descriptions = cast<FunctionDescription@[]>(functionDescriptions[name]);
        }

        descriptions.insertLast(FunctionDescription(type, name, pretty, format, isDefaultEvent, isOperator));
        functionDescriptions[name] = descriptions;
    }

    ParseTree::Statement@ Peek() {
        return editedStatements[currentStackLevel - 1];
    }

    Trigger@ Selected() {
        if (uint(selectedTrigger) >= triggers.length()) {
            return null;
        }

        return triggers[uint(selectedTrigger)];
    }

    AST::Node@ TransformParseTree() {
        auto selected = Selected();

        if (selected is null) {
            return null;
        }

        return selected.triggerFunction.Transform(script.CreateContext());
    }
}

namespace API {
    void Operator(
        VM::FunctionExecutor@ executor,
        string symbol,
        LiteralType@ returnType,
        LiteralType@ type,
        string format = "",
        string pretty = ""
    ) {
        if (format.length() == 0) {
            format = "%s " + symbol + " %s";
        }

        Native(
            name: symbol,
            format: format,
            pretty: pretty,
            returnType: returnType,
            arg1: FunctionArgument(type, "left"),
            arg2: FunctionArgument(type, "right"),
            executor: executor,
            isOperator: true
        );
    }

    void Native(
        VM::FunctionExecutor@ executor,
        string name,
        LiteralType@ returnType,
        string format = "",
        string pretty = "",
        bool isOperator = false,
        bool isDefaultEvent = false,
        FunctionArgument@ arg1 = null,
        FunctionArgument@ arg2 = null,
        FunctionArgument@ arg3 = null,
        FunctionArgument@ arg4 = null
    ) {
        if (format.length() == 0) format = name;
        if (pretty.length() == 0) pretty = name;

        array<FunctionArgument@> all = { arg1, arg2, arg3, arg4 };

        for (uint i = 0; i < all.length(); i++) {
            if (all[i] is null) {
                all.removeAt(i);
                i--;
            }
        }

        auto type = script.RegisterNativeFunction(executor, name, returnType, all);
        state.AddDescription(name, pretty, format, type, isDefaultEvent, isOperator);
    }

    void Converter(string type, VM::MessageConverter@ converter) {
        script.RegisterMessageConverter(type, converter);
    }
}

void Init(string p_level_name) {
    Log(info, "CALLING INIT " + p_level_name);
    @state = TriggerKitState();
    state.triggers = Persistence::Load();

    @script = VM::GlobalScriptState();

    #include "triggerkit/default_functions.as"

    for (uint i = 0; i < state.triggers.length(); i++) {
        script.Execute(state.triggers[i].triggerFunction.TransformToExpression(script.CreateContext()));
    }
}

void ReceiveMessage(string msg) {
    // Spam
    if (msg == "tutorial " || script is null) {
        return;
    }

    script.ReceiveMessage(msg);
}

void DrawGUI() {
    /*if (triggerFunction is null) {
        @triggerFunction = Persistence::Load();
        state.TransformParseTree();
    }*/

    if (EditorModeActive()) {
        DrawTriggerKit();
    }
}

void DrawActionPopup(ParseTree::Statement@ statement, VM::ExecutionContext@ context, LiteralType@ limitTo, int &statementIndex) {
    StatementType[] statementTypes = {
        STATEMENT_TYPE_FUNCTION_CALL,
        STATEMENT_TYPE_CONDITION,
        STATEMENT_TYPE_REPEAT_LOOP,
        STATEMENT_TYPE_ASSIGNMENT,
        STATEMENT_TYPE_DECLARATION
    };

    if (limitTo !is null) {
        statementTypes = array<StatementType> = {
            STATEMENT_TYPE_VARIABLE,
            STATEMENT_TYPE_LITERAL,
            STATEMENT_TYPE_BI_FUNCTION,
            STATEMENT_TYPE_FUNCTION_CALL
        };
    }

    string[] actions;
    int selected = -1;

    for (uint i = 0; i < statementTypes.length(); i++) {
        actions.insertLast(GetStatementName(statementTypes[i]));

        if (statementTypes[i] == statement.type) {
            selected = i;
        }
    }

    if (ImGui_Combo("###ActionList", selected, actions)) {
        Log(info, "List selection changed to " + selected);
        statement.type = statementTypes[selected];
    }

    if (statement !is null) {
        DrawStatement(statement, context, limitTo, ++statementIndex, true);
    }

    if (ImGui_Button("Ok")) {
        if (state.editedStatements.length() > 0) {
            state.Pop();
            state.TransformParseTree();
        }

        if (state.editedStatements.length() == 0) {
            state.Persist();
        }

        ImGui_CloseCurrentPopup();
    }
}

void ExtractDeclarations(ParseTree::Statement@ statement, VM::ExecutionContext@ context, int &statementIndex) {
    if (statement is null) {
        return;
    }

    switch (statement.type) {
        case STATEMENT_TYPE_DECLARATION:
            context.DeclareVariable(statement.name, statement.literalType);
            break;
        case STATEMENT_TYPE_FOR_LOOP:
            ExtractDeclarations(statement.pre, context, statementIndex);
            ExtractDeclarations(statement.value, context, statementIndex);
            break;
    }
}

void DrawStatements(ParseTree::Statement@ parent, array<ParseTree::Statement@>@ statements, VM::ExecutionContext@ context, int &statementIndex) {
    context.Push();

    bool topLevel = parent is null;
    bool inTree = false;

    if (!topLevel) {
        inTree = ImGui_TreeNodeEx(statements.length() + " actions###StatementBlock" + statementIndex, ImGuiTreeNodeFlags_OpenOnDoubleClick | ImGuiTreeNodeFlags_DefaultOpen);
    }

    if (topLevel || inTree) {
        if (parent !is null && parent.literalType !is null && parent.literalType.basic == BASIC_TYPE_FUNCTION) {
            for (uint i = 0; i < parent.literalType.parameters.length(); i++) {
                auto type = parent.literalType.parameters[i];
                auto name = parent.functionArgumentNames[i];

                ImGui_AlignFirstTextHeightToWidgets();
                ImGui_Text(type.ToString());
                ImGui_SameLine();
                ImGui_PushItemWidth(100);

                ImGui_SetTextBuf(name);
                if (ImGui_InputText("###ArgumentName" + (statementIndex++))) {
                    parent.functionArgumentNames[i] = ImGui_GetTextBuf();
                }

                context.DeclareVariable(name, type);

                ImGui_PopItemWidth();
            }
        }

        auto cursorY = ImGui_GetMousePos().y - ImGui_GetWindowPos().y;
        auto startY = ImGui_GetCursorPosY();
        auto endY = -1.0;
        auto dragging = ImGui_IsMouseDragging();

        for (uint i = 0; i < statements.length(); i++) {
            auto statement = statements[i];

            auto currentStartY = ImGui_GetCursorPosY();
            auto diffY = cursorY - currentStartY;

            if (dragging && (diffY < 0 && diffY > - 20) && i == 0) {
                Log(info, (cursorY - currentStartY) + "");
                ImGui_Separator();
            }

            if (inTree) {
                if (ImGui_Button("X###StatementRemove" + i)) {
                    Log(info, "Remove");
                    statements.removeAt(i);
                    i--;
                }

                ImGui_SameLine();
            }

            startY = ImGui_GetCursorPosY();
            ImGui_BeginGroup();
            DrawStatement(statement, context, null, ++statementIndex);

            ExtractDeclarations(statement, context, statementIndex);

            switch (statement.type) {
                case STATEMENT_TYPE_LITERAL:
                    if (statement.literalType.basic != BASIC_TYPE_FUNCTION)
                        break;
                case STATEMENT_TYPE_FOR_LOOP:
                case STATEMENT_TYPE_REPEAT_LOOP:
                case STATEMENT_TYPE_CONDITION:
                    DrawStatements(statement, statement.statements, context, ++statementIndex);
                    break;
                case STATEMENT_TYPE_FUNCTION_CALL:
                    for (uint j = 0; j < statement.statements.length(); j++) {
                        if (statement.statements[j].literalType is null) {
                            continue;
                        }

                        if (statement.statements[j].literalType.basic == BASIC_TYPE_FUNCTION) {
                            DrawStatements(statement.statements[j], statement.statements[j].statements, context, ++statementIndex);
                        }
                    }

                    break;
            }

            ImGui_EndGroup();
            endY = ImGui_GetCursorPosY();

            auto blockHeight = endY - startY;
            auto relY = cursorY - startY;

            if (ImGui_IsMouseDragging() && relY > 0 && relY < blockHeight && abs(relY) < 20) {
                ImGui_Separator();
            }
        }

        if (!topLevel) {
            if (ImGui_Button("+###StatementAdd" + statementIndex)) {
                auto newOne = ParseTree::Statement(STATEMENT_TYPE_FUNCTION_CALL);
                statements.insertLast(newOne);
                state.Push(newOne);

                ImGui_OpenPopup("Add");
            }

            ImGui_SetNextWindowPos(ImGui_GetWindowPos() + vec2(20, 20), ImGuiSetCond_Appearing);
            if (ImGui_BeginPopupModal("Add", ImGuiWindowFlags_AlwaysAutoResize)) {
                state.currentStackLevel++;
                DrawActionPopup(state.Peek(), context, null, ++statementIndex);

                ImGui_EndPopup();
            }
        }

        if (inTree) {
            ImGui_TreePop();
        }
    }

    context.Pop();
}

string StatementToString(ParseTree::Statement@ statement, VM::ExecutionContext@ context) {
    if (statement is null) {
        return "<no value>";
    }

    switch (statement.type) {
        case STATEMENT_TYPE_NONE:
            return "Nothing";
        case STATEMENT_TYPE_DECLARATION:
            return join(array<string> = {
                GetTypeName(statement.literalType),
                statement.name,
                "=",
                StatementToString(statement.value, context)
            }, " ");
        case STATEMENT_TYPE_ASSIGNMENT:
            return join(array<string> = {
                "set",
                statement.name,
                "=",
                StatementToString(statement.value, context)
            }, " ");
        case STATEMENT_TYPE_VARIABLE:
            return statement.name;
        case STATEMENT_TYPE_LITERAL:
            if (statement.literalType is null) {
                return "<unknown>";
            }

            return TypeToUIString(statement);
        case STATEMENT_TYPE_BI_FUNCTION:
        case STATEMENT_TYPE_FUNCTION_CALL:
            {
                auto type = statement.FindFittingFunction(context);
                auto sts = statement.statements;
                array<string> args;

                auto description = state.FindFunctionDescription(statement.name, type);

                if (description !is null) {
                    auto format = description.format;

                    int index = 0;
                    int currentArgument = 0;
                    string result = "";

                    while (true) {
                        int newIndex = format.findFirst("%s", index);

                        if (newIndex != -1) {
                            auto arg = "(" + StatementToString(sts[currentArgument], context) + ")";
                            result += format.substr(index, newIndex - index) + arg;
                            currentArgument++;
                        } else {
                            if (index == 0) {
                                result = format;
                            } else {
                                result += format.substr(index);
                            }

                            break;
                        }

                        index = newIndex + 2;
                    }

                    return result;
                } else {
                    for (uint i = 0; i < sts.length(); i++) {
                        args.insertLast(StatementToString(sts[i], context));
                    }
                }

                return statement.name + "(" + join(args, ", ") + ")";
            }
        case STATEMENT_TYPE_REPEAT_LOOP:
            return join(array<string> = {
                "Repeat",
                StatementToString(statement.value, context),
                "times"
            }, " ");
        case STATEMENT_TYPE_CONDITION:
            return "If " + StatementToString(statement.value, context) + " do";
    }

    return "";
}

void EditableStatement(ParseTree::Statement@ statement, VM::ExecutionContext@ context, LiteralType@ limitTo, int &index) {
    if (ImGui_Button(StatementToString(statement, context) + "###EditableStatement" + (index++))) {
        state.Push(statement);
        Log(info, "Open editor popup at stack level " + state.currentStackLevel);
        ImGui_OpenPopup("Action###EditWindow" + index);
    }

    ImGui_SetNextWindowPos(ImGui_GetWindowPos() + vec2(20, 20), ImGuiSetCond_Appearing);
    if (ImGui_BeginPopupModal("Action###EditWindow" + index, ImGuiWindowFlags_AlwaysAutoResize)) {
        state.currentStackLevel++;
        DrawActionPopup(state.Peek(), context, limitTo, ++index);

        ImGui_EndPopup();
    }
}

void FillDefaultFunctionArguments(ParseTree::Statement@ statement, VM::ExecutionContext@ context,  LiteralType@ type) {
    ParseTree::Statement@[] newArguments;

    for (uint i = 0; i < type.parameters.length(); i++) {
        if (statement.statements.length() > i) {
            auto inferred = ParseTree::InferExpressionType(context, statement.statements[i]);

            if (inferred == type.parameters[i]) {
                newArguments.insertLast(statement.statements[i]);
                continue;
            }
        }

        auto argument = ParseTree::Statement(STATEMENT_TYPE_LITERAL);
        @argument.literalType = type.parameters[i];
        newArguments.insertLast(argument);

        if (argument.literalType.basic == BASIC_TYPE_FUNCTION) {
            argument.functionArgumentNames.resize(0);

            for (uint j = 0; j < argument.literalType.parameters.length(); j++) {
                argument.functionArgumentNames.insertLast("arg" + (j + 1));
            }
        }
    }

    statement.statements.resize(0);

    for (uint i = 0; i < newArguments.length(); i++) {
        statement.statements.insertLast(newArguments[i]);
    }
}

void DrawFunctionCall(ParseTree::Statement@ statement, VM::ExecutionContext@ context, LiteralType@ limitTo, FunctionPredicate@ predicate, int &stIndex) {
    //VM::ScopeVariable@[] functions = context.LookupAllByReturnType(limitTo);
    auto functions = state.FindFunctions(predicate);

    if (limitTo !is null) {
        for (uint i = 0; i < functions.length(); i++) {
            if (functions[i].type.returnType != limitTo) {
                functions.removeAt(i);
                i--;
            }
        }
    }

    functions.sortAsc();

    string[] filteredFunctions;

    for (uint i = 0; i < functions.length(); i++) {
        filteredFunctions.insertLast(functions[i].prettyName);
    }

    string[] functionNames;
    int selected = -1;

    for (uint i = 0; i < filteredFunctions.length(); i++) {
        if (functions[i].name == statement.name && functions[i].type == statement.FindFittingFunction(context)) {
            selected = i;
        }
    }

    ImGui_PushItemWidth(300);

    if (ImGui_Combo("###FunctionSelection" + stIndex, selected, filteredFunctions)) {
        auto type = functions[selected].type;
        statement.name = functions[selected].name;
        FillDefaultFunctionArguments(statement, context, type);
    }

    ImGui_PopItemWidth();

    auto description = selected != -1 ? functions[selected] : null;

    if (description !is null) {
        auto format = description.format;
        auto type = description.type;

        int index = 0;
        int currentArgument = 0;

        ImGui_AlignFirstTextHeightToWidgets();

        while (true) {
            int newIndex = format.findFirst("%s", index);

            if (newIndex != -1) {
                auto preText = StringTrim(format.substr(index, newIndex - index));

                if (preText.length() > 0) {
                    if (currentArgument > 0) {
                        ImGui_SameLine();
                    }
                    
                    ImGui_Text(preText);
                }
                
                if (preText.length() > 0 || currentArgument > 0) {
                    ImGui_SameLine();
                }
                
                DrawStatement(statement.statements[currentArgument], context, type.parameters[currentArgument], ++stIndex);
                currentArgument++;
            } else {
                if (index == 0) {
                    auto txt = StringTrim(format);

                    if (txt.length() > 0) {
                        ImGui_Text(txt);
                    }
                } else {
                    auto txt = StringTrim(format.substr(index));

                    if (txt.length() > 0) {
                        if (currentArgument > 0) {
                            ImGui_SameLine();
                        }

                        ImGui_Text(txt);
                    }
                }

                break;
            }

            index = newIndex + 2;
        }
    }

    /*auto type = selected != -1 ? functions[selected].type : null;

    for (uint i = 0; i < statement.statements.length(); i++) {
        DrawStatement(statement.statements[i], context, type !is null ? type.parameters[i] : statement.statements[i].literalType, ++index);
    }*/
}

void DrawTypeSelectionCombo(ParseTree::Statement@ statement, string label, LiteralType@ limitTo) {
    LiteralType@[] allTypes = {
        LITERAL_TYPE_INT,
        LITERAL_TYPE_FLOAT,
        LITERAL_TYPE_BOOL,
        LITERAL_TYPE_STRING,
        LITERAL_TYPE_OBJECT,
        LITERAL_TYPE_ITEM,
        LITERAL_TYPE_CHARACTER,
        LITERAL_TYPE_HOTSPOT,
        LITERAL_TYPE_VECTOR
    };

    if (limitTo !is null) {
        allTypes.resize(0);
        allTypes.insertLast(limitTo);
    }

    string[] variableTypes;
    int selected = -1;

    for (uint i = 0; i < allTypes.length(); i++) {
        if (allTypes[i] == statement.literalType) {
            selected = i;
        }

        variableTypes.insertLast(GetTypeName(allTypes[i]));
    }

    if (ImGui_Combo(label, selected, variableTypes)) {
        @statement.literalType = allTypes[selected];
    }
}

void DrawDeclaration(ParseTree::Statement@ statement, VM::ExecutionContext@ context, int &index) {
    DrawTypeSelectionCombo(statement, "###DeclarationTypes" + index, null);

    ImGui_SameLine();

    ImGui_SetTextBuf(statement.name);
    ImGui_PushItemWidth(100);

    if (ImGui_InputText("###DeclarationInput" + index)) {
        statement.name = ImGui_GetTextBuf();
    }

    ImGui_PopItemWidth();

    ImGui_SameLine();
    ImGui_Text("=");
    ImGui_SameLine();
    EditableStatement(statement.value, context, statement.literalType, index);
}

void DrawLiteral(ParseTree::Statement@ statement, LiteralType@ limitTo, int &index) {
    ImGui_PushItemWidth(200);

    DrawTypeSelectionCombo(statement, "###LiteralType" + index, limitTo);
    DrawBasicType(statement, index);

    ImGui_PopItemWidth();
}

void DrawVariable(ParseTree::Statement@ statement,  VM::ExecutionContext@ context, LiteralType@ limitTo, int &index) {
    VM::ScopeVariable@[] vars = context.LookupAllByType(limitTo);

    string[] names;
    int selected = -1;

    for (uint i = 0; i < vars.length(); i++) {
        names.insertLast(vars[i].name);

        if (names[i] == statement.name) {
            selected = i;
        }
    }

    if (ImGui_Combo("###VariableCombo" + index, selected, names)) {
        statement.name = names[selected];
    }
}

void DrawCondition(ParseTree::Statement@ statement, VM::ExecutionContext@ context, int &index) {
    ImGui_AlignFirstTextHeightToWidgets();
    ImGui_Text("If");
    ImGui_SameLine();
    EditableStatement(statement.value, context, LITERAL_TYPE_BOOL, index);
}

void DrawStatement(ParseTree::Statement@ statement, VM::ExecutionContext@ context, LiteralType@ limitTo, int &index, bool inPopup = false) {
    if (!inPopup) {
        EditableStatement(statement, context, limitTo, ++index);
        return;
    }

    switch (statement.type) {
        case STATEMENT_TYPE_DECLARATION:
            DrawDeclaration(statement, context, index);
            break;
        case STATEMENT_TYPE_ASSIGNMENT:
            ImGui_Button("set");
            ImGui_SameLine();
            ImGui_Button(statement.name);
            ImGui_SameLine();
            ImGui_Text("=");
            ImGui_SameLine();

            DrawStatement(statement.value, context, limitTo, ++index);
            break;
        case STATEMENT_TYPE_VARIABLE:
            DrawVariable(statement, context, limitTo, ++index);
            break;
        case STATEMENT_TYPE_LITERAL:
            DrawLiteral(statement, limitTo, index);
            break;
        case STATEMENT_TYPE_REPEAT_LOOP:
            ImGui_Text("Repeat");
            ImGui_SameLine();
            DrawStatement(statement.value, context, LITERAL_TYPE_INT, ++index);
            ImGui_SameLine();
            ImGui_Text("times");
            break;
        case STATEMENT_TYPE_BI_FUNCTION:
            DrawFunctionCall(statement, context, limitTo, function(f) {
                return f.isOperator;
            }, ++index);
            break;
        case STATEMENT_TYPE_FUNCTION_CALL:
            DrawFunctionCall(statement, context, limitTo, function(f) {
                return !f.isDefaultEvent && !f.isOperator;
            }, ++index);
            break;
        case STATEMENT_TYPE_CONDITION:
            DrawCondition(statement, context, ++index);
            break;
    }
}

Trigger@ DrawTriggerList(float windowHeight) {
    string[] triggerNames;

    for (uint i = 0; i < state.triggers.length(); i++) {
        triggerNames.insertLast(state.triggers[i].name);
    }

    ImGui_BeginGroup();
    ImGui_PushItemWidth(200);
    ImGui_AlignFirstTextHeightToWidgets();
    ImGui_Text("Triggers");
    const int itemSize = 17;
    float windowRemaining = windowHeight - ImGui_GetCursorPosY() - itemSize * 4;

    ImGui_ListBox("###TriggerList", state.selectedTrigger, triggerNames, int(floor(windowRemaining / itemSize)));
    ImGui_PopItemWidth();

    if (ImGui_Button("Add")) {
        string triggerName;
        uint triggerId = 0;

        while (true) {
            bool found = false;
            triggerName = "Trigger " + (triggerId + 1);

            for (uint i = 0; i < state.triggers.length(); i++) {
                if (state.triggers[i].name == triggerName) {
                    triggerId++;
                    found = true;
                    break;
                }
            }

            if (!found) {
                break;
            }
        }

        Trigger trigger(triggerName);
        state.selectedTrigger = state.triggers.length();
        state.triggers.insertLast(trigger);

        state.Persist();
    }

    ImGui_SameLine();

    if (ImGui_Button("Rem##FFFF00FFove")) {
        state.triggers.removeAt(uint(state.selectedTrigger));
        state.selectedTrigger = max(state.selectedTrigger - 1, 0);

        state.Persist();
    }

    ImGui_SameLine();

    if (ImGui_Button("Load")) {
        state.triggers = Persistence::Load();
        state.TransformParseTree();
    }

    ImGui_SameLine();

    if (ImGui_Button("VM Reload")) {
        Init("");
    }

    ImGui_EndGroup();

    if (state.triggers.length() <= uint(state.selectedTrigger)) {
        return null;
    }

    return state.triggers[uint(state.selectedTrigger)];
}

void DrawMenuBar() {
    if (ImGui_BeginMenu("Tools")) {
        ImGui_Checkbox("Show JSON", state.showJSON);

        ImGui_EndMenu();
    }

    if (ImGui_BeginMenu("Style")) {
        ImGui_DragInt("Hue", style.hue, v_max: 255);
        ImGui_DragFloat("Main Sat", style.mainSat, v_max: 255.0f);
        ImGui_DragFloat("Main Val", style.mainVal, v_max: 255.0f);
        ImGui_DragFloat("Area Sat", style.areaSat, v_max: 255.0f);
        ImGui_DragFloat("Area Val", style.areaVal, v_max: 255.0f);
        ImGui_DragFloat("Back Sat", style.backSat, v_max: 255.0f);
        ImGui_DragFloat("Back Val", style.backVal, v_max: 255.0f);
        float mainSat = 180.0f;
        float mainVal = 161.0f;
        float areaSat = 124.0f;
        float areaVal = 100.0f;
        float backSat = 49.0f;
        float backVal = 50.0f;

        ImGui_EndMenu();
    }
}

void DrawTriggerKit() {
    //PushStyles();

    ImGui_Begin("TriggerKit", ImGuiWindowFlags_MenuBar);

    float windowWidth = ImGui_GetWindowWidth();
    float windowHeight = ImGui_GetWindowHeight();

    if (windowWidth < 500) {
        windowWidth = 500;
        ImGui_SetWindowSize(vec2(windowWidth, windowHeight), ImGuiSetCond_Always);
    }

    if (windowHeight < 300) {
        windowHeight = 300;
        ImGui_SetWindowSize(vec2(windowWidth, windowHeight), ImGuiSetCond_Always);
    }

    if (ImGui_BeginMenuBar()) {
        DrawMenuBar();
        ImGui_EndMenuBar();
    }

    Trigger@ currentTrigger = DrawTriggerList(windowHeight);
    ImGui_SameLine();

    if (currentTrigger !is null) {
        DrawTriggerContent(currentTrigger);
    }

    ImGui_End();

    if (state.showJSON and state.Selected() !is null) {
        ImGui_Begin("JSON output", ImGuiWindowFlags_HorizontalScrollbar);
        JSON json;
        json.getRoot()["trigger"] = Persistence::ToJSON(state.Selected().triggerFunction);
        ImGui_SetTextBuf(json.writeString(true));
        ImGui_InputTextMultiline("###input", ImGuiInputTextFlags_ReadOnly);
        ImGui_End();
    }

    //PopStyles();
}

/*void DrawEventSelector(ParseTree::Statement@ statement, VM::ExecutionContext@ context) {
    auto eventFunctions = state.FindFunctions(function(f) { return f.isDefaultEvent; });
    string[] events;

    for (uint i = 0; i < eventFunctions.length(); i++) {
        events.insertLast(eventFunctions[i].prettyName);
    }

    int selected = -1;

    for (uint i = 0; i < events.length(); i++) {
        if (eventFunctions[i].name == statement.name) {
            selected = i;
            break;
        }
    }

    ImGui_AlignFirstTextHeightToWidgets();
    ImGui_Text("Event");

    if (ImGui_Combo("###EventSelector", selected, events)) {
        auto description = eventFunctions[selected];
        statement.name = description.name;
        FillDefaultFunctionArguments(statement, description.type);
    }
}
*/
void DrawTriggerContent(Trigger@ currentTrigger) {
    ImGui_BeginGroup();

    ImGui_AlignFirstTextHeightToWidgets();
    ImGui_Text("Content");

    ImGui_SetTextBuf(currentTrigger.name);
    if (ImGui_InputText("###TriggerName")) {
        currentTrigger.name = ImGui_GetTextBuf();
    }

    ImGui_SetTextBuf(currentTrigger.description);
    if (ImGui_InputTextMultiline("###TriggerDescription", vec2(0, 50))) {
        currentTrigger.description = ImGui_GetTextBuf();
    }

    int index = 0;
    state.currentStackLevel = 0;

    auto ctx = script.CreateContext();

    ImGui_AlignFirstTextHeightToWidgets();
    ImGui_Text("Event");
    //DrawEventSelector(currentTrigger.triggerFunction, ctx);

    auto call = currentTrigger.triggerFunction;

    DrawFunctionCall(call, ctx, null, function(f) {
        return f.isDefaultEvent;
    }, index);

    for (uint j = 0; j < call.statements.length(); j++) {
        if (call.statements[j].literalType is null) {
            continue;
        }

        if (call.statements[j].literalType.basic == BASIC_TYPE_FUNCTION) {
            DrawStatements(call.statements[j], call.statements[j].statements, ctx, ++index);
        }
    }
    //DrawStatements(null, array<ParseTree::Statement@> = { currentTrigger.triggerFunction }, script.CreateContext(), index);

    /*if (ImGui_Button("Eval")) {
        script.Execute(
            AST::FunctionCall(
                currentTrigger.triggerFunction.TransformToExpression(ctx),
                array<AST::Expression@>()
            )
        );
    }*/

    ImGui_EndGroup();
}

void Update(int paused) {  
}

void SetWindowDimensions(int w, int h)
{
}
