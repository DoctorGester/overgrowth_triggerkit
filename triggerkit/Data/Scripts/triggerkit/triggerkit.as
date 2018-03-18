// Operators todos:
//  Work on parenthesis elimination. Long chains of additions shouldn't have parenthesis at all.
//      This is easy to handle, not sure if we can devise a more general solution though.
// A big point of failure is:
//  if we delete a variable/user function which is used in an operator we won't be able to infer a type
//  from it and will fail to determine the operator. This can be prevented by somehow caching the expression type in
//  the expression itself and falling back to that type if we failed to determine one.

// Undo/Redo/Cancel. The way to do it: just keep a buffer of serialized code versions and have a push_trigger_state function called at certain times
// Serialization format versioning
// Proper error reporting: compiler goes through the whole thing and gives a list of Compiler_Error which have trigger name and line numbers, 
//                         highlight them and exclude related triggers from compilation
// Fix some todos
// Break expression, fix the return expression, user functions UI
// Figure out another demo with proper dialogues
// Make even more demos, abandon this one!
// Varargs for string concatenation? We could combine them into an array and pass that easily
// We WILL need expressions or some kind of parameter selection in events, example: Every X seconds
//  Alternatively Every X seconds can be easily implemented with while (true) wait
// Hide all non-void returns in statement editor popup, but add an exception boolean which would allow functions like CreateCharacter to be there

// UI: User functions!
// Compiler: Actual function types so we could get rid of EXPRESSION_FORK and the whole strapped on event architecture
// VM/Compiler: Resize stack dynamically or just figure out maximum stack size and set it to that
// VM: Exceptions (divide by zero, etc)
// VM: Array types
// VM/Compiler: _RESERVE seems like a useless instruction? What are we doing wrong here exactly? There has to be
//              a way to move the stack pointer without it
// An interesting thing there: we could have a thread.join function which would wait until a thread ends
// We could somehow signify that a parameter is an enum value and allow selecting it in-place
//  This gets rid of useless (?) function/variable selectors
// We desperately need newlines in action dialogue
// Dialogue milestones:
//  Enums:
//    Poses
//  Enter dialogue skipping
//  Figure out how to implement [wait .. 0.4] in our dialogues (maybe some special mode which doesn't trigger "click to proceed?")
//  Implement Dialogue append string ([wait for click])
//  New demo: Racing again. Notions:
//      Use an existing map (that ice thingy from overgrowth campaign)
//      UI: timer, countdown
//      Sounds
//      Map camera overview
//      Record best runs
//      Fade in/fade out
//      Checkpoints
//      Maybe we could have something like have actual race contestants? I dunno
// BUG: when adding a new condition default operator value is not filled at all (because we set it to do_nothing)
// After the latest update modal window positions are not set correctly, look into it
// We don't really need to show empty combos now, need to look into it if it's not possible
//  We could also just draw a text which says "no values available" or whatever
// BUG: when editing an expression, other expressions under it get their state thrown around due to expression_index changing,
//      we should tie stateful elements to line counter instead (example: if statement blocks)
// Figure out expression editor modal size issues, we need to have minimum size and dynamically adapt the expressions for the size
// Dialogue:
//  should get rid of placement_type lol
//  start/stop talking
//  fade in/out
//  get current camera
//  enter skipping
// We could add category icons to the categories combo (need a custom selectable-like) component for that
// We need to be able to put cameras/poses/regions into categories

#include "triggerkit/ui.as"
#include "triggerkit/vm.as"
#include "triggerkit/types.as"
#include "triggerkit/compiler.as"
#include "triggerkit/parser.as"
#include "triggerkit/persistence.as"
#include "triggerkit/api.as"
#include "triggerkit/shared_definitions.as"
#include "triggerkit/dialogue/dialogue.as"

Virtual_Machine@ vm;
Trigger_Kit_State@ state;
Enums@ enums;

double get_time_delta_in_ms(uint64 start) {
    return double((GetPerformanceCounter() - start)*1000) / GetPerformanceFrequency();
}

array<Expression@>@ make_test_expression_array() {
    Expression@ add = make_op_expr(OPERATOR_ADD, make_lit(2), make_lit(3));
    Expression@ sub = make_op_expr(OPERATOR_SUB, make_lit(10), add);

    Expression@ or_op = make_op_expr(OPERATOR_OR, 
        make_op_expr(OPERATOR_EQ, make_ident("my_var"), make_lit(3)),
        make_op_expr(OPERATOR_EQ, make_ident("my_var"), make_lit(5))
    );

    Expression@ and_op = make_op_expr(OPERATOR_AND, 
        make_op_expr(OPERATOR_LT, make_ident("my_var2"), make_lit(6)),
        or_op
    );

    Expression@ log1 = make_function_call("log1");
    Expression@ log2 = make_function_call("log2");
    Expression@ wait = make_function_call("wait");

    Expression@ print = make_function_call("print");
    Expression@ rnd = make_function_call("rnd");
    print.arguments.insertLast(rnd);

    Expression@ print_str = make_function_call("print_str");
    print_str.arguments.insertLast(make_lit("donger"));


    Expression@ condition = Expression();
    condition.type = EXPRESSION_IF;
    @condition.value_expression = make_op_expr(OPERATOR_LT, make_ident("my_var2"), make_lit(5));
    condition.block_body = array<Expression@> = {
        log2
    };

    condition.else_block_body = array<Expression@> = {
        log2,
        wait
    };

    Expression@ condition2 = Expression();
    condition2.type = EXPRESSION_IF;
    @condition2.value_expression = and_op;
    condition2.block_body = array<Expression@> = {
        log1
    };

    Expression@ repeat = Expression();
    repeat.type = EXPRESSION_REPEAT;
    @repeat.value_expression = make_lit(10);
    //repeat.block_body.insertLast(sub);
    repeat.block_body = array<Expression@> = {
        make_declaration(LITERAL_TYPE_NUMBER,"My boy named \"Bucko\"", make_lit(3)),
        make_declaration(LITERAL_TYPE_NUMBER,"My funky var", make_lit(3)),
        make_declaration(LITERAL_TYPE_NUMBER,"my_var2", make_ident("my_var")),
        make_assignment("my_var2", make_op_expr(OPERATOR_ADD, make_ident("my_var2"), make_lit(2))),
        condition,
        make_assignment("my_var", make_op_expr(OPERATOR_ADD, make_ident("my_var"), make_lit(1))),
        print,
        print_str
    };


    array<Expression@>@ expressions = {
        make_declaration(LITERAL_TYPE_NUMBER,"my_var", make_lit(1)),
        repeat
    };

    return expressions;
}

void print_compilation_debug_info(Translation_Context@ ctx) {
    array<string>@ function_names = ctx.user_function_indices.getKeys();
    array<Instruction>@ code = ctx.code;

    for (uint x = 0; x < code.length(); x++) {
        string text = instruction_to_string(code[x]);

        for (uint i = 0; i < function_names.length(); i++) {
            string name = function_names[i];
            uint location = uint(ctx.constants[uint(ctx.user_function_indices[name])].number_value);

            if (location == x) {
                Log(info, colored_keyword("// function ") + name);
                break;
            }
        }

        for (uint i = 0; i < state.triggers.length(); i++) {
            if (state.triggers[i].function_entry_pointer == x) {
                Log(info, colored_keyword("// trigger ") + state.triggers[i].name);
            }
        }

        if (code[x].type == INSTRUCTION_TYPE_LOAD_CONST) {
            Memory_Cell@ constant = ctx.constants[uint(code[x].int_arg)];

            text += colored_keyword(" // ") + memory_cell_to_string(constant);
        }

        if (code[x].type == INSTRUCTION_TYPE_RESERVE && code[x].int_arg >= 0) {
            Log(info, "");
        }

        if (code[x].type == INSTRUCTION_TYPE_NATIVE_CALL) {
            auto keys = ctx.native_function_indices.getKeys();
            uint function_id = uint(code[x].int_arg);
            string suffix_text = " (" + colored_literal(function_id + "") + ")";

            for (uint j = 0; j < keys.length(); j++) {
                if (uint(ctx.native_function_indices[keys[j]]) == function_id) {
                    text = colored_keyword("call ") + keys[j] + suffix_text;
                    break;
                }
            }

            if (function_id < ctx.operator_definitions.length()) {
                string op_name = operator_type_to_serializeable_string(ctx.operator_definitions[function_id].operator_type);
                text = colored_keyword(op_name) + suffix_text;
            }
        }

        if (code[x].type == INSTRUCTION_TYPE_CALL) {
            auto keys = ctx.user_function_indices.getKeys();
            uint function_id = uint(code[x].int_arg);
            string suffix_text = " (" + colored_literal(function_id + "") + ")";

            for (uint j = 0; j < keys.length(); j++) {
                if (uint(ctx.user_function_indices[keys[j]]) == function_id) {
                    text = colored_keyword("ucall ") + keys[j] + suffix_text;
                    break;
                }
            }
        }

        Log(info, x + ": " + text);
    }
}

void test_simple_code(array<Expression@>@ expressions) {
    Thread@ thread = make_thread(vm);

    Log(info, "----");

    auto t = GetPerformanceCounter();
    /*Translation_Context@ context = translate_expressions_into_bytecode(expressions);
    set_thread_up_from_translation_context(thread, context);
    Log(info, "Translation :: " + context.expressions_translated + " expressions translated in " + get_time_delta_in_ms(t) + "ms");

    Log(info, "Constants");

    for (uint index = 0; index < thread.constant_pool.length(); index++) {
        Log(info, index + ": " + memory_cell_to_string(thread.constant_pool[index]));
    }

    print_bytecode(thread);*/

    vm.threads.insertLast(thread);
}

string memory_cell_to_string(Memory_Cell@ cell) {
    return cell.number_value + "/" + cell.string_value;
}

void initialize_state_and_vm() {
    @vm = make_vm();
    @state = load_trigger_state_from_level_params();

    for (uint variable_index = 0; variable_index < state.global_variables.length(); variable_index++) {
        vm.memory[variable_index] = state.global_variables[variable_index].value;
    }
}

array<Operator_Definition@>@ collect_operator_definitions(array<Operator_Group@>@ operator_groups) {
    array<Operator_Definition@> result;

    for (uint group_index = 0; group_index < operator_groups.length(); group_index++) {
        Operator_Group@ group = operator_groups[group_index];

        for (uint operator_index = 0; operator_index < group.operators.length(); operator_index++) {
            Operator_Definition@ operator = group.operators[operator_index];

            result.insertLast(group.operators[operator_index]);
        }
    }

    return result;
}

void compile_everything() {
    auto time = GetPerformanceCounter();

    Translation_Context@ translation_context = prepare_translation_context();

    for (uint trigger_index = 0; trigger_index < state.triggers.length(); trigger_index++) {
        Trigger@ trigger = state.triggers[trigger_index];
        Function_Definition@ function_definition = convert_trigger_to_function_definition(trigger);

        trigger.function_entry_pointer = compile_single_function_definition(translation_context, function_definition);
    }

    compile_user_functions(translation_context);
    backpatch_user_function_calls(translation_context);

    vm.code = translation_context.code;
    @vm.function_executors = translation_context.function_executors;
    @vm.constant_pool = translation_context.constants;

    Log(info, "load_state_and_compile_code :: " + translation_context.expressions_translated + " expressions translated, took " + get_time_delta_in_ms(time) + "ms");

    // print_compilation_debug_info(translation_context);
}

void Init(string p_level_name) {
    PostScriptReload();

    level.SendMessage(event_type_to_serializeable_string(EVENT_LEVEL_START));
}

void ReceiveMessage(string message) {
    // Spam
    if (message == "tutorial") {
        return;
    }
    
    if (message == "post_reset") {
        level.SendMessage(event_type_to_serializeable_string(EVENT_LEVEL_START));
    }

    try_handle_event_from_message(message);
}

// TODO remove testing stuff
string serialized = "";
string serialized_and_then_deserialized = "";
bool show_text_output = false;

float fade_out_start;
float fade_out_end = -1.0f;

float fade_in_start;
float fade_in_end = -1.0f;
int controller_id = 0;

void DrawGUI2() {
    environment::draw2();
}

void DrawGUI() {
    environment::draw();

    if (EditorModeActive()) {
        ImGui_Begin("My_Debug_Win", ImGuiWindowFlags_MenuBar);

        if (ImGui_Button("Restart VM and Reload state")) {
            Init("");
        }

        if (ImGui_Button("Save trigger state")) {
            save_trigger_state_into_level_params(state);
        }

        if (ImGui_Button("Run current trigger")) {
            run_trigger(state.triggers[state.selected_trigger], array<Memory_Cell@>());
        }

        if (ImGui_Button("Run test simple code")) {
            test_simple_code(make_test_expression_array());
        }

        if (ImGui_Button("Populate first trigger with test code")) {
            state.triggers[0].actions = make_test_expression_array();
        }

        if (ImGui_Button("Save and load code")) {
            save_trigger_state_into_level_params(state);
            load_trigger_state_from_level_params();
        }

        if (ImGui_Button("Compile code")) {
            compile_everything();
        }

        if (ImGui_Button("Test string escaping")) {
            auto t = serializeable_string("dog \"dobbi bingo bobbi\" bobzer");

            Log(info, "--");

            for (uint i = 0; i < t.length(); i++) {
                Log(info, t);
            }

            Log(info, "bb");
        }
        

        if (ImGui_Button("Test lexer")) {
            auto t = split_into_words_and_quoted_pieces(serialize_expression_block(make_test_expression_array(), ""));

            Log(info, "--");

            for (uint i = 0; i < t.length(); i++) {
                Log(info, t[i]);
            }

            Log(info, "bb");
        }

        if (ImGui_Button("Test code serialization")) {
            serialized = serialize_expression_block(make_test_expression_array(), "");

            auto words = split_into_words_and_quoted_pieces(serialized);
            Parser_State parser_state;
            parser_state.words = words;

            array<Expression@> expressions;
            parse_words_into_expression_array(parser_state, expressions);

            serialized_and_then_deserialized = serialize_expression_block(expressions, "");
        }

        if (vm !is null) {
            ImGui_Checkbox("Debugger", vm.is_in_debugger_mode);

            if (vm.is_in_debugger_mode && vm.threads.length() > 0) {
                Thread@ thread = vm.threads[0];

                ImGui_Text("Is Paused: " + thread.is_paused);

                if (ImGui_Button("Step forward")) {
                    thread_step_forward(thread);
                }

                ImGui_ListBoxHeader("Code");

                for (uint i = 0; i < vm.code.length(); i++) {
                    string clr = i == thread.current_instruction ? "\x1B22FF11FF" : "";

                    ImGui_Text(clr + i + ": " + instruction_to_string(vm.code[i]));
                }

                ImGui_ListBoxFooter();

                ImGui_ListBoxHeader("Stack");

                for (uint i = 0; i < thread.stack_top; i++) {
                    string clr = i == thread.current_call_frame_pointer ? "\x1B22FF11FF" : "";

                    ImGui_Text(clr + i + ": " + memory_cell_to_string(thread.stack[i]));
                }

                ImGui_ListBoxFooter();
            }
        }

        ImGui_Checkbox("Show text ouput", show_text_output);

        ImGui_End();

        draw_trigger_kit();

        if (show_text_output) {
            ImGui_Begin("text output", ImGuiWindowFlags_HorizontalScrollbar);
            ImGui_SetTextBuf(serialized);
            ImGui_InputTextMultiline("###input", ImGuiInputTextFlags_ReadOnly);
            ImGui_End();

            ImGui_Begin("text output 2", ImGuiWindowFlags_HorizontalScrollbar);
            ImGui_SetTextBuf(serialized_and_then_deserialized);
            ImGui_InputTextMultiline("###input", ImGuiInputTextFlags_ReadOnly);
            ImGui_End();
        }
    }
}

void Update(int paused) {
    if (!EditorModeActive()) {
        environment::update();
    }

    if (!(vm is null)) {
        if (vm.threads.length() > 0) {
            if (!vm.is_in_debugger_mode) {
                auto t = GetPerformanceCounter();
                update_vm_state(vm);
                //Log(info, "Time :: " + get_time_delta_in_ms(t) + "ms");
            }
        }
    }
}

void PostScriptReload() {
    @enums = Enums();

    fill_enums(enums);
    initialize_state_and_vm();
    compile_everything();
}

void PreScriptReload() {
    @state = null;
    @vm = null;
    @enums = null;
}

void SetWindowDimensions(int w, int h) {
}

int HasCameraControl() {
    if (EditorModeActive()) {
        return 0;
    }

    return environment::has_camera_control ? 1 : 0;
}

bool DialogueCameraControl() {
    return !EditorModeActive() && environment::has_camera_control;
}

Expression@ make_empty_lit(Literal_Type literal_type) {
    Expression expression;
    expression.type = EXPRESSION_LITERAL;
    expression.literal_type = literal_type;

    return expression;
}

Expression@ make_handle_lit(Literal_Type literal_type, int handle_id) {
    Expression expression;
    expression.type = EXPRESSION_LITERAL;
    expression.literal_type = literal_type;
    expression.literal_value.number_value = handle_id;

    return expression;
}

Expression@ make_enum_lit(Literal_Type literal_type, uint enum_value) {
    Expression expression;
    expression.type = EXPRESSION_LITERAL;
    expression.literal_type = literal_type;
    expression.literal_value.number_value = enum_value;

    return expression;
}

Expression@ make_lit(float v) {
    Expression expression;
    expression.type = EXPRESSION_LITERAL;
    expression.literal_type = LITERAL_TYPE_NUMBER;
    expression.literal_value.number_value = v;

    return expression;
}

Expression@ make_lit(string v) {
    Expression expression;
    expression.type = EXPRESSION_LITERAL;
    expression.literal_type = LITERAL_TYPE_STRING;
    expression.literal_value.string_value = v;

    return expression;
}

Expression@ make_lit(bool v) {
    Expression expression;
    expression.type = EXPRESSION_LITERAL;
    expression.literal_type = LITERAL_TYPE_BOOL;
    expression.literal_value.number_value = bool_to_number(v);

    return expression;
}

Expression@ make_lit(vec3 v) {
    Expression expression;
    expression.type = EXPRESSION_LITERAL;
    expression.literal_type = LITERAL_TYPE_VECTOR_3;
    expression.literal_value.vec3_value = v;

    return expression;
}

Expression@ make_return(Expression@ value) {
    Expression expression;
    expression.type = EXPRESSION_RETURN;
    @expression.value_expression = value;

    return expression;
}

Expression@ make_ident(string name) {
    Expression expression;
    expression.type = EXPRESSION_IDENTIFIER;
    expression.identifier_name = name;

    return expression;
}

Expression@ make_declaration(Literal_Type type, string name, Expression@ right) {
    Expression expression;
    expression.type = EXPRESSION_DECLARATION;
    expression.literal_type = type;
    expression.identifier_name = name;
    @expression.value_expression = right;

    return expression;
}

Expression@ make_op_expr(Operator_Type type, Expression@ left, Expression@ right) {
    Expression expression;
    expression.type = EXPRESSION_OPERATOR;
    expression.operator_type = type;

    @expression.left_operand = left;
    @expression.right_operand = right;

    return expression;
}

Expression@ make_function_call(string name) {
    Expression@ expr = Expression();
    expr.type = EXPRESSION_CALL;
    expr.identifier_name = name;

    return expr;
}

Expression@ make_assignment(string variable, Expression@ right) {
    Expression expression;
    expression.type = EXPRESSION_ASSIGNMENT;
    expression.identifier_name = variable;
    @expression.value_expression = right;

    return expression;
}

Expression@ make_while(Expression@ condition, array<Expression@>@ body) {
    Expression@ expression = Expression();
    expression.type = EXPRESSION_WHILE;
    @expression.value_expression = condition;
    expression.block_body = body;

    return expression;
}

Expression@ make_if(Expression@ condition, array<Expression@>@ then_body = null, array<Expression@>@ else_body = null) {
    Expression@ expression = Expression();
    expression.type = EXPRESSION_IF;
    @expression.value_expression = condition;

    if (then_body !is null) {
        expression.block_body = then_body;
    }
    
    if (else_body !is null) {
        expression.else_block_body = else_body;
    }

    return expression;
}