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
    array<Operator_Group@> operator_groups;

    int selected_action_category = 0;
    int selected_trigger;

    array<Trigger@> triggers;
    array<Variable> global_variables;

    bool is_cameras_window_open = true;
}

class Variable {
    Literal_Type type;
    Memory_Cell value;
    string name;
}

class Ui_Frame_State {
    uint expression_index;
    uint popup_stack_level;
    uint line_counter;
    uint argument_counter;

    bool drawing_conditions_block;

    Variable_Scope@ top_scope;

    string unique_id(string id) {
        return "###" + id + (expression_index++);
    }
}

class Ui_Special_Action {
    Expression_Type expression_type;
    string action_name;

    Ui_Special_Action() {}

    Ui_Special_Action(string name, Expression_Type type) {
        this.expression_type = type;
        this.action_name = name;
    }
}

void push_ui_variable_scope(Ui_Frame_State@ frame) {
    Variable_Scope new_scope;
    @new_scope.parent_scope = frame.top_scope;
    @new_scope.variables = array<Variable>();

    @frame.top_scope = new_scope;
}

void pop_ui_variable_scope(Ui_Frame_State@ frame) {
    if (frame.top_scope !is null)
    @frame.top_scope = frame.top_scope.parent_scope;
}

// TODO this is technically used in compiler, shouldn't be in ui.as
void collect_scope_variables(Variable_Scope@ from_scope, array<Variable@>@ target, Literal_Type limit_to = LITERAL_TYPE_VOID) {
    // TODO Variable shadowing duplicates variables!
    for (uint variable_index = 0; variable_index < from_scope.variables.length(); variable_index++) {
        if (limit_to == LITERAL_TYPE_VOID || limit_to == from_scope.variables[variable_index].type) {
            target.insertLast(from_scope.variables[variable_index]);
        }
    }

    if (from_scope.parent_scope !is null) {
        collect_scope_variables(from_scope.parent_scope, target, limit_to);
    }
}

Variable@ make_variable(Literal_Type type, string name) {
    Variable variable;
    variable.type = type;
    variable.name = name;

    return variable;
}

Trigger_Kit_State@ make_trigger_kit_state() {
    Trigger_Kit_State state;

    // TODO this COPIES all arrays, that's bad
    // We could also just store the api builder itself in the state
    Api_Builder@ api_builder = build_api();
    state.function_definitions = api_builder.functions;
    state.native_events = api_builder.events;
    state.operator_groups = api_builder.operator_groups;

    return state;
}

void draw_icon_menu_bar() {
    ImGui_BeginGroup();

    if (icon_button("New trigger", "new_trigger", icons::trigger)) {
        string trigger_name = find_vacant_trigger_name();

        Trigger trigger(trigger_name);
        state.selected_trigger = state.triggers.length();
        state.triggers.insertLast(trigger);

        //state.Persist();
    }

    ImGui_SameLine();

    if (icon_button("Variables", "open_globals", icons::action_variable)) {
        ImGui_OpenPopup("Variables###globals_popup");
    }

    ImGui_SameLine();

    bool is_globals_window_open = true;

    ImGui_SetNextWindowSize(vec2(800, 400), ImGuiSetCond_Appearing);
    if (ImGui_BeginPopupModal("Globals###globals_popup", is_globals_window_open)) {
        draw_globals_modal();

        ImGui_EndPopup();
    }

    if (state.is_cameras_window_open) {
        ImGui_SetNextWindowSize(vec2(300, 600), ImGuiSetCond_Appearing);
        if (ImGui_Begin("Cameras###camers_window", state.is_cameras_window_open)) {
            draw_cameras_window();

            ImGui_End();
        }
    }

    if (icon_button("Cameras", "open_cameras", icons::action_camera)) {
        state.is_cameras_window_open = !state.is_cameras_window_open;
    }

    ImGui_EndGroup();
}

void draw_trigger_list() {
    ImGui_BeginGroup();
    ImGui_AlignFirstTextHeightToWidgets();
    ImGui_Text("Triggers");

    ImGui_ListBoxHeader("##trigger_list", vec2(200, ImGui_GetWindowHeight() - ImGui_GetCursorPosY() - 8));

    for (uint trigger_index = 0; trigger_index < state.triggers.length(); trigger_index++) {
        string trigger_name_and_id = state.triggers[trigger_index].name + "##list_trigger" + trigger_index;

        if (ImGui_Selectable(trigger_name_and_id, int(trigger_index) == state.selected_trigger)) {
            state.selected_trigger = trigger_index;
        }

        if (ImGui_BeginPopupContextItem("##list_trigger_popup" + trigger_index)) {
            if (ImGui_MenuItem("Delete")) {
                state.triggers.removeAt(trigger_index);
                state.selected_trigger = max(state.selected_trigger - 1, 0);

                //state.Persist();
            }

            ImGui_EndPopup();
        }

    }

    ImGui_ListBoxFooter();

    ImGui_EndGroup();
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

    draw_icon_menu_bar();
    draw_trigger_list();

    ImGui_SameLine();

    if (state.selected_trigger != -1 && uint(state.selected_trigger) < state.triggers.length()) {
        draw_trigger_content(state.triggers[uint(state.selected_trigger)]);
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

void draw_expressions_in_a_tree_node(string title, array<Expression@>@ expressions, Ui_Frame_State@ frame, Literal_Type limit_to = LITERAL_TYPE_VOID) {
    if (ImGui_TreeNodeEx(title + frame.unique_id("expression_block"), ImGuiTreeNodeFlags_OpenOnDoubleClick | ImGuiTreeNodeFlags_DefaultOpen)) {
        draw_expressions(expressions, frame, limit_to: limit_to);
        ImGui_TreePop();
    }
}

void draw_expression_and_continue_on_the_same_line(Expression@ expression, Ui_Frame_State@ frame, Literal_Type limit_to = LITERAL_TYPE_VOID) {
    draw_editable_expression(expression, frame, limit_to: limit_to);
    ImGui_SameLine();
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

void draw_editor_popup_function_selector(Expression@ expression, Ui_Frame_State@ frame, Literal_Type limit_to) {
    array<Operator_Group@>@ operator_groups = filter_operator_groups_by_return_type(limit_to);
    array<Function_Definition@>@ source_functions = filter_function_definitions_by_return_type(limit_to);

    int selected_expression = 0;
    array<string> expression_names;

    int functions_offset = operator_groups.length();

    bool fit_operator_to_a_selected_action = false;

    Operator_Definition@ current_fitting_operator = find_operator_definition_by_expression_in_context(expression, frame.top_scope);

    for (uint group_index = 0; group_index < operator_groups.length(); group_index++) {
        Operator_Group@ group = operator_groups[group_index];

        if (current_fitting_operator !is null && group is current_fitting_operator.parent_group) {
            selected_expression = group_index;
            fit_operator_to_a_selected_action = true;
        }

        expression_names.insertLast(group.name);
    }

    for (uint function_index = 0; function_index < source_functions.length(); function_index++) {
        Function_Definition@ function_definition = source_functions[function_index];

        string name = get_function_name_for_list(function_definition);

        if (!fit_operator_to_a_selected_action && expression.identifier_name == function_definition.function_name) {
            selected_expression = function_index + functions_offset;
        }

        expression_names.insertLast(name);
    }

    if (ImGui_Combo("##function_selector", selected_expression, expression_names)) {
        if (selected_expression < functions_offset) {
            Operator_Definition@ first_operator = operator_groups[selected_expression].operators[0];

            expression.type = EXPRESSION_OPERATOR;

            fill_operator_expression_from_operator_definition(expression, first_operator);
        } else {
            Function_Definition@ selected_definition = source_functions[selected_expression - functions_offset];

            expression.type = EXPRESSION_CALL;

            fill_function_call_expression_from_function_definition(expression, selected_definition);
        }
    }
}

void handle_expression_type_changed_to(Expression_Type expression_type, Expression@ expression) {
    switch (expression_type) {
        case EXPRESSION_DECLARATION: {
            expression.literal_type = LITERAL_TYPE_NUMBER;
            @expression.value_expression = make_lit(0);
            break;
        }

        case EXPRESSION_ASSIGNMENT: {
            @expression.value_expression = make_empty_lit(LITERAL_TYPE_BOOL);
            break;
        }

        case EXPRESSION_WHILE:
        case EXPRESSION_IF: {
            @expression.value_expression = make_lit(true);
            break;
        }
    }
}

void draw_statement_editor_popup(Ui_Frame_State@ frame, Literal_Type limit_to) {
    Expression@ expression = state.edited_expressions[frame.popup_stack_level - 1];

    ImGui_Text("Action type");

    int selected_action = -1;

    array<string> action_names;
    array<Function_Definition@>@ source_functions;
    array<Ui_Special_Action> special_actions;

    if (limit_to != LITERAL_TYPE_VOID) {
        @source_functions = filter_function_definitions_by_return_type(limit_to);
    } else {
        @source_functions = state.function_definitions;

        special_actions = array<Ui_Special_Action> = {
            Ui_Special_Action("Declare Variable", EXPRESSION_DECLARATION),
            Ui_Special_Action("Assign Variable", EXPRESSION_ASSIGNMENT),
            Ui_Special_Action("If/Then/Else", EXPRESSION_IF),
            Ui_Special_Action("While/Do", EXPRESSION_WHILE),
            Ui_Special_Action("Run in Parallel", EXPRESSION_FORK)
        };

        for (uint action_index = 0; action_index < special_actions.length(); action_index++) {
            if (special_actions[action_index].expression_type == expression.type) {
                selected_action = action_index;
            }

            action_names.insertLast(special_actions[action_index].action_name);
        }
    }

    uint functions_offset = special_actions.length();

    for (uint function_index = 0; function_index < source_functions.length(); function_index++) {
        Function_Definition@ function_definition = source_functions[function_index];

        string name = get_function_name_for_list(function_definition);

        if (expression.type == EXPRESSION_CALL && expression.identifier_name == function_definition.function_name) {
            selected_action = function_index + functions_offset;
        }

        action_names.insertLast(name);
    }

    if (ImGui_Combo("##function_selector", selected_action, action_names)) {
        if (selected_action < int(special_actions.length())) {
            Expression_Type special_type = special_actions[selected_action].expression_type;
            expression.type = special_type;

            handle_expression_type_changed_to(special_type, expression);
        } else {
            expression.type = EXPRESSION_CALL;

            Function_Definition@ selected_definition = source_functions[selected_action - functions_offset];

            fill_function_call_expression_from_function_definition(expression, selected_definition);
        }
    }

    ImGui_NewLine();
    ImGui_Separator();
    ImGui_NewLine();

    ImGui_Text("Action text");
    draw_expression_as_broken_into_pieces(expression, frame);

    draw_editor_popup_footer(frame);
}

bool draw_variable_selector(Ui_Frame_State@ frame, Expression@ expression, Variable@& result_variable, Literal_Type limit_to = LITERAL_TYPE_VOID) {
    array<Variable@> scope_variables;

    collect_scope_variables(frame.top_scope, scope_variables, limit_to);

    array<string> variable_names;
    int selected_variable = 0;

    for (uint variable_index = 0; variable_index < scope_variables.length(); variable_index++) {
        string variable_name = scope_variables[variable_index].name;

        variable_names.insertLast(variable_name);

        if (variable_name == expression.identifier_name) {
            selected_variable = variable_index;

            @result_variable = scope_variables[variable_index];
        }
    }

    bool changed = ImGui_Combo(frame.unique_id("variable_selector"), selected_variable, variable_names);

    if (changed) {
        expression.identifier_name = variable_names[selected_variable];

        @result_variable = scope_variables[selected_variable];
    }

    return changed;
}

void draw_expression_editor_popup(Ui_Frame_State@ frame, bool draw_literal_editor, Literal_Type limit_to) {
    Expression@ expression = state.edited_expressions[frame.popup_stack_level - 1];

    const int offset = 200;

    if (ImGui_RadioButton("Variable", expression.type == EXPRESSION_IDENTIFIER)) {
        array<Variable@> scope_variables;
        collect_scope_variables(frame.top_scope, scope_variables, limit_to);

        if (scope_variables.length() > 0) {
            expression.type = EXPRESSION_IDENTIFIER;
            expression.identifier_name = scope_variables[0].name;
        }
    }

    ImGui_SameLine();
    ImGui_SetCursorPosX(offset);

    Variable@ selected_variable = null;
    
    if (draw_variable_selector(frame, expression, selected_variable, limit_to)) {
        expression.type = EXPRESSION_IDENTIFIER;
    }

    bool is_a_function_call = expression.type == EXPRESSION_CALL;
    bool is_an_operator = expression.type == EXPRESSION_OPERATOR;

    if (ImGui_RadioButton("Function", is_a_function_call || is_an_operator)) {
        expression.type = EXPRESSION_OPERATOR;

        // TODO this is not a good way to set a default value
        array<Operator_Group@>@ operator_groups = filter_operator_groups_by_return_type(limit_to);

        fill_operator_expression_from_operator_definition(expression, operator_groups[0].operators[0]);
    }

    ImGui_SameLine();
    ImGui_SetCursorPosX(offset);
    draw_editor_popup_function_selector(expression, frame, limit_to);

    if (is_a_function_call || is_an_operator) {
        ImGui_SetCursorPosX(offset);

        draw_expression_as_broken_into_pieces(expression, frame);
    } else {
        ImGui_NewLine();
    }

    if (draw_literal_editor) {
        if (ImGui_RadioButton("Value", expression.type == EXPRESSION_LITERAL)) {
            expression.type = EXPRESSION_LITERAL;
            expression.literal_type = limit_to;
        }

        ImGui_SameLine();
        ImGui_SetCursorPosX(offset);

        if (draw_editable_literal(expression.literal_type, expression.literal_value, frame.unique_id("editable_literal"))) {
            expression.type = EXPRESSION_LITERAL;
            expression.literal_type = limit_to;
        }
    }
    
    draw_editor_popup_footer(frame);
}

void draw_editable_expression(Expression@ expression, Ui_Frame_State@ frame, bool parent_is_a_code_block = false, Literal_Type limit_to = LITERAL_TYPE_VOID) {
    if (ImGui_Button(expression_to_string(expression) + frame.unique_id("editable_button"))) {
        open_expression_editor_popup(expression, frame);
    }

    bool is_open = true;

    ImGui_SetNextWindowPos(ImGui_GetWindowPos() + vec2(20, 20), ImGuiSetCond_Appearing);
    if (ImGui_BeginPopupModal("Edit###Popup" + frame.popup_stack_level + frame.line_counter + frame.argument_counter, is_open, ImGuiWindowFlags_AlwaysAutoResize)) {
        frame.popup_stack_level++;

        if (parent_is_a_code_block && !frame.drawing_conditions_block) {
            draw_statement_editor_popup(frame, limit_to);
        } else {
            bool hide_literal_editor = frame.drawing_conditions_block && parent_is_a_code_block;
            draw_expression_editor_popup(frame, !hide_literal_editor, limit_to);
        }

        ImGui_EndPopup();
    }

    if (!is_open) {
        pop_edited_expression(frame);
    }

    if (!parent_is_a_code_block) {
        frame.argument_counter++;
    }
}

bool draw_type_selector(Literal_Type& input_type, string text_label) {
    array<Literal_Type> all_types;

    all_types.reserve(LITERAL_TYPE_LAST - 1);

    // Skip VOID type
    for (Literal_Type type = Literal_Type(1); type < LITERAL_TYPE_LAST; type++) {
        all_types.insertLast(type);
    }

    array<string> type_names;
    int selected = -1;

    for (uint index = 0; index < all_types.length(); index++) {
        if (all_types[index] == input_type) {
            selected = index;
        }

        type_names.insertLast(colored_literal_type(all_types[index]));
    }

    bool changed = ImGui_Combo(text_label, selected, type_names);

    if (changed) {
        input_type = all_types[selected];
    }

    ImGui_SameLine();

    return changed;
}

void draw_function_call_as_broken_into_pieces_simple(Expression@ expression, Ui_Frame_State@ frame) {
    ImGui_Button(expression.identifier_name + frame.unique_id("function_name"));
    ImGui_SameLine();

    pre_expression_text("(");

    for (uint argument_index = 0; argument_index < expression.arguments.length(); argument_index++) {
        Expression@ argument = expression.arguments[argument_index];
        draw_expression_and_continue_on_the_same_line(argument, frame, limit_to: argument.literal_type);
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

        Literal_Type argument_type = function_definition.argument_types[argument_index];
        string argument_as_string = literal_type_to_ui_string(argument_type);
        bool argument_found = false;

        if (expression.arguments.length() > argument_index) {
            Expression@ argument_expression = expression.arguments[argument_index];
            argument_found = argument_expression !is null;

            if (argument_found) {
                draw_expression_and_continue_on_the_same_line(argument_expression, frame, limit_to: argument_type);
            }
        }

        if (!argument_found) {
            ImGui_Text(argument_as_string);
            ImGui_SameLine();
        }
    }

    ImGui_Text(pieces[pieces.length() - 1]);
}

void draw_operator_as_broken_into_pieces(Expression@ expression, Ui_Frame_State@ frame) {
    Operator_Definition@ fitting_operator = find_operator_definition_by_expression_in_context(expression, frame.top_scope);
    Operator_Group@ operator_group = fitting_operator.parent_group;

    array<string> operator_names;
    int selected_operator = 0;
    int max_text_width = 35;

    for (uint operator_index = 0; operator_index < operator_group.operators.length(); operator_index++) {
        Operator_Definition@ operator = operator_group.operators[operator_index];

        if (operator.operator_type == fitting_operator.operator_type) {
            selected_operator = operator_index;
        }

        string operator_name = operator_type_to_ui_string(operator.operator_type);

        operator_names.insertLast(colored_keyword(operator_name));

        int operator_name_width = int(ImGui_CalcTextSize(operator_name).x + 35);
        max_text_width = max(operator_name_width, max_text_width);
    }

    frame.argument_counter = 0;

    draw_expression_and_continue_on_the_same_line(expression.left_operand, frame, limit_to: fitting_operator.left_operand_type);

    ImGui_PushItemWidth(max_text_width);

    if (ImGui_Combo(frame.unique_id("operator_selector"), selected_operator, operator_names)) {
        expression.operator_type = operator_group.operators[selected_operator].operator_type;
    }

    ImGui_PopItemWidth();
    ImGui_SameLine();

    draw_editable_expression(expression.right_operand, frame, limit_to: fitting_operator.right_operand_type);
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
            draw_operator_as_broken_into_pieces(expression, frame);
            break;
        }

        case EXPRESSION_IF: {
            pre_expression_text("If");
            draw_editable_expression(expression.value_expression, frame, limit_to: LITERAL_TYPE_BOOL);

            break;
        }

        case EXPRESSION_WHILE: {
            pre_expression_text("While");
            draw_editable_expression(expression.value_expression, frame, limit_to: LITERAL_TYPE_BOOL);
            post_expression_text("is " + colored_literal("True"));

            break;
        }

        case EXPRESSION_REPEAT: {
            pre_expression_text("Repeat");
            draw_editable_expression(expression.value_expression, frame, limit_to: LITERAL_TYPE_NUMBER);
            post_expression_text("times");
            break;
        }

        case EXPRESSION_DECLARATION: {
            pre_expression_text(colored_keyword("Declare"));
            
            if (draw_type_selector(expression.literal_type, "")) {
                expression.value_expression = make_empty_lit(expression.literal_type);
            }

            ImGui_SetTextBuf(expression.identifier_name);
            
            if (ImGui_InputText(frame.unique_id("declare"))) {
                expression.identifier_name = ImGui_GetTextBuf();
            }

            ImGui_SameLine();

            pre_expression_text("=");
            draw_editable_expression(expression.value_expression, frame, limit_to: expression.literal_type);
            break;
        }

        case EXPRESSION_ASSIGNMENT: {
            pre_expression_text("set");
            
            Variable@ selected_variable = null;

            if (draw_variable_selector(frame, expression, selected_variable)) {
                @expression.value_expression = make_empty_lit(selected_variable.type);
            }

            ImGui_SameLine();
            pre_expression_text("=");

            Literal_Type limit_assignment_to = selected_variable !is null ? selected_variable.type : LITERAL_TYPE_VOID;
            draw_editable_expression(expression.value_expression, frame, limit_to: limit_assignment_to); 
            break;
        }

        case EXPRESSION_CALL: {
            draw_function_call_as_broken_into_pieces(expression, frame);

            break;
        }

        case EXPRESSION_FORK: break;

        default: {
            ImGui_Button("not_implemented##" + frame.unique_id("not_implemented"));
            break;
        }
    }
}

void draw_expressions(array<Expression@>@ expressions, Ui_Frame_State@ frame, Literal_Type limit_to = LITERAL_TYPE_VOID) {
    if (expressions.length() == 0) {
        if (ImGui_Button("+" + frame.unique_id("add"))) {
            Expression@ new_expression = make_function_call("do_nothing");
            expressions.insertLast(new_expression);

            frame.argument_counter = 0;

            open_expression_editor_popup(new_expression, frame);
            return;
        }
    }

    push_ui_variable_scope(frame);

    for (int index = 0; uint(index) < expressions.length(); index++) {
        frame.argument_counter = 0;

        Expression@ expression = expressions[uint(index)];

        bool is_in_editor_popup = state.edited_expressions.length() > 0;

        vec2 cursor_start_pos = ImGui_GetCursorScreenPos();

        draw_expression_image(expression);
        draw_editable_expression(expression, frame, true, limit_to: limit_to);

        if (expression.type == EXPRESSION_DECLARATION) {
            Variable@ variable = make_variable(expression.literal_type, expression.identifier_name);

            frame.top_scope.variables.insertLast(variable);
        }

        if (!is_in_editor_popup) {
            vec2 hover_min = cursor_start_pos;
            vec2 hover_max = cursor_start_pos + vec2(900, 18);

            if (ImGui_IsMouseHoveringRect(hover_min, hover_max)) {
                float x_position_snapped = int((ImGui_GetMousePos().x - ImGui_GetWindowPos().x) / 64) * 64;

                ImGui_SameLine();
                // ImGui_SetCursorPosX(x_position_snapped);
                
                if (ImGui_Button("+")) {
                    Expression@ new_expression = make_function_call("do_nothing");
                    expressions.insertAt(uint(index) + 1, new_expression);

                    open_expression_editor_popup(new_expression, frame);
                }

                ImGui_SameLine();

                if (ImGui_Button("X")) {
                    expressions.removeAt(index);

                    index--;
                }
            }
        }

        switch (expression.type) {
            case EXPRESSION_IF: {
                draw_expressions_in_a_tree_node("Then do", expression.block_body, frame);
                draw_expressions_in_a_tree_node("Else do", expression.else_block_body, frame);
                break;
            }

            case EXPRESSION_FORK:
            case EXPRESSION_WHILE:
            case EXPRESSION_REPEAT: {
                draw_expressions_in_a_tree_node("Actions", expression.block_body, frame);
                break;
            }
        }

        frame.line_counter++;
    }

    pop_ui_variable_scope(frame);
}

void draw_trigger_content(Trigger@ current_trigger) {
    ImGui_BeginGroup();

    ImGui_AlignFirstTextHeightToWidgets();
    ImGui_Text("Content");

    {
        ImGui_PushItemWidth(-1);
        ImGui_SetTextBuf(current_trigger.name);
        if (ImGui_InputText("##trigger_name")) {
            current_trigger.name = ImGui_GetTextBuf();
        }

        ImGui_PopItemWidth();
    }

    {
        ImGui_PushItemWidth(-1);
        ImGui_SetTextBuf(current_trigger.description);
        if (ImGui_InputTextMultiline("##trigger_description", vec2(0, 50))) {
            current_trigger.description = ImGui_GetTextBuf();
        }

        ImGui_PopItemWidth();
    }

    vec2 size = ImGui_GetWindowSize() - ImGui_GetCursorPos() - vec2(8, 8);

    ImGui_ListBoxHeader("##main_list", size);

    Ui_Frame_State frame;

    Variable_Scope global_scope;
    @global_scope.variables = state.global_variables;
    @frame.top_scope = global_scope;

    if (ImGui_TreeNodeEx("Event##event_block", ImGuiTreeNodeFlags_OpenOnDoubleClick | ImGuiTreeNodeFlags_DefaultOpen)) {
        int selected_event = 0;
        array<string> event_names;

        for (uint event_index = 0; event_index < EVENT_LAST; event_index++) {
            event_names.insertLast(state.native_events[event_index].pretty_name);

            if (current_trigger.event_type == Event_Type(event_index)) {
                selected_event = event_index;
            }
        }

        ImGui_Image(icons::event, size: vec2(16, 16));
        ImGui_SameLine();
        if (ImGui_Combo("##function_selector", selected_event, event_names)) {
            current_trigger.event_type = Event_Type(selected_event);
        }

        ImGui_TreePop();
    }

    push_ui_variable_scope(frame);

    Event_Definition@ trigger_event = state.native_events[current_trigger.event_type];

    for (uint variable_index = 0; variable_index < trigger_event.variable_types.length(); variable_index++) {
        Variable@ variable = make_variable(trigger_event.variable_types[variable_index], trigger_event.variable_names[variable_index]);

        frame.top_scope.variables.insertLast(variable);
    }

    ImGui_PushStyleColor(ImGuiCol_Button, vec4(0.35f, 0.60f, 0.61f, 0.22f)); // TODO we should just make our own routine for drawing expression buttons

    frame.drawing_conditions_block = true;
    draw_expressions_in_a_tree_node("Conditions", current_trigger.conditions, frame, limit_to: LITERAL_TYPE_BOOL);

    frame.drawing_conditions_block = false;
    draw_expressions_in_a_tree_node("Actions", current_trigger.actions, frame);

    ImGui_PopStyleColor();

    pop_ui_variable_scope(frame);

    ImGui_ListBoxFooter();

    ImGui_EndGroup();
}

void draw_globals_modal() {
    float window_width = ImGui_GetWindowWidth();

    ImGui_PushItemWidth(int(window_width) - 16);

    ImGui_ListBoxHeader("###global_list", 16, 8);

    float right_padding = 100;
    float st = ImGui_GetCursorPosX();
    float free_width = window_width - st - right_padding;

    for (uint variable_index = 0; variable_index < state.global_variables.length(); variable_index++) {
        Variable@ variable = state.global_variables[variable_index];

        ImGui_AlignFirstTextHeightToWidgets();
        ImGui_Image(icons::action_variable, vec2(16, 16));
        ImGui_SameLine();

        ImGui_PushItemWidth(int(free_width * 0.3));

        ImGui_SetTextBuf(variable.name);
        if (ImGui_InputText("###variable_name" + variable_index)) {
            variable.name = ImGui_GetTextBuf();
        }

        ImGui_PopItemWidth();
        ImGui_SameLine();

        {
            ImGui_PushItemWidth(int(free_width * 0.2));
            
            draw_type_selector(variable.type, "###type_selector" + variable_index);

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
            ImGui_PushItemWidth(int(free_width * 0.35));
            draw_editable_literal(variable.type, variable.value, "###" + variable_index);
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

    if (icon_button("New variable", "variable_add", icons::action_variable)) {
        state.global_variables.insertLast(make_variable(LITERAL_TYPE_NUMBER, "New variable"));
    }
}

void set_camera_to_view(Object@ camera_hotspot) {
    camera_hotspot.SetTranslation(camera.GetPos());

    float deg_to_rad = 3.14f / 180.0f;

    mat4 rotation_matrix_x;
    rotation_matrix_x.SetRotationX(camera.GetXRotation() * deg_to_rad);

    mat4 rotation_matrix_y;
    rotation_matrix_y.SetRotationY(camera.GetYRotation() * deg_to_rad);

    quaternion rotation = QuaternionFromMat4(rotation_matrix_y * rotation_matrix_x);

    camera_hotspot.SetRotation(rotation);
}

array<Object@>@ list_camera_objects() {
    array<Object@> result;

    int amount_of_hotspots = GetNumHotspots();

    for (int hotspot_index = 0; hotspot_index < amount_of_hotspots; hotspot_index++) {
        Hotspot@ hotspot = ReadHotspot(hotspot_index);

        if (hotspot.GetTypeString() == HOTSPOT_CAMERA_TYPE) {
            result.insertLast(ReadObjectFromID(hotspot.GetID()));
        }
    }

    return result;
}

void draw_cameras_window() {
    float window_width = ImGui_GetWindowWidth();
    ImGui_PushItemWidth(int(window_width) - 16);

    ImGui_ListBoxHeader("###cameras_list", 16, 16);

    Object@ selected_hotspot_as_object = null;

    array<Object@>@ camera_objects = list_camera_objects();

    for (uint camera_index = 0; camera_index < camera_objects.length(); camera_index++) {
        Object@ camera_object = camera_objects[camera_index];

        ImGui_AlignFirstTextHeightToWidgets();
        ImGui_Image(icons::action_camera, vec2(16, 16));
        ImGui_SameLine();

        bool is_selected = camera_object.IsSelected();

        if (ImGui_Selectable(camera_id_to_camera_name(camera_object.GetID()), is_selected)) {
            camera_object.SetSelected(!is_selected);
        }

        if (is_selected) {
            @selected_hotspot_as_object = camera_object;
        }
    }

    ImGui_ListBoxFooter();
    ImGui_PopItemWidth();

    if (icon_button("New camera", "camera_add", icons::action_camera)) {
        int camera_id = CreateObject("Data/Objects/triggerkit/trigger_camera.xml", false);

        if (camera_id == -1) {
            Log(error, "Fatal error: was not able to create camera object");
            return;
        }

        Object@ camera_as_object = ReadObjectFromID(camera_id);
        camera_as_object.SetName("New camera");
        camera_as_object.SetSelectable(true);
        camera_as_object.SetSelected(true);

        set_camera_to_view(camera_as_object);
    }

    if (selected_hotspot_as_object !is null) {
        if (icon_button("Selected camera to view", "set_camera_to_view", icons::action_camera)) {
            set_camera_to_view(selected_hotspot_as_object);
        }

        if (icon_button("View to selected camera", "set_view_to_camera", icons::action_camera)) {
            // TODO doesn't work!
            const int entity_type_camera = 2;

            array<int>@ object_ids = GetObjectIDsType(entity_type_camera);

            for (uint id_index = 0; id_index < object_ids.length(); id_index++) {
                Object@ camera_object = ReadObjectFromID(object_ids[id_index]);

                // camera_object.SetTranslation(selected_hotspot_as_object.GetTranslation());
            }
            
            // camera.SetPos(selected_hotspot_as_object.GetTranslation());
        }

        if (icon_button("Delete selected camera", "delete_camera", icons::action_camera)) {
            QueueDeleteObjectID(selected_hotspot_as_object.GetID());
        }
    }
}