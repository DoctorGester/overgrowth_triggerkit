funcdef bool Function_Predicate(Function_Definition@ f);

namespace icons {
    TextureAssetRef image_blank = LoadTexture("Data/Images/triggerkit/ui/image_blank.png", TextureLoadFlags_NoMipmap);

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

// TODO unused
Trigger@ get_current_selected_trigger() {
    if (uint(state.selected_trigger) >= state.triggers.length()) {
        return null;
    }

    return state.triggers[uint(state.selected_trigger)];
}

array<Function_Definition@> filter_function_definitions_by_predicate(Function_Predicate@ predicate) {
    array<Function_Definition@> filter_result;

    for (uint index = 0; index < state.function_definitions.length(); index++) {
        Function_Definition@ function_description = state.function_definitions[index];

        if (predicate(function_description)) {
            filter_result.insertLast(function_description);
        }
    }

    return filter_result;
}

Trigger_Kit_State@ make_trigger_kit_state() {
    Trigger_Kit_State state;

    Api_Builder@ api_builder = build_api();
    state.function_definitions = api_builder.functions;
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

    draw_globals_modal();

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
        case LITERAL_TYPE_BOOL: return literal_color + (number_to_bool(literal.literal_value.number_value) ? "True" : "False") + default_color;

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

// TODO speed, can DEFINITELY be cached
// TODO speed, can DEFINITELY be cached
// TODO speed, can DEFINITELY be cached
array<string>@ split_function_format_string_into_pieces(string format) {
    array<string> result;

    int character_index = 0;

    while (true) {
        int new_character_index = format.findFirst("{}", character_index);

        if (new_character_index != -1) {
            result.insertLast(format.substr(character_index, new_character_index - character_index));
        } else {
            if (character_index == 0) {
                result.insertLast(format);
            } else {
                result.insertLast(format.substr(character_index));
            }

            break;
        }

        character_index = new_character_index + 2;
    }

    return result;
}

Function_Definition@ find_function_definition_by_function_name(string function_name) {
    for (uint function_index = 0; function_index < state.function_definitions.length(); function_index++) {
        if (state.function_definitions[function_index].function_name == function_name) {
            return state.function_definitions[function_index];
        }
    }

    return null;
}

string function_call_to_string(Expression@ expression) {
    Function_Definition@ function_definition = find_function_definition_by_function_name(expression.identifier_name);

    if (function_definition is null) {
        return function_call_to_string_simple(expression);
    }

    string result = "";

    array<string>@ pieces = split_function_format_string_into_pieces(function_definition.format);

    for (uint argument_index = 0; argument_index < function_definition.argument_types.length(); argument_index++) {
        result += pieces[argument_index];

        string argument_as_string = literal_type_to_ui_string(function_definition.argument_types[argument_index]);

        if (expression.arguments.length() > argument_index) {
            Expression@ argument_expression = expression.arguments[argument_index];

            if (argument_expression !is null) {
                argument_as_string = expression_to_string(argument_expression);

                if (argument_expression.type != EXPRESSION_LITERAL && argument_expression.type != EXPRESSION_IDENTIFIER) {
                    argument_as_string = "(" + argument_as_string + ")";
                }
            }
        }

        result += argument_as_string;
    }

    result += pieces[pieces.length() - 1];

    return result;
    //return expression.identifier_name + "(" + join(arguments, ", ") + ")";
}

string expression_to_string(Expression@ expression) {
    if (expression is null) {
        return "<ERROR>";
    }

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
        case EXPRESSION_CALL: return function_call_to_string(expression);
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

void fill_function_call_expression_from_function_definition(Expression@ expression, Function_Definition@ function_definition) {
    expression.identifier_name = function_definition.function_name;
    expression.arguments.resize(function_definition.argument_types.length());

    for (uint argument_index = 0; argument_index < function_definition.argument_types.length(); argument_index++) {
        Literal_Type argument_type = function_definition.argument_types[argument_index];

        @expression.arguments[argument_index] = make_empty_lit(argument_type);
    }
}

string get_function_name_for_list(Function_Definition@ function_definition) {
    string name = function_definition.pretty_name;

    if (name.isEmpty()) {
        return function_definition.function_name;
    }

    return name;
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

// TODO speed! Could be array indexed
// We could also just store Function_Definition references in expressions
TextureAssetRef get_call_icon(Expression@ expression) {
    for (uint function_index = 0; function_index < state.function_definitions.length(); function_index++) {
        Function_Definition@ function_definition = state.function_definitions[function_index];
        if (function_definition.function_name == expression.identifier_name) {
            if (function_definition.return_type == LITERAL_TYPE_BOOL) {
                return icons::action_logical;
            }
            
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

void draw_expressions(array<Expression@>@ expressions, Ui_Frame_State@ frame) {
    if (expressions.length() == 0) {
        if (ImGui_Button("+##bluz")) {
            expressions.insertLast(make_function_call("dingo"));
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
                expressions.insertAt(uint(index) + 1, make_function_call("dingo"));
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

// Big SHack!
float get_text_width(string text) {
    vec2 cursor_position = ImGui_GetCursorPos();

    ImGui_TextColored(vec4(), text);
    ImGui_SameLine();

    float new_x = ImGui_GetCursorPosX();

    ImGui_SetCursorPos(cursor_position);

    return new_x - cursor_position.x;
}

bool icon_button(string text, string id, TextureAssetRef icon) {
    const float size_y = 28.0f;
    float text_width = get_text_width(text);

    vec2 cursor_position = ImGui_GetCursorPos();
    vec2 image_size(16, 16);
    float image_padding = size_y / 2.0f - (image_size.y / 2.0f);
    vec2 size(image_padding * 3 + image_size.x + text_width, size_y);
    vec2 image_position(image_padding, image_padding);

    bool activated = ImGui_InvisibleButton(id, size);

    vec2 cursor_position_after_button = ImGui_GetCursorPos();
    vec4 color(0.35f, 0.40f, 0.61f, 0.62f);

    if (ImGui_IsItemActive()) {
        color = vec4(0.46f, 0.54f, 0.80f, 1.00f);
    } else if (ImGui_IsItemHovered()) {
        color = vec4(0.40f, 0.48f, 0.71f, 0.79f);
    }

    ImGui_SetCursorPos(cursor_position);
    ImGui_Image(icons::image_blank, size, tint_color: color);

    ImGui_SetCursorPos(cursor_position + image_position);
    ImGui_Image(icon, image_size);

    ImGui_SameLine();
    ImGui_Text(text);

    ImGui_SetCursorPos(cursor_position_after_button);

    return activated;
}

void draw_globals_modal() {
    bool is_open = true;

    if (ImGui_BeginPopupModal("Globals###globals_popup", is_open)) {
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

        ImGui_EndPopup();
    }
}