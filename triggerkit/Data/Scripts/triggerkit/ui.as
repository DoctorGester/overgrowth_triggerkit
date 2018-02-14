#include "triggerkit/ui_util.as"

class Trigger {
    string name;
    string description;
    array<Expression@> conditions;
    array<Expression@> actions;
    Event_Type event_type = EVENT_CHARACTER_ENTERS_REGION;

    uint function_entry_pointer;

    Trigger(string name) {
        this.name = name;
    }
}

class Trigger_Kit_State {
    array<Expression@> edited_expressions;
    array<Function_Definition@> function_definitions;
    array<Event_Definition@> native_events;

    int current_stack_depth = 0;
    int selected_action_category = 0;
    int selected_trigger;

    array<Trigger@> triggers;
    array<Variable> global_variables;
}

class Variable {
    Literal_Type type;
    Memory_Cell value;
    string name;
}

class Ui_Frame_State {
    uint expression_index;
    uint popup_stack_level;

    Ui_Variable_Scope@ top_scope;

    string unique_id(string id) {
        return "###" + id + (expression_index++);
    }
}

class Ui_Variable_Scope {
    Ui_Variable_Scope@ parent_scope;

    array<Variable>@ variables;
}

void push_ui_variable_scope(Ui_Frame_State@ frame) {
    Ui_Variable_Scope new_scope;
    @new_scope.parent_scope = frame.top_scope;
    @new_scope.variables = array<Variable>();

    @frame.top_scope = new_scope;
}

void pop_ui_variable_scope(Ui_Frame_State@ frame) {
    if (frame.top_scope !is null)
    @frame.top_scope = frame.top_scope.parent_scope;
}

void collect_scope_variables(Ui_Variable_Scope@ from_scope, array<Variable@>@ target) {
    // TODO Variable shadowing duplicates variables!
    for (uint variable_index = 0; variable_index < from_scope.variables.length(); variable_index++) {
        target.insertLast(from_scope.variables[variable_index]);
    }

    if (from_scope.parent_scope !is null) {
        collect_scope_variables(from_scope.parent_scope, target);
    }
}

Trigger_Kit_State@ make_trigger_kit_state() {
    Trigger_Kit_State state;

    Api_Builder@ api_builder = build_api();
    state.function_definitions = api_builder.functions;
    state.native_events = api_builder.events;

    return state;
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

        //state.Persist();
    }

    ImGui_SameLine();

    if (ImGui_Button("Rem")) {
        state.triggers.removeAt(uint(state.selected_trigger));
        state.selected_trigger = max(state.selected_trigger - 1, 0);

        //state.Persist();
    }

    ImGui_SameLine();

    if (ImGui_Button("Load")) {
        // state.triggers = Persistence::Load();
        // state.TransformParseTree();
    }

    ImGui_SameLine();

    if (ImGui_Button("Globals")) {
        ImGui_OpenPopup("Globals###globals_popup");
    }

    bool is_open = true;

    if (ImGui_BeginPopupModal("Globals###globals_popup", is_open)) {
        draw_globals_modal();

        ImGui_EndPopup();
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

void draw_expressions_in_a_tree_node(string title, array<Expression@>@ expressions, Ui_Frame_State@ frame) {
    if (ImGui_TreeNodeEx(title + frame.unique_id("expression_block"), ImGuiTreeNodeFlags_OpenOnDoubleClick | ImGuiTreeNodeFlags_DefaultOpen)) {
        draw_expressions(expressions, frame);
        ImGui_TreePop();
    }
}

void draw_expression_and_continue_on_the_same_line(Expression@ expression, Ui_Frame_State@ frame) {
    draw_editable_expression(expression, frame);
    ImGui_SameLine();
}

bool draw_button_and_continue_on_the_same_line(string text) {
    bool result = ImGui_Button(text);
    ImGui_SameLine();

    return result;
}

void pop_edited_expression(Ui_Frame_State@ frame) {
    state.edited_expressions.removeLast();
    frame.popup_stack_level--;
}

void draw_editor_popup_footer(Ui_Frame_State@ frame) {
    ImGui_NewLine();
    ImGui_Separator();
    ImGui_NewLine();

    if (ImGui_Button("close###" + frame.popup_stack_level)) {
        pop_edited_expression(frame);
        ImGui_CloseCurrentPopup();
    }
}

void draw_editor_popup_function_selector(Expression@ expression) {
    int selected_function = 0;
    array<string> function_names;

    for (uint function_index = 0; function_index < state.function_definitions.length(); function_index++) {
        Function_Definition@ function_definition = state.function_definitions[function_index];

        string name = get_function_name_for_list(function_definition);

        if (expression.identifier_name == function_definition.function_name) {
            selected_function = function_index;
        }

        function_names.insertLast(name);
    }

    if (ImGui_Combo("##function_selector", selected_function, function_names)) {
        Function_Definition@ selected_definition = state.function_definitions[selected_function];

        fill_function_call_expression_from_function_definition(expression, selected_definition);
    }
}

void draw_statement_editor_popup(Ui_Frame_State@ frame) {
    Expression@ expression = state.edited_expressions[frame.popup_stack_level - 1];

    ImGui_Text("Action type");

    array<string> action_names = { "Declare Variable", "Assign Variable", "If/Then/Else" };

    uint functions_offset = action_names.length();
    int selected_action = -1;

    switch (expression.type) {
        case EXPRESSION_DECLARATION: {
            selected_action = 0;
            break;
        }

        case EXPRESSION_ASSIGNMENT: {
            selected_action = 1;
            break;
        }

        case EXPRESSION_IF: {
            selected_action = 2;
            break;
        }
    }

    for (uint function_index = 0; function_index < state.function_definitions.length(); function_index++) {
        Function_Definition@ function_definition = state.function_definitions[function_index];

        string name = get_function_name_for_list(function_definition);

        if (expression.type == EXPRESSION_CALL && expression.identifier_name == function_definition.function_name) {
            selected_action = function_index + functions_offset;
        }

        action_names.insertLast(name);
    }

    if (ImGui_Combo("##function_selector", selected_action, action_names)) {
        switch (selected_action) {
            case 0: {
                expression.type = EXPRESSION_DECLARATION;
                break;
            }

            case 1: {
                expression.type = EXPRESSION_ASSIGNMENT;
                @expression.value_expression = make_empty_lit(LITERAL_TYPE_BOOL);
                break;
            }

            case 2: {
                expression.type = EXPRESSION_IF;
                @expression.value_expression = make_lit(true);
                break;
            }

            default: {
                expression.type = EXPRESSION_CALL;

                Function_Definition@ selected_definition = state.function_definitions[selected_action - functions_offset];

                fill_function_call_expression_from_function_definition(expression, selected_definition);
            }
        }
    }

    ImGui_NewLine();
    ImGui_Separator();
    ImGui_NewLine();

    ImGui_Text("Action text");
    draw_expression_as_broken_into_pieces(expression, frame);

    draw_editor_popup_footer(frame);
}

bool draw_variable_selector(Ui_Frame_State@ frame, Expression@ expression) {
    array<Variable@> scope_variables;

    // TODO incorrect, doesn't consider variable declaration locations, bad!
    collect_scope_variables(frame.top_scope, scope_variables);

    array<string> variable_names;
    int selected_variable = -1;

    for (uint variable_index = 0; variable_index < scope_variables.length(); variable_index++) {
        string variable_name = scope_variables[variable_index].name;

        variable_names.insertLast(variable_name);

        if (variable_name == expression.identifier_name) {
            selected_variable = variable_index;
        }
    }

    bool changed = ImGui_Combo(frame.unique_id("variable_selector"), selected_variable, variable_names);

    if (changed) {
        expression.identifier_name = variable_names[selected_variable];
    }

    return changed;
}

void draw_expression_editor_popup(Ui_Frame_State@ frame) {
    Expression@ expression = state.edited_expressions[frame.popup_stack_level - 1];

    const int offset = 200;

    if (ImGui_RadioButton("Variable", expression.type == EXPRESSION_IDENTIFIER)) {
        expression.type = EXPRESSION_IDENTIFIER;
    }

    ImGui_SameLine();
    ImGui_SetCursorPosX(offset);
    
    if (draw_variable_selector(frame, expression)) {
        expression.type = EXPRESSION_IDENTIFIER;
    }

    bool is_a_function_call = expression.type == EXPRESSION_CALL;
    bool is_an_operator = expression.type == EXPRESSION_OPERATOR;

    if (ImGui_RadioButton("Function", is_a_function_call || is_an_operator)) {
        expression.type = EXPRESSION_CALL;
    }

    ImGui_SameLine();
    ImGui_SetCursorPosX(offset);
    draw_editor_popup_function_selector(expression);

    if (is_a_function_call || is_an_operator) {
        ImGui_SetCursorPosX(offset);
        draw_expression_as_broken_into_pieces(expression, frame);
    }

    if (ImGui_RadioButton("Value", expression.type == EXPRESSION_LITERAL)) {
        expression.type = EXPRESSION_LITERAL;
    }

    ImGui_SameLine();
    ImGui_SetCursorPosX(offset);

    draw_editable_literal(expression.literal_type, expression.literal_value, frame.unique_id("editable_literal"));
    
    draw_editor_popup_footer(frame);
}

void draw_editable_expression(Expression@ expression, Ui_Frame_State@ frame, bool parent_is_a_code_block = false) {
    if (ImGui_Button(expression_to_string(expression) + frame.unique_id("editable_button"))) {
        ImGui_OpenPopup("Edit###Popup" + frame.popup_stack_level);
        state.edited_expressions.insertLast(expression);
    }

    bool is_open = true;

    ImGui_SetNextWindowPos(ImGui_GetWindowPos() + vec2(20, 20), ImGuiSetCond_Appearing);
    if (ImGui_BeginPopupModal("Edit###Popup" + frame.popup_stack_level, is_open, ImGuiWindowFlags_AlwaysAutoResize)) {
        frame.popup_stack_level++;

        if (parent_is_a_code_block) {
            draw_statement_editor_popup(frame);
        } else {
            draw_expression_editor_popup(frame);
        }

        ImGui_EndPopup();
    }

    if (!is_open) {
        pop_edited_expression(frame);
    }
}

void draw_editable_literal(Literal_Type literal_type, Memory_Cell@ literal_value, string unique_id) {
    switch (literal_type) {
        case LITERAL_TYPE_NUMBER:
            ImGui_InputFloat(unique_id, literal_value.number_value, 1);
            break;
        case LITERAL_TYPE_STRING:
            ImGui_SetTextBuf(literal_value.string_value);

            if (ImGui_InputText(unique_id)) {
                literal_value.string_value = ImGui_GetTextBuf();
            }

            break;
        case LITERAL_TYPE_BOOL: {
            bool value = number_to_bool(literal_value.number_value);

            if (ImGui_Checkbox(unique_id, value)) {
                literal_value.number_value = bool_to_number(value);
            }

            ImGui_SameLine();
            ImGui_Text(value ? "True" : "False");
            // ImGui_Checkbox("###LiteralFloat" + index, literal_value.int_value);
            break;
        }

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

void draw_type_selector(Literal_Type& input_type, string text_label, Literal_Type limit_to) {
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
        if (all_types[index] == input_type) {
            selected = index;
        }

        type_names.insertLast(colored_literal_type(all_types[index]));
    }

    if (ImGui_Combo(text_label, selected, type_names)) {
        input_type = all_types[selected];
    }

    ImGui_SameLine();
}

void draw_function_call_as_broken_into_pieces_simple(Expression@ expression, Ui_Frame_State@ frame) {
    draw_button_and_continue_on_the_same_line(expression.identifier_name + frame.unique_id("function_name"));

    pre_expression_text("(");

    for (uint argument_index = 0; argument_index < expression.arguments.length(); argument_index++) {
        draw_expression_and_continue_on_the_same_line(expression.arguments[argument_index], frame);
    }

    post_expression_text(")");
}

void draw_function_call_as_broken_into_pieces(Expression@ expression, Ui_Frame_State@ frame) {
    Function_Definition@ function_definition = find_function_definition_by_function_name(expression.identifier_name);

    if (function_definition is null) {
        draw_function_call_as_broken_into_pieces_simple(expression, frame);
        return;
    }

    array<string>@ pieces = split_function_format_string_into_pieces(function_definition.format);

    ImGui_AlignFirstTextHeightToWidgets();

    for (uint argument_index = 0; argument_index < function_definition.argument_types.length(); argument_index++) {
        if (!pieces[argument_index].isEmpty()) {
            ImGui_Text(pieces[argument_index]);
            ImGui_SameLine();
        }

        string argument_as_string = literal_type_to_ui_string(function_definition.argument_types[argument_index]);
        bool argument_found = false;

        if (expression.arguments.length() > argument_index) {
            Expression@ argument_expression = expression.arguments[argument_index];
            argument_found = argument_expression !is null;

            if (argument_found) {
                draw_expression_and_continue_on_the_same_line(argument_expression, frame);
            }
        }

        if (!argument_found) {
            ImGui_Text(argument_as_string);
            ImGui_SameLine();
        }
    }

    ImGui_Text(pieces[pieces.length() - 1]);
}

void draw_expression_as_broken_into_pieces(Expression@ expression, Ui_Frame_State@ frame) {
    switch (expression.type) {
        case EXPRESSION_LITERAL: {
            draw_editable_literal(expression.literal_type, expression.literal_value, frame.unique_id("editable_literal"));
            //ImGui_Button(literal_to_ui_string(expression));
            break;
        }
        
        case EXPRESSION_IDENTIFIER: {
            ImGui_Button(expression.identifier_name + frame.unique_id("identifier"));
            break;
        }

        case EXPRESSION_OPERATOR: {
            pre_expression_text("(");
            draw_expression_and_continue_on_the_same_line(expression.left_operand, frame);
            pre_expression_text(operator_type_to_ui_string(expression.operator_type));
            draw_editable_expression(expression.right_operand, frame);
            post_expression_text(")");
            break;
        }

        case EXPRESSION_IF: {
            pre_expression_text("If");
            draw_editable_expression(expression.value_expression, frame);

            break;
        }

        case EXPRESSION_REPEAT: {
            pre_expression_text("Repeat");
            draw_editable_expression(expression.value_expression, frame);
            post_expression_text("times");
            break;
        }

        case EXPRESSION_DECLARATION: {
            pre_expression_text(colored_keyword("Declare"));
            draw_type_selector(expression.literal_type, "", Literal_Type(0));
            draw_button_and_continue_on_the_same_line(expression.identifier_name + frame.unique_id("declare"));
            pre_expression_text("=");
            draw_editable_expression(expression.value_expression, frame);
            break;
        }

        case EXPRESSION_ASSIGNMENT: {
            pre_expression_text("set");
            draw_variable_selector(frame, expression);
            ImGui_SameLine();
            pre_expression_text("=");
            draw_editable_expression(expression.value_expression, frame);
            break;
        }

        case EXPRESSION_CALL: {
            draw_function_call_as_broken_into_pieces(expression, frame);

            break;
        }

        default: {
            ImGui_Button("not_implemented##" + frame.unique_id("not_implemented"));
            break;
        }
    }
}

void draw_expressions(array<Expression@>@ expressions, Ui_Frame_State@ frame) {
    if (expressions.length() == 0) {
        if (ImGui_Button("+##bluz")) {
            expressions.insertLast(make_function_call("do_nothing"));
            return;
        }
    }

    push_ui_variable_scope(frame);

    for (int index = 0; uint(index) < expressions.length(); index++) {
        Expression@ expression = expressions[uint(index)];

        if (expression.type == EXPRESSION_DECLARATION) {
            Variable variable;
            variable.name = expression.identifier_name;
            variable.type = expression.literal_type;

            frame.top_scope.variables.insertLast(variable);
        }

        vec2 cursor_start_pos = ImGui_GetCursorScreenPos() ;

        draw_expression_image(expression);
        draw_editable_expression(expression, frame, true);

        vec2 hover_min = cursor_start_pos;
        vec2 hover_max = cursor_start_pos + vec2(900, 18);

        if (ImGui_IsMouseHoveringRect(hover_min, hover_max)) {
            float x_position_snapped = int((ImGui_GetMousePos().x - ImGui_GetWindowPos().x) / 64) * 64;

            ImGui_SameLine();
            // ImGui_SetCursorPosX(x_position_snapped);
            
            if (ImGui_Button("+")) {
                Expression@ new_expression = make_function_call("do_nothing");
                expressions.insertAt(uint(index) + 1, new_expression);
                ImGui_OpenPopup("Edit###Popup" + frame.popup_stack_level);
                state.edited_expressions.insertLast(new_expression);
            }

            ImGui_SameLine();

            if (ImGui_Button("X")) {
                expressions.removeAt(index);

                index--;
            }
        }

        switch (expression.type) {
            case EXPRESSION_IF: {
                draw_expressions_in_a_tree_node("Then do", expression.block_body, frame);
                draw_expressions_in_a_tree_node("Else do", expression.else_block_body, frame);
                break;
            }

            case EXPRESSION_WHILE:
            case EXPRESSION_REPEAT: {
                draw_expressions_in_a_tree_node("Actions", expression.block_body, frame);
                break;
            }
        }
    }

    pop_ui_variable_scope(frame);
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

    Ui_Frame_State frame;
    Ui_Variable_Scope global_scope;
    @global_scope.variables = state.global_variables;
    @frame.top_scope = global_scope;

    if (ImGui_TreeNodeEx("Event###event_block", ImGuiTreeNodeFlags_OpenOnDoubleClick | ImGuiTreeNodeFlags_DefaultOpen)) {
        int selected_event = 0;
        array<string> event_names;

        for (uint event_index = 0; event_index < EVENT_LAST; event_index++) {
            event_names.insertLast(state.native_events[event_index].pretty_name);
        }

        ImGui_Combo("##function_selector", selected_event, event_names);

        ImGui_TreePop();
    }

    push_ui_variable_scope(frame);

    Event_Definition@ trigger_event = state.native_events[current_trigger.event_type];

    for (uint variable_index = 0; variable_index < trigger_event.variable_types.length(); variable_index++) {
        // TODO Code duplication
        Variable variable;
        variable.name = trigger_event.variable_names[variable_index];
        variable.type = trigger_event.variable_types[variable_index];

        frame.top_scope.variables.insertLast(variable);
    }

    draw_expressions_in_a_tree_node("Conditions", current_trigger.conditions, frame);
    draw_expressions_in_a_tree_node("Actions", current_trigger.actions, frame);

    pop_ui_variable_scope(frame);

    ImGui_EndGroup();
}

void draw_globals_modal() {
    float window_width = ImGui_GetWindowWidth();

    ImGui_PushItemWidth(int(window_width) - 14);

    ImGui_ListBoxHeader("###global_list", 16, 8);

    float right_padding = 100;
    float st = ImGui_GetCursorPosX();
    float free_width = window_width - st - right_padding;

    for (uint variable_index = 0; variable_index < state.global_variables.length(); variable_index++) {
        Variable@ variable = state.global_variables[variable_index];

        ImGui_AlignFirstTextHeightToWidgets();
        ImGui_Image(icons::action_variable, vec2(16, 16));
        ImGui_SameLine();

        ImGui_PushItemWidth(int(free_width * 0.2));

        ImGui_SetTextBuf(variable.name);
        if (ImGui_InputText("###variable_name" + variable_index)) {
            variable.name = ImGui_GetTextBuf();
        }

        ImGui_PopItemWidth();
        ImGui_SameLine();

        {
            ImGui_PushItemWidth(int(free_width * 0.2));
            
            draw_type_selector(variable.type, "###type_selector" + variable_index, Literal_Type(0));

            ImGui_PopItemWidth();
            ImGui_SameLine();
        }

        {
            float cursor_pre_checkbox = ImGui_GetCursorPosX();

            bool a = false;
            ImGui_Checkbox("Is array", a);
            ImGui_SameLine();

            ImGui_SetCursorPosX(cursor_pre_checkbox + free_width * 0.15f);
        }

        {
            ImGui_PushItemWidth(int(free_width * 0.45));
            draw_editable_literal(variable.type, variable.value, variable_index + "");
            ImGui_PopItemWidth();
        }

        ImGui_SameLine();
        ImGui_SetCursorPosX(window_width - 40);
        
        if (ImGui_Button("X###" + variable_index)) {
            state.global_variables.removeAt(variable_index);

            if (variable_index > 0) {
                variable_index--;
            }
        }
    }

    ImGui_ListBoxFooter();
    ImGui_PopItemWidth();

    if (icon_button("Add", "variable_add", icons::action_variable)) {
        state.global_variables.insertLast(Variable());
    }
}