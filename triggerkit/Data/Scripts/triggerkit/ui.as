funcdef bool Function_Predicate(Function_Definition@ f);

namespace icons {
    TextureAssetRef action_variable = LoadTexture("Data/Images/triggerkit/ui/icons/Actions-SetVariables.png", TextureLoadFlags_NoMipmap);
    TextureAssetRef action_logical = LoadTexture("Data/Images/triggerkit/ui/icons/Actions-Logical.png", TextureLoadFlags_NoMipmap);
    TextureAssetRef action_other = LoadTexture("Data/Images/triggerkit/ui/icons/Actions-Nothing.png", TextureLoadFlags_NoMipmap);
    TextureAssetRef action_wait = LoadTexture("Data/Images/triggerkit/ui/icons/Actions-Wait.png", TextureLoadFlags_NoMipmap);
    TextureAssetRef action_dialogue = LoadTexture("Data/Images/triggerkit/ui/icons/Actions-Quest.png", TextureLoadFlags_NoMipmap);
}

class Trigger {
    string name;
    string description;
    array<Expression@> conditions;
    array<Expression@> actions;
    Event_Type event_type = EVENT_CHARACTER_ENTERS_REGION;

    Trigger(string name) {
        this.name = name;
    }
}

class Trigger_Kit_State {
    array<Expression@> edited_expressions;
    array<Function_Definition@> native_functions;
    array<Event_Definition@> native_events;

    int current_stack_depth = 0;
    int selected_action_category = 0;
    int selected_trigger;

    array<Trigger@> triggers;
}

// TODO unused
Trigger@ get_current_selected_trigger() {
    if (uint(state.selected_trigger) >= state.triggers.length()) {
        return null;
    }

    return state.triggers[uint(state.selected_trigger)];
}

array<Function_Definition@> filter_native_functions_by_predicate(Function_Predicate@ predicate) {
    array<Function_Definition@> filter_result;

    for (uint index = 0; index < state.native_functions.length(); index++) {
        Function_Definition@ function_description = state.native_functions[index];

        if (predicate(function_description)) {
            filter_result.insertLast(function_description);
        }
    }

    return filter_result;
}

Trigger_Kit_State@ make_trigger_kit_state() {
    Trigger_Kit_State state;

    Api_Builder@ api_builder = build_api();
    state.native_functions = api_builder.functions;
    state.native_events = api_builder.events;

    return state;
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

        //state.Persist();
    }

    ImGui_SameLine();

    if (ImGui_Button("Rem##FFFF00FFove")) {
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

    if (ImGui_Button("VM Reload")) {
        @vm = make_vm();
        @state = load_trigger_state_from_level_params();
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
        draw_expressions(expressions, expression_index, popup_stack_level);
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

const string default_color = "\x1BFFFFFFFF";
const string keyword_color = "\x1BFFD800FF";
const string type_color = "\x1BB6FF00FF";
const string literal_color = "\x1BFF7FEDFF";
const string string_color = "\x1BFFB27FFF";
const string identifier_color = "\x1BC0C0C0FF";

string colored_keyword(const string keyword) {
    return keyword_color + keyword + default_color;
}

string colored_literal_type(Literal_Type literal_type) {
    return type_color + literal_type_to_ui_string(literal_type) + default_color;
}

string colored_identifier(string identifier_name) {
    return identifier_color + identifier_name + default_color;
}

string literal_to_ui_string(Expression@ literal) {
    switch (literal.literal_type) {

        case LITERAL_TYPE_NUMBER: return literal_color + literal.literal_value.number_value + default_color;
        case LITERAL_TYPE_STRING: return string_color + "\"" + literal.literal_value.string_value + "\"" + default_color;

        default: {
            Log(error, "Unsupported literal type " + literal_type_to_ui_string(literal.literal_type));
        }
    }

    return "not_implemented";
}

string function_call_to_string_simple(Expression@ expression) {
    array<string> arguments;
    arguments.resize(expression.arguments.length());

    for (uint argument_index = 0; argument_index < expression.arguments.length(); argument_index++) {
        arguments[argument_index] = expression_to_string(expression.arguments[argument_index]);
    }

    return expression.identifier_name + "(" + join(arguments, ", ") + ")";
}

string native_call_to_string(Expression@ expression) {
    Function_Definition@ function_description;

    for (uint function_index = 0; function_index < state.native_functions.length(); function_index++) {
        if (state.native_functions[function_index].function_name == expression.identifier_name) {
            @function_description = state.native_functions[function_index];
            break;
        }
    }

    if (function_description is null) {
        return function_call_to_string_simple(expression);
    }

    int character_index = 0;
    int current_argument_index = 0;

    string result = "";
    string format = function_description.format;

    while (true) {
        int new_character_index = format.findFirst("%s", character_index);

        if (new_character_index != -1) {
            string argument_as_string = expression_to_string(expression.arguments[current_argument_index]);

            if (expression.arguments[current_argument_index].type != EXPRESSION_LITERAL) {
                argument_as_string = "(" + argument_as_string + ")";
            }

            result += format.substr(character_index, new_character_index - character_index) + argument_as_string;
            current_argument_index++;
        } else {
            if (character_index == 0) {
                result = format;
            } else {
                result += format.substr(character_index);
            }

            break;
        }

        character_index = new_character_index + 2;
    }

    return result;
    //return expression.identifier_name + "(" + join(arguments, ", ") + ")";
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
                colored_literal_type(expression.literal_type),
                colored_identifier(expression.identifier_name),
                "=",
                expression_to_string(expression.value_expression)
            }, " ");
        }
            
        case EXPRESSION_ASSIGNMENT:
            return join(array<string> = {
                colored_keyword("Set"),
                colored_identifier(expression.identifier_name),
                "=",
                expression_to_string(expression.value_expression)
            }, " ");
        case EXPRESSION_IDENTIFIER: return colored_identifier(expression.identifier_name);
        case EXPRESSION_LITERAL: return literal_to_ui_string(expression);
        case EXPRESSION_CALL: return native_call_to_string(expression);
        case EXPRESSION_REPEAT: {
            return join(array<string> = {
                colored_keyword("Repeat"),
                expression_to_string(expression.value_expression),
                "times"
            }, " ");
        }

        case EXPRESSION_WHILE: {
            return join(array<string> = {
                colored_keyword("While"),
                expression_to_string(expression.value_expression),
                "is " + literal_color + "true" + default_color + ", do"
            }, " ");
        }

        case EXPRESSION_IF: return colored_keyword("If ") + expression_to_string(expression.value_expression);
    }

    return "not_implemented (" + expression.type + ")";
}

void draw_editor_popup_footer(uint& popup_stack_level) {
    ImGui_NewLine();
    ImGui_Separator();
    ImGui_NewLine();

    if (ImGui_Button("close###" + popup_stack_level)) {
        state.edited_expressions.removeLast();
        ImGui_CloseCurrentPopup();
        popup_stack_level--;
    }
}

void draw_editor_popup_function_selector() {
    int selected_function = 0;
    array<string> function_names;

    for (uint function_index = 0; function_index < state.native_functions.length(); function_index++) {
        function_names.insertLast(state.native_functions[function_index].pretty_name);
    }

    ImGui_Combo("##function_selector", selected_function, function_names);
}

void draw_statement_editor_popup(uint& expression_index, uint& popup_stack_level) {
    ImGui_Text("Action type");

    draw_editor_popup_function_selector();

    ImGui_NewLine();
    ImGui_Separator();
    ImGui_NewLine();

    ImGui_Text("Action text");
    draw_expression_as_broken_into_pieces(state.edited_expressions[popup_stack_level - 1], expression_index, popup_stack_level);

    draw_editor_popup_footer(popup_stack_level);

    ImGui_EndPopup();
}

void draw_expression_editor_popup(uint& expression_index, uint& popup_stack_level) {
    array<string> variable_names = { "var1" };
    int selected = 0;

    const int offset = 200;

    Expression@ expression = state.edited_expressions[popup_stack_level - 1];

    if (ImGui_RadioButton("Variable", expression.type == EXPRESSION_IDENTIFIER)) {
        expression.type = EXPRESSION_IDENTIFIER;
    }

    ImGui_SameLine();
    ImGui_SetCursorPosX(offset);
    ImGui_Combo("##variable_selector", selected, variable_names);

    bool is_a_function_call = expression.type == EXPRESSION_CALL;
    bool is_an_operator = expression.type == EXPRESSION_OPERATOR;

    if (ImGui_RadioButton("Function", is_a_function_call || is_an_operator)) {

    }

    ImGui_SameLine();
    ImGui_SetCursorPosX(offset);
    draw_editor_popup_function_selector();

    if (is_a_function_call || is_an_operator) {
        ImGui_SetCursorPosX(offset);
        draw_expression_as_broken_into_pieces(expression, expression_index, popup_stack_level);
    }

    if (ImGui_RadioButton("Value", expression.type == EXPRESSION_LITERAL)) {
        expression.type = EXPRESSION_LITERAL;
    }

    ImGui_SameLine();
    ImGui_SetCursorPosX(offset);

    draw_editable_literal(state.edited_expressions[popup_stack_level - 1], expression_index);
    
    draw_editor_popup_footer(popup_stack_level);

    ImGui_EndPopup();
}

void draw_editable_expression(Expression@ expression, uint& expression_index, uint& popup_stack_level, bool parent_is_a_code_block = false) {
    if (ImGui_Button(expression_to_string(expression) + "##" + expression_index)) {
        ImGui_OpenPopup("Edit###Popup" + popup_stack_level);
        state.edited_expressions.insertLast(expression);
    }

    ImGui_SetNextWindowPos(ImGui_GetWindowPos() + vec2(20, 20), ImGuiSetCond_Appearing);
    if (ImGui_BeginPopupModal("Edit###Popup" + popup_stack_level, ImGuiWindowFlags_AlwaysAutoResize)) {
        popup_stack_level++;

        if (parent_is_a_code_block) {
            draw_statement_editor_popup(expression_index, popup_stack_level);
        } else {
            draw_expression_editor_popup(expression_index, popup_stack_level);
        }
    }
}

void draw_editable_literal(Expression@ expression, int index) {
    Memory_Cell@ literal_value = expression.literal_value;

    switch (expression.literal_type) {
        case LITERAL_TYPE_NUMBER:
            ImGui_InputFloat("###LiteralFloat" + index, literal_value.number_value, 1);
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

        type_names.insertLast(colored_literal_type(all_types[index]));
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
            //ImGui_Button(literal_to_ui_string(expression));
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
            pre_expression_text(colored_keyword("Declare"));
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

        case EXPRESSION_CALL: {
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

// TODO speed! Could be array indexed
// We could also just store Function_Definition references in expressions
TextureAssetRef get_call_icon(Expression@ expression) {
    for (uint function_index = 0; function_index < state.native_functions.length(); function_index++) {
        Function_Definition@ function_definition = state.native_functions[function_index];
        if (function_definition.function_name == expression.identifier_name) {
            
            switch (function_definition.function_category) {
                case CATEGORY_WAIT: return icons::action_wait;
                case CATEGORY_DIALOGUE: return icons::action_dialogue;

                default: return icons::action_other;
            }

            break;
        }
    }

    return icons::action_other;
}

void draw_expression_image(Expression@ expression) {
    ImGui_SetCursorPosY(ImGui_GetCursorPosY() + 1);

    switch (expression.type) {
        case EXPRESSION_IF:
        case EXPRESSION_WHILE:
        case EXPRESSION_REPEAT: {
            ImGui_Image(icons::action_logical, vec2(16, 16));
            break;
        }

        case EXPRESSION_CALL: {
            ImGui_Image(get_call_icon(expression), vec2(16, 16));

            break;
        }

        default: {
            ImGui_Image(icons::action_variable, vec2(16, 16));
        }
    }

    ImGui_SameLine();

    ImGui_SetCursorPosY(ImGui_GetCursorPosY() - 1);
}

void draw_expressions(array<Expression@>@ expressions, uint& expression_index, uint& popup_stack_level) {
    if (expressions.length() == 0) {
        if (ImGui_Button("+##bluz")) {
            expressions.insertLast(make_native_call_expr("dingo"));
            return;
        }
    }

    for (int index = 0; uint(index) < expressions.length(); index++) {
        Expression@ expression = expressions[uint(index)];

        vec2 cursor_start_pos = ImGui_GetCursorScreenPos() ;

        draw_expression_image(expression);
        draw_editable_expression(expression, expression_index, popup_stack_level, true);

        vec2 hover_min = cursor_start_pos;
        vec2 hover_max = cursor_start_pos + vec2(400, 18);

        if (ImGui_IsMouseHoveringRect(hover_min, hover_max)) {
            float x_position_snapped = int((ImGui_GetMousePos().x - ImGui_GetWindowPos().x) / 64) * 64;

            ImGui_SameLine();
            // ImGui_SetCursorPosX(x_position_snapped);
            
            if (ImGui_Button("+")) {
                expressions.insertAt(uint(index) + 1, make_native_call_expr("dingo"));
            }

            ImGui_SameLine();

            if (ImGui_Button("X")) {
                expressions.removeAt(index);

                index--;
            }
        }

        switch (expression.type) {
            case EXPRESSION_IF: {
                draw_expressions_in_a_tree_node("Then do", expression.block_body, expression_index, popup_stack_level);
                draw_expressions_in_a_tree_node("Else do", expression.else_block_body, expression_index, popup_stack_level);
                break;
            }

            case EXPRESSION_WHILE:
            case EXPRESSION_REPEAT: {
                draw_expressions_in_a_tree_node("Actions", expression.block_body, expression_index, popup_stack_level);
                break;
            }
        }

        expression_index++;
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

    uint expression_index = 0;
    uint popup_stack_level = 0;

    if (ImGui_TreeNodeEx("Event###event_block", ImGuiTreeNodeFlags_OpenOnDoubleClick | ImGuiTreeNodeFlags_DefaultOpen)) {
        int selected_event = 0;
        array<string> event_names;

        for (uint event_index = 0; event_index < EVENT_LAST; event_index++) {
            event_names.insertLast(state.native_events[event_index].pretty_name);
        }

        ImGui_Combo("##function_selector", selected_event, event_names);

        ImGui_TreePop();
    }

    if (ImGui_TreeNodeEx("Conditions###conditions_block", ImGuiTreeNodeFlags_OpenOnDoubleClick | ImGuiTreeNodeFlags_DefaultOpen)) {
        ImGui_TreePop();
    }

    draw_expressions_in_a_tree_node("Actions", current_trigger.actions, expression_index, popup_stack_level);

    ImGui_EndGroup();
}