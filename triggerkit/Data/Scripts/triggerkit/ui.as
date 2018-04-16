#include "triggerkit/ui_modals.as"
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
    // Stack
    array<Expression@> edited_expressions;
    array<Function_Category> selected_categories;

    // Just arrays, nothing to see there
    array<Function_Definition@> function_definitions;
    array<Event_Definition@> native_events;
    array<Operator_Group@> operator_groups;

    int selected_action_category = 0;
    int selected_trigger;

    array<Trigger@> triggers;
    array<Variable> global_variables;

    bool is_cameras_window_open = false;
    bool is_poses_window_open = true;
    bool is_regions_window_open = false;
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

void draw_modals_if_necessary() {
    if (state.is_regions_window_open) {
        ImGui_SetNextWindowSize(vec2(300, 600), ImGuiSetCond_Appearing);
        if (ImGui_Begin("Regions###regions_window", state.is_regions_window_open)) {
            draw_regions_window();

            ImGui_End();
        }
    }

    if (state.is_cameras_window_open) {
        ImGui_SetNextWindowSize(vec2(300, 600), ImGuiSetCond_Appearing);
        if (ImGui_Begin("Cameras###camers_window", state.is_cameras_window_open)) {
            draw_cameras_window();

            ImGui_End();
        }
    }

    if (state.is_poses_window_open) {
        ImGui_SetNextWindowSize(vec2(300, 600), ImGuiSetCond_Appearing);
        if (ImGui_Begin("Poses###poses_window", state.is_poses_window_open)) {
            draw_poses_window();

            ImGui_End();
        }
    }
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

    if (icon_button("Regions", "open_regions", icons::action_region)) {
        state.is_regions_window_open = !state.is_regions_window_open;
    }

    ImGui_SameLine();

    if (icon_button("Cameras", "open_cameras", icons::action_camera)) {
        state.is_cameras_window_open = !state.is_cameras_window_open;
    }

    ImGui_SameLine();

    if (icon_button("Poses", "open_poses", icons::action_pose)) {
        state.is_poses_window_open = !state.is_poses_window_open;
    }

    ImGui_SameLine();

    if (icon_button("Save", "save_state", icons::action_other)) {
        save_trigger_state_into_level_params(state);
        initialize_state_and_vm();
        compile_everything();
    }

    ImGui_SameLine();
    ImGui_Text("Errors: " + num_compilation_errors);

    ImGui_EndGroup();
}

void draw_trigger_list() {
    ImGui_BeginGroup();
    ImGui_AlignFirstTextHeightToWidgets();
    ImGui_Text("Triggers");

    ImGui_ListBoxHeader("##trigger_list", vec2(200, ImGui_GetWindowHeight() - ImGui_GetCursorPosY() - 8));

    for (uint trigger_index = 0; trigger_index < state.triggers.length(); trigger_index++) {
        string trigger_name_and_id = state.triggers[trigger_index].name + "##list_trigger" + trigger_index;
        bool is_selected = int(trigger_index) == state.selected_trigger;

        if (ImGui_Selectable(trigger_name_and_id, is_selected)) {
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

    draw_modals_if_necessary();

    if (!ImGui_Begin("TriggerKit", ImGuiWindowFlags_MenuBar | ImGuiWindowFlags_ResizeFromAnySide)) {
        ImGui_End();
        return;
    }

    float window_width = ImGui_Getwindow_width();
    float window_height = ImGui_GetWindowHeight();

    if (window_height < 20) {
        return;
    }

    if (window_width < 500) {
        window_width = 500;
        ImGui_SetWindowSize(vec2(window_width, window_height), ImGuiSetCond_Always);
    }

    if (window_height < 300) {
        window_height = 300;
        ImGui_SetWindowSize(vec2(window_width, window_height), ImGuiSetCond_Always);
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
    state.selected_categories.removeLast();
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

    Operator_Definition@ current_fitting_operator = find_operator_definition_by_expression_in_context(expression, frame.top_scope);
    Function_Definition@ current_function_definition = find_function_definition_by_function_name(expression.identifier_name);

    string preview_text;

    if (current_fitting_operator !is null) {
        preview_text = current_fitting_operator.parent_group.name;
    } else if (current_function_definition !is null) {
        preview_text = get_function_name_for_list(current_function_definition);
    }

    if (ImGui_BeginCombo(frame.unique_id("function_selector"), preview_text)) {
        for (uint group_index = 0; group_index < operator_groups.length(); group_index++) {
            Operator_Group@ group = operator_groups[group_index];

            bool is_selected = current_fitting_operator !is null && group is current_fitting_operator.parent_group;

            if (ImGui_Selectable(group.name, is_selected)) {
                fill_operator_expression_from_operator_definition(expression, group.operators[0], frame.top_scope);
            }
        }

        for (uint function_index = 0; function_index < source_functions.length(); function_index++) {
            Function_Definition@ function_definition = source_functions[function_index];

            bool is_selected = expression.identifier_name == function_definition.function_name;

            if (ImGui_Selectable(get_function_name_for_list(function_definition), is_selected)) {
                fill_function_call_expression_from_function_definition(expression, function_definition, frame.top_scope);
            }
        }

        ImGui_EndCombo();
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

void draw_statement_editor_popup(Ui_Frame_State@ frame) {
    Expression@ expression = state.edited_expressions[frame.popup_stack_level - 1];
    Function_Category selected_category = state.selected_categories[frame.popup_stack_level - 1];

    ImGui_Text("Action category");

    ImGui_PushItemWidth(300);

    if (ImGui_BeginCombo(frame.unique_id("category_selector"), function_category_to_string(selected_category))) {
        for (Function_Category category = Function_Category(0); category < CATEGORY_LAST; category++) {
            if (ImGui_Selectable(function_category_to_string(category), category == selected_category)) {
                state.selected_categories[frame.popup_stack_level - 1] = category;
                selected_category = category; // We can't use a reference?

                if (category != CATEGORY_NONE) {
                    Function_Definition@ first_function_in_category = filter_function_definitions_for_statement_popup(category)[0];
                    Function_Definition@ current_function_definition = find_function_definition_by_function_name(expression.identifier_name);

                    if (current_function_definition is null || first_function_in_category.function_category != current_function_definition.function_category) {
                        expression.identifier_name = first_function_in_category.function_name;
                    }
                }
            }
        }

        ImGui_EndCombo();
    }

    ImGui_PopItemWidth();

    array<Function_Definition@>@ source_functions = filter_function_definitions_for_statement_popup(selected_category);

    const array<Ui_Special_Action> special_actions = {
        Ui_Special_Action("Declare Variable", EXPRESSION_DECLARATION),
        Ui_Special_Action("Assign Variable", EXPRESSION_ASSIGNMENT),
        Ui_Special_Action("If/Then/Else", EXPRESSION_IF),
        Ui_Special_Action("While/Do", EXPRESSION_WHILE),
        Ui_Special_Action("Run in Parallel", EXPRESSION_FORK)
    };

    string function_preview_text;

    if (expression.type == EXPRESSION_CALL) {
        Function_Definition@ function_definition = find_function_definition_by_function_name(expression.identifier_name);

        if (function_definition is null) {
            function_preview_text = expression.identifier_name;
        } else {
            function_preview_text = get_function_name_for_list(function_definition);
        }
    } else {
        for (uint action_index = 0; action_index < special_actions.length(); action_index++) {
            if (special_actions[action_index].expression_type == expression.type) {
                function_preview_text = special_actions[action_index].action_name;
            }
        }
    }

    ImGui_Text("Action type");

    ImGui_PushItemWidth(300);
    if (ImGui_BeginCombo(frame.unique_id("function_selector"), function_preview_text)) {
        if (selected_category == CATEGORY_NONE) {
            for (uint action_index = 0; action_index < special_actions.length(); action_index++) {
                const Ui_Special_Action@ action = special_actions[action_index];
                bool is_selected = action.expression_type == expression.type;

                if (ImGui_Selectable(action.action_name, is_selected)) {
                    expression.type = action.expression_type;

                    handle_expression_type_changed_to(action.expression_type, expression);
                }
            }
        }

        for (uint function_index = 0; function_index < source_functions.length(); function_index++) {
            Function_Definition@ function_definition = source_functions[function_index];
            bool is_selected = expression.type == EXPRESSION_CALL && expression.identifier_name == function_definition.function_name;
            string name = get_function_name_for_list(function_definition);

            if (selected_category == CATEGORY_NONE) {
                name = function_category_to_string(function_definition.function_category) + " - " + name;
            }

            if (ImGui_Selectable(name, is_selected)) {
                fill_function_call_expression_from_function_definition(expression, function_definition, frame.top_scope);
            }
        }

        ImGui_EndCombo();
    }

    ImGui_PopItemWidth();

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

    for (uint variable_index = 0; variable_index < scope_variables.length(); variable_index++) {
        if (scope_variables[variable_index].name == expression.identifier_name) {
            @result_variable = scope_variables[variable_index];
            break;
        }
    }

    bool user_selected_an_element = false;

    string initially_selected_variable_name = expression.identifier_name;
    string preview_text = expression.type == EXPRESSION_IDENTIFIER ? expression.identifier_name : "";

    if (result_variable is null) {
        preview_text = "[" + not_found + "]";
    }

    if (ImGui_BeginCombo(frame.unique_id("variable_selector"), preview_text)) {
        for (uint variable_index = 0; variable_index < scope_variables.length(); variable_index++) {
            string variable_name = scope_variables[variable_index].name;
            bool is_selected = expression.type == EXPRESSION_IDENTIFIER && initially_selected_variable_name == expression.identifier_name;

            if (ImGui_Selectable(variable_name, is_selected)) {
                expression.identifier_name = variable_name;

                @result_variable = scope_variables[variable_index];

                user_selected_an_element = true;
            }
        }

        ImGui_EndCombo();
    }

    return user_selected_an_element;
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
    
    ImGui_PushItemWidth(300);

    if (draw_variable_selector(frame, expression, selected_variable, limit_to)) {
        expression.type = EXPRESSION_IDENTIFIER;
    }

    ImGui_PopItemWidth();

    bool is_a_function_call = expression.type == EXPRESSION_CALL;
    bool is_an_operator = expression.type == EXPRESSION_OPERATOR;

    if (ImGui_RadioButton("Function", is_a_function_call || is_an_operator)) {
        // TODO this is not a good way to set a default value
        array<Operator_Group@>@ operator_groups = filter_operator_groups_by_return_type(limit_to);

        fill_operator_expression_from_operator_definition(expression, operator_groups[0].operators[0], frame.top_scope);
    }

    ImGui_SameLine();
    ImGui_SetCursorPosX(offset);
    ImGui_PushItemWidth(300);

    draw_editor_popup_function_selector(expression, frame, limit_to);

    ImGui_PopItemWidth();

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

        Literal_Type literal_type = limit_to != LITERAL_TYPE_VOID ? limit_to : expression.literal_type;

        if (draw_editable_literal(literal_type, expression.literal_value, frame.unique_id("editable_literal"))) {
            expression.type = EXPRESSION_LITERAL;
            expression.literal_type = limit_to;
        }
    }
    
    draw_editor_popup_footer(frame);
}

void draw_editable_expression(Expression@ expression, Ui_Frame_State@ frame, bool parent_is_a_code_block = false, Literal_Type limit_to = LITERAL_TYPE_VOID) {
    if (ImGui_Button(expression_to_string(expression, frame.top_scope) + frame.unique_id("editable_button"))) {
        open_expression_editor_popup(expression, frame);
    }

    bool is_open = true;

    ImGui_SetNextWindowPos(ImGui_GetWindowPos() + vec2(20, 20), ImGuiSetCond_Once);

    ImGui_PushStyleVar(ImGuiStyleVar_WindowPadding, vec2(15));

    if (ImGui_BeginPopupModal("Edit###Popup" + frame.popup_stack_level + frame.line_counter + frame.argument_counter, is_open, ImGuiWindowFlags_AlwaysAutoResize)) {
        frame.popup_stack_level++;

        // I'm not sure if there is a way to get the default stylevar value
        ImGui_PushStyleVar(ImGuiStyleVar_WindowPadding, vec2(4));

        if (parent_is_a_code_block && !frame.drawing_conditions_block) {
            draw_statement_editor_popup(frame);
        } else {
            bool hide_literal_editor = frame.drawing_conditions_block && parent_is_a_code_block;
            draw_expression_editor_popup(frame, !hide_literal_editor, limit_to);
        }

        ImGui_PopStyleVar();

        ImGui_EndPopup();
    }

    ImGui_PopStyleVar();

    if (!is_open) {
        pop_edited_expression(frame);
    }

    if (!parent_is_a_code_block) {
        frame.argument_counter++;
    }
}

bool draw_type_selector(Literal_Type& input_type, string text_label) {
    bool changed = false;

    if (ImGui_BeginCombo(text_label, colored_literal_type(input_type))) {
        // Skip VOID type
        for (Literal_Type type = Literal_Type(1); type < LITERAL_TYPE_LAST; type++) {
            string colored_type_name = colored_literal_type(type);

            if (ImGui_Selectable(colored_type_name, type == input_type)) {
                input_type = type;
                changed = true;
            }
        }

        ImGui_EndCombo();
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

    if (fitting_operator is null) {
        ImGui_Text(expression_to_string(expression.left_operand, frame.top_scope));
        ImGui_SameLine();

        ImGui_Text(operator_type_to_ui_string(expression.operator_type));
        ImGui_SameLine();

        ImGui_Text(expression_to_string(expression.right_operand, frame.top_scope));

        return;
    }

    Operator_Group@ operator_group = fitting_operator.parent_group;

    int max_text_width = 35;

    for (uint operator_index = 0; operator_index < operator_group.operators.length(); operator_index++) {
        Operator_Definition@ operator = operator_group.operators[operator_index];
        string operator_name = operator_type_to_ui_string(operator.operator_type);
        int operator_name_width = int(ImGui_CalcTextSize(operator_name).x + 35);
        max_text_width = max(operator_name_width, max_text_width);
    }

    frame.argument_counter = 0;

    draw_expression_and_continue_on_the_same_line(expression.left_operand, frame, limit_to: fitting_operator.left_operand_type);

    ImGui_PushItemWidth(max_text_width);

    if (ImGui_BeginCombo(frame.unique_id("operator_selector"), operator_type_to_ui_string(fitting_operator.operator_type))) {
        for (uint operator_index = 0; operator_index < operator_group.operators.length(); operator_index++) {
            Operator_Definition@ operator = operator_group.operators[operator_index];

            string operator_name = operator_type_to_ui_string(operator.operator_type);

            if (ImGui_Selectable(operator_name, operator.operator_type == fitting_operator.operator_type)) {
                expression.operator_type = operator.operator_type;
            }
        }

        ImGui_EndCombo();
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
            bool found = false;
            find_scope_variable_by_name(expression.identifier_name, frame.top_scope, found);

            if (found) {
                ImGui_Button(expression.identifier_name + frame.unique_id("identifier"));
            } else {
                ImGui_Button(not_found + frame.unique_id("identifier"));
            }
            
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
            
            float combo_width = ImGui_CalcTextSize(literal_type_to_ui_string(expression.literal_type)).x;
            ImGui_PushItemWidth(int(combo_width) + 30);
            
            if (draw_type_selector(expression.literal_type, "")) {
                expression.value_expression = make_empty_lit(expression.literal_type);
            }

            ImGui_PopItemWidth();

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
        ImGui_Image(icons::event, size: vec2(16, 16));
        ImGui_SameLine();

        if (ImGui_BeginCombo("##function_selector", state.native_events[current_trigger.event_type].pretty_name)) {
            for (Event_Type type = Event_Type(0); type < EVENT_LAST; type++) {
                if (ImGui_Selectable(state.native_events[type].pretty_name, current_trigger.event_type == type)) {
                    current_trigger.event_type = type;
                }
            }

            ImGui_EndCombo();
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