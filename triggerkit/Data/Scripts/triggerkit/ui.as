funcdef bool Function_Predicate(Function_Description@ f);

class Trigger {
    string name;
    string description;
    Expression@ event_definition;
    array<Expression@> content;

    Trigger(string name) {
        this.name = name;
    }
}

class Function_Description {
    Literal_Type type;
    string prettyName;
    string format;
    string name;
    bool isDefaultEvent;
    bool isOperator;

    Function_Description(){}

    Function_Description(Literal_Type type, string name, string prettyName, string format, bool isDefaultEvent, bool isOperator) {
        this.type = type;
        this.name = name;
        this.prettyName = prettyName;
        this.format = format;
        this.isDefaultEvent = isDefaultEvent;
        this.isOperator = isOperator;
    }

    int opCmp(Function_Description@ description) {
        return prettyName.opCmp(description.name);
    }
}

class Trigger_Kit_State {
    array<Expression@> edited_expressions;
    array<Function_Description> native_functions;

    int current_stack_depth = 0;
    int selected_action_category = 0;
    int selected_trigger;

    array<Trigger@> triggers;


    void Persist() {
        // Persistence::Save(triggers);
    }

    Function_Description@[] filter_native_event_handlers() {
        return filter_native_functions_by_predicate(function(f) {
            return f.isDefaultEvent;
        });
    }

    array<Function_Description@> filter_native_functions_by_predicate(Function_Predicate@ predicate) {
        array<Function_Description@> filter_result;

        for (uint index = 0; index < native_functions.length(); index++) {
            Function_Description@ function_description = native_functions[index];

            if (predicate(function_description)) {
                filter_result.insertLast(function_description);
            }
        }

        return filter_result;
    }

    void add_native_function_to_library(Function_Description description) {
        native_functions.insertLast(description);
    }

    Trigger@ get_current_selected_trigger() {
        if (uint(selected_trigger) >= triggers.length()) {
            return null;
        }

        return triggers[uint(selected_trigger)];
    }
}

string find_vacant_trigger_name() {
    string trigger_name;
    uint trigger_id = 0;

    while (true) {
        bool found = false;
        trigger_name = "Trigger " + (trigger_id + 1);

        for (uint i = 0; i < state.triggers.length(); i++) {
            if (state.triggers[i].name == trigger_name) {
                trigger_id++;
                found = true;
                break;
            }
        }

        if (!found) {
            break;
        }
    }

    return trigger_name;
}

Trigger@ draw_trigger_list(float window_height) {
    string[] triggerNames;

    for (uint i = 0; i < state.triggers.length(); i++) {
        triggerNames.insertLast(state.triggers[i].name);
    }

    ImGui_BeginGroup();
    ImGui_PushItemWidth(200);
    ImGui_AlignFirstTextHeightToWidgets();
    ImGui_Text("Triggers");
    const int itemSize = 17;
    float windowRemaining = window_height - ImGui_GetCursorPosY() - itemSize * 4;

    ImGui_ListBox("###TriggerList", state.selected_trigger, triggerNames, int(floor(windowRemaining / itemSize)));
    ImGui_PopItemWidth();

    if (ImGui_Button("Add")) {
        string trigger_name = find_vacant_trigger_name();

        Trigger trigger(trigger_name);
        state.selected_trigger = state.triggers.length();
        state.triggers.insertLast(trigger);

        state.Persist();
    }

    ImGui_SameLine();

    if (ImGui_Button("Rem##FFFF00FFove")) {
        state.triggers.removeAt(uint(state.selected_trigger));
        state.selected_trigger = max(state.selected_trigger - 1, 0);

        state.Persist();
    }

    ImGui_SameLine();

    if (ImGui_Button("Load")) {
        // state.triggers = Persistence::Load();
        // state.TransformParseTree();
    }

    ImGui_SameLine();

    if (ImGui_Button("VM Reload")) {
        Init("");
    }

    ImGui_EndGroup();

    if (state.triggers.length() <= uint(state.selected_trigger)) {
        return null;
    }

    return state.triggers[uint(state.selected_trigger)];
}

void draw_trigger_kit() {
    if (state is null) {
        return;
    }

    //PushStyles();

    ImGui_Begin("TriggerKit", ImGuiWindowFlags_MenuBar);

    float windowWidth = ImGui_GetWindowWidth();
    float window_height = ImGui_GetWindowHeight();

    if (windowWidth < 500) {
        windowWidth = 500;
        ImGui_SetWindowSize(vec2(windowWidth, window_height), ImGuiSetCond_Always);
    }

    if (window_height < 300) {
        window_height = 300;
        ImGui_SetWindowSize(vec2(windowWidth, window_height), ImGuiSetCond_Always);
    }

    if (ImGui_BeginMenuBar()) {
        // DrawMenuBar();
        ImGui_EndMenuBar();
    }

    Trigger@ currentTrigger = draw_trigger_list(window_height);
    ImGui_SameLine();

    if (currentTrigger !is null) {
        draw_trigger_content(currentTrigger);
    }
    
    ImGui_End();
    //PopStyles();
}

void pre_expression_text(string text) {
    ImGui_AlignFirstTextHeightToWidgets();
    ImGui_Text(text);
    ImGui_SameLine();
}

void post_expression_text(string text) {
    ImGui_SameLine();
    ImGui_Text(text);
}

void draw_expressions_in_a_tree_node(string title, array<Expression@>@ expressions, uint& expression_index, uint& popup_stack_level) {
    expression_index++;
    if (ImGui_TreeNodeEx(title + "###expression_block_" + expression_index, ImGuiTreeNodeFlags_OpenOnDoubleClick | ImGuiTreeNodeFlags_DefaultOpen)) {
        draw_expressions_(expressions, expression_index, popup_stack_level);
        ImGui_TreePop();
    }
}

void draw_expression_and_continue_on_the_same_line(Expression@ expression, uint& expression_index, uint& popup_stack_level) {
    draw_editable_expression(expression, expression_index, popup_stack_level);
    ImGui_SameLine();
}

bool draw_button_and_continue_on_the_same_line(string text) {
    bool result = ImGui_Button(text);
    ImGui_SameLine();

    return result;
}

string operator_type_to_ui_string(Operator_Type operator_type) {
    switch (operator_type) {
        case OPERATOR_AND: return "and";
        case OPERATOR_OR: return "or";
        case OPERATOR_EQ: return "is";
        case OPERATOR_GT: return ">";
        case OPERATOR_LT: return "<";
        case OPERATOR_ADD: return "+";
        case OPERATOR_SUB: return "-";
    }

    return "undefined";
}

string literal_type_to_ui_string(Literal_Type literal_type) {
    switch(literal_type) {
        case LITERAL_TYPE_VOID: return "Void";
        case LITERAL_TYPE_NUMBER: return "Number";
        case LITERAL_TYPE_STRING: return "String";
        case LITERAL_TYPE_BOOL: return "Bool";
        case LITERAL_TYPE_OBJECT: return "Object";
        case LITERAL_TYPE_ITEM: return "Item";
        case LITERAL_TYPE_HOTSPOT: return "Hotspot";
        case LITERAL_TYPE_CHARACTER: return "Character";
        case LITERAL_TYPE_VECTOR: return "Vector";
        case LITERAL_TYPE_FUNCTION: return "Function";
        case LITERAL_TYPE_ARRAY: return "Array";
    }

    return "unknown";
}

string literal_to_string(Expression@ literal) {
    switch (literal.literal_type) {
        case LITERAL_TYPE_NUMBER: return literal.literal_value.number_value + "";
        case LITERAL_TYPE_STRING: return "\"" + literal.literal_value.string_value + "\"";

        default: {
            Log(error, "Unsupported literal type " + literal_type_to_ui_string(literal.literal_type));
        }
    }

    return "not_implemented";
}

string native_call_to_string(Expression@ expression) {
    array<string> arguments;
    arguments.resize(expression.arguments.length());

    for (uint argument_index = 0; argument_index < expression.arguments.length(); argument_index++) {
        arguments[argument_index] = expression_to_string(expression.arguments[argument_index]);
    }

    /*
    auto type = expression.FindFittingFunction(context);
    auto sts = expression.expressions;
    array<string> args;

    auto description = state.FindFunctionDescription(expression.name, type);

    if (description !is null) {
        auto format = description.format;

        int index = 0;
        int currentArgument = 0;
        string result = "";

        while (true) {
            int newIndex = format.findFirst("%s", index);

            if (newIndex != -1) {
                auto arg = "(" + expression_to_string(sts[currentArgument], context) + ")";
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
            args.insertLast(expression_to_string(sts[i], context));
        }
    }

    return expression.name + "(" + join(args, ", ") + ")";*/

    return expression.identifier_name + "(" + join(arguments, ", ") + ")";
}

string expression_to_string(Expression@ expression) {
    switch (expression.type) {
        case EXPRESSION_OPERATOR: {
            string result = join(array<string> = {
                expression_to_string(expression.left_operand),
                operator_type_to_ui_string(expression.operator_type),
                expression_to_string(expression.right_operand)
            }, " ");

            if (expression.left_operand.type == EXPRESSION_OPERATOR || expression.right_operand.type == EXPRESSION_OPERATOR) {
                result = "(" + result + ")";
            } 

            return result;
        }

        case EXPRESSION_DECLARATION: {
            return join(array<string> = {
                literal_type_to_ui_string(expression.literal_type),
                expression.identifier_name,
                "=",
                expression_to_string(expression.value_expression)
            }, " ");
        }
            
        case EXPRESSION_ASSIGNMENT:
            return join(array<string> = {
                "set",
                expression.identifier_name,
                "=",
                expression_to_string(expression.value_expression)
            }, " ");
        case EXPRESSION_IDENTIFIER: return expression.identifier_name;
        case EXPRESSION_LITERAL: return literal_to_string(expression);
        case EXPRESSION_NATIVE_CALL: return native_call_to_string(expression);
        case EXPRESSION_REPEAT: {
            return join(array<string> = {
                "Repeat",
                expression_to_string(expression.value_expression),
                "times"
            }, " ");
        }

        case EXPRESSION_IF: return "If " + expression_to_string(expression.value_expression) + " do";
    }

    return "not_implemented (" + expression.type + ")";
}

void draw_editable_expression(Expression@ expression, uint& expression_index, uint& popup_stack_level) {
    if (ImGui_Button(expression_to_string(expression) + "##" + expression_index)) {
        ImGui_OpenPopup("Edit###Popup" + popup_stack_level);
        state.edited_expressions.insertLast(expression);
    }

    ImGui_SetNextWindowPos(ImGui_GetWindowPos() + vec2(20, 20), ImGuiSetCond_Appearing);
    if (ImGui_BeginPopupModal("Edit###Popup" + popup_stack_level, ImGuiWindowFlags_AlwaysAutoResize)) {
        popup_stack_level++;
        draw_expression_as_broken_into_pieces(state.edited_expressions[popup_stack_level - 1], expression_index, popup_stack_level);
        // draw_editable_expression(make_native_call_expr("dog"), expression_index, popup_stack_level);

        if (ImGui_Button("close")) {
            state.edited_expressions.removeLast();
            ImGui_CloseCurrentPopup();
        }

        ImGui_EndPopup();
    }
}

void draw_editable_literal(Expression@ expression, int index) {
    Memory_Cell@ literal_value = expression.literal_value;

    switch (expression.literal_type) {
        case LITERAL_TYPE_NUMBER:
            ImGui_InputFloat("###LiteralFloat" + index, literal_value.number_value, 2);
            break;
        case LITERAL_TYPE_STRING:
            ImGui_SetTextBuf(literal_value.string_value);

            if (ImGui_InputText("###DeclarationInput" + index)) {
                literal_value.string_value = ImGui_GetTextBuf();
            }

            break;
        case LITERAL_TYPE_BOOL:
            ImGui_Text("Not implemented");
            // ImGui_Checkbox("###LiteralFloat" + index, literal_value.int_value);
            break;
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
        case LITERAL_TYPE_VECTOR:
            // ImGui_InputFloat3("###LiteralVector" + index, statement.valueVector, 2);
            ImGui_Text("Not implemented");
            break;
        case LITERAL_TYPE_ARRAY:
            ImGui_Text("Array input here");
            break;
    }
}

void draw_type_selector(Expression@ expression, string text_label, Literal_Type limit_to) {
    array<Literal_Type> all_types;

    if (limit_to != 0) {
        all_types.resize(0);
        all_types.insertLast(limit_to);
    } else {
        all_types.reserve(LITERAL_TYPE_LAST - 1);

        for (Literal_Type type = Literal_Type(0); type < LITERAL_TYPE_LAST; type++) {
            all_types.insertLast(type);
        }
    }

    array<string> type_names;
    int selected = -1;

    for (uint index = 0; index < all_types.length(); index++) {
        if (all_types[index] == expression.literal_type) {
            selected = index;
        }

        type_names.insertLast(literal_type_to_ui_string(all_types[index]));
    }

    if (ImGui_Combo(text_label, selected, type_names)) {
        expression.literal_type = all_types[selected];
    }

    ImGui_SameLine();
}

void draw_expression_as_broken_into_pieces(Expression@ expression, uint& expression_index, uint& popup_stack_level) {
    switch (expression.type) {
        case EXPRESSION_LITERAL: {
            draw_editable_literal(expression, expression_index);
            //ImGui_Button(literal_to_string(expression));
            break;
        }
        
        case EXPRESSION_IDENTIFIER: {
            ImGui_Button(expression.identifier_name);
            break;
        }

        case EXPRESSION_OPERATOR: {
            pre_expression_text("(");
            draw_expression_and_continue_on_the_same_line(expression.left_operand, expression_index, popup_stack_level);
            pre_expression_text(operator_type_to_ui_string(expression.operator_type));
            draw_editable_expression(expression.right_operand, expression_index, popup_stack_level);
            post_expression_text(")");
            break;
        }

        case EXPRESSION_IF: {
            pre_expression_text("If");
            draw_editable_expression(expression.value_expression, expression_index, popup_stack_level);

            break;
        }

        case EXPRESSION_REPEAT: {
            pre_expression_text("Repeat");
            draw_editable_expression(expression.value_expression, expression_index, popup_stack_level);
            post_expression_text("times");
            break;
        }

        case EXPRESSION_DECLARATION: {
            pre_expression_text("variable of type");
            draw_type_selector(expression, "", Literal_Type(0));
            draw_button_and_continue_on_the_same_line(expression.identifier_name + "##" + expression_index);
            pre_expression_text("=");
            draw_editable_expression(expression.value_expression, expression_index, popup_stack_level);
            break;
        }

        case EXPRESSION_ASSIGNMENT: {
            pre_expression_text("set");
            draw_button_and_continue_on_the_same_line(expression.identifier_name + "##" + expression_index);
            pre_expression_text("=");
            draw_editable_expression(expression.value_expression, expression_index, popup_stack_level);
            break;
        }

        case EXPRESSION_NATIVE_CALL: {
            pre_expression_text("call");
            draw_button_and_continue_on_the_same_line(expression.identifier_name + "##" + expression_index);

            pre_expression_text("(");

            for (uint argument_index = 0; argument_index < expression.arguments.length(); argument_index++) {
                draw_expression_and_continue_on_the_same_line(expression.arguments[argument_index], expression_index, popup_stack_level);
            }

            post_expression_text(")");

            break;
        }

        default: {
            ImGui_Button("not_implemented##" + expression_index);
            break;
        }
    }
}

void draw_expression_with_block_body_if_present(Expression@ expression, uint& expression_index, uint& popup_stack_level) {
    draw_editable_expression(expression, expression_index, popup_stack_level);

    switch (expression.type) {
        case EXPRESSION_IF: {
            draw_expressions_in_a_tree_node("Then", expression.block_body, expression_index, popup_stack_level);
            draw_expressions_in_a_tree_node("Else", expression.else_block_body, expression_index, popup_stack_level);
            break;
        }

        case EXPRESSION_REPEAT: {
            draw_expressions_in_a_tree_node("Actions", expression.block_body, expression_index, popup_stack_level);
            break;
        }
    }

    expression_index++;
}

void draw_top_level_expression_with_block_body_if_present(Expression@ expression, uint& expression_index, uint& popup_stack_level) {
    ImGui_Button("X");
    ImGui_SameLine();

    draw_expression_with_block_body_if_present(expression, expression_index, popup_stack_level);
}

void draw_expressions_(array<Expression@>@ expressions, uint& expression_index, uint& popup_stack_level) {
    for (uint index = 0; index < expressions.length(); index++) {
        draw_top_level_expression_with_block_body_if_present(expressions[index], expression_index, popup_stack_level);
    }
}

void draw_expressions(array<Expression@>@ expressions) {
    uint expression_index = 0;
    uint stack_depth = 0;
    array<array<Expression@>@> expression_stack;
    array<uint> iteration_index;

    expression_stack.insertLast(expressions);
    iteration_index.insertLast(0);

    ImGui_TreeNodeEx("Actions###StatementBlock" + expression_index, ImGuiTreeNodeFlags_OpenOnDoubleClick | ImGuiTreeNodeFlags_DefaultOpen);

    Log(info, "---");

    while (true) {
        uint current_iteration_index = iteration_index[stack_depth];
        array<Expression@>@ current_expressions = expression_stack[stack_depth];
        Expression@ current_expression = current_expressions[current_iteration_index];

        // Log(info, current_iteration_index + " " + current_expressions.length() + " " + current_expression.type);

        expression_index++;

        if (current_expression.type == EXPRESSION_REPEAT || current_expression.type == EXPRESSION_IF) {
            // Log(info, "go inside");
            iteration_index[stack_depth]++;

            if (ImGui_TreeNodeEx("Actions###StatementBlock" + expression_index, ImGuiTreeNodeFlags_OpenOnDoubleClick | ImGuiTreeNodeFlags_DefaultOpen)) {
                expression_stack.insertLast(current_expression.block_body);
                iteration_index.insertLast(0);
                stack_depth++;
            } else {
                Log(info, "closed pop");
                ImGui_TreePop();
            }
            
            continue;
        }

        ImGui_Button("DOG##" + expression_index);

        current_iteration_index++;
        iteration_index[stack_depth] = current_iteration_index;

        while (iteration_index[stack_depth] == expression_stack[stack_depth].length()) {
            Log(info, "OUT");
            expression_stack.removeLast();
            iteration_index.removeLast();
            stack_depth--;

            ImGui_TreePop();

            if (expression_stack.length() == 0) {
                break;
            }
        }

        if (expression_stack.length() == 0) {
            break;
        }

    }
}

void draw_trigger_content(Trigger@ current_trigger) {
    ImGui_BeginGroup();

    ImGui_AlignFirstTextHeightToWidgets();
    ImGui_Text("Content");

    ImGui_SetTextBuf(current_trigger.name);
    if (ImGui_InputText("###TriggerName")) {
        current_trigger.name = ImGui_GetTextBuf();
    }

    ImGui_SetTextBuf(current_trigger.description);
    if (ImGui_InputTextMultiline("###TriggerDescription", vec2(0, 50))) {
        current_trigger.description = ImGui_GetTextBuf();
    }

    int index = 0;
    //state.current_stack_depth = 0;

    //auto ctx = script.CreateContext();

    ImGui_AlignFirstTextHeightToWidgets();
    ImGui_Text("Event");

    uint expression_index = 0;
    uint popup_stack_level = 0;

    draw_expressions_(current_trigger.content, expression_index, popup_stack_level);
    //DrawEventSelector(current_trigger.triggerFunction, ctx);

    // auto call = current_trigger.triggerFunction;

    // DrawFunctionCall(call, ctx, null, function(f) {
    //     return f.isDefaultEvent;
    // }, index);

    // for (uint j = 0; j < call.statements.length(); j++) {
    //     if (call.statements[j].literalType is null) {
    //         continue;
    //     }

    //     if (call.statements[j].literalType.literal == LITERAL_TYPE_FUNCTION) {
    //         DrawStatements(call.statements[j], call.statements[j].statements, ctx, ++index);
    //     }
    // }

    
    //DrawStatements(null, array<Expression@> = { current_trigger.triggerFunction }, script.CreateContext(), index);

    /*if (ImGui_Button("Eval")) {
        script.Execute(
            AST::FunctionCall(
                current_trigger.triggerFunction.TransformToExpression(ctx),
                array<AST::Expression@>()
            )
        );
    }*/

    ImGui_EndGroup();
}