// More dialogue functions
// Operator support in UI
// Exclude certain functions (like boolean comparisons) from the list of available actions
// Undo/Redo/Cancel. The way to do it: just keep a buffer of serialized code versions and have a push_trigger_state function called at certain times
// Serialization format versioning
// Proper error reporting: compiler goes through the whole thing and gives a list of Compiler_Error which have direct links to Expression@ instances, 
//                         highlight them and exclude related triggers from compilation
// Properly resize globals window when opened and resize global list to the size of the window
// Figure out what to do with stuff like string operators etc, we could totally make everything a function but then we lose an ability to easily analyze it
// Fix variable scoping in the UI, you can access already defined variables
// Fix some todos
// Cameras for dialogues:
//      Vector type
//      Camera type: camera model and a camera panel which allows setting current view to camera and camera to view
//      Parallel execution, Parallel operation type
//          Break expression, fix the return expression, user functions UI
// Figure out another demo with proper dialogues
// Make even more demos, abandon this one!
// Varargs for string concatenation? We could combine them into an array and pass that easily

// UI: User functions!
// Compiler: Make the compiler multipass, currently can't call routines which were not parsed yet
// Compiler: Types in general, lol
// Compiler: Actual function types
// VM/Compiler: Resize stack dynamically or just figure out maximum stack size and set it to that
// VM: Exceptions (divide by zero, etc)
// VM: Array types
// VM/Compiler: _RESERVE seems like a useless instruction? What are we doing wrong here exactly? There has to be
//              a way to move the stack pointer without it
// Very far fetch: "Run in parallel block", would require lambda functions?
//                  Maybe we can just somehow hack it together and only run user functions like that? 
//                  Like a user-function call flag which just spawns a new thread with a native_call
//                       and copies num_args from top of the stack into it?
//                  On a side note a block would literally be compiled as a separate function with all
//                      used previous scope local variables copied in a similar manner to function calls,
//                      in the end isn't that what lambda functions are? It wouldn't even enable first class
//                      function support or a funarg problem because we wouldn't be able to pass the function around
//                      and there wouldn't be a function type or any associated type-checking. Smooth.
//                  An interesting thing there: we could have a thread.join function which would wait until a thread ends


#include "triggerkit/ui.as"
#include "triggerkit/vm.as"
#include "triggerkit/compiler.as"
#include "triggerkit/parser.as"
#include "triggerkit/persistence.as"
#include "triggerkit/api.as"
#include "triggerkit/shared_definitions.as"
#include "triggerkit/dialogue/dialogue.as"

class Expression {
    Expression_Type type;

    Literal_Type literal_type;
    Literal_Type array_type;

    Operator_Type operator_type;

    Memory_Cell literal_value;

    // Identifier/Function call/Declaration/Assignment
    string identifier_name;

    // Operator
    Expression@ left_operand;
    Expression@ right_operand;

    // If/While/For condition/Assignment/Declaration
    Expression@ value_expression;

    // Function args
    array<Expression@> arguments;

    // Block
    array<Expression@> block_body;
    array<Expression@> else_block_body;
}

Virtual_Machine@ vm;
Trigger_Kit_State@ state;

Expression@ make_empty_lit(Literal_Type literal_type) {
    Expression expression;
    expression.type = EXPRESSION_LITERAL;
    expression.literal_type = literal_type;

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
    for (uint x = 0; x < ctx.code.length(); x++) {
        string comment = "";
        for (uint i = 0; i < function_names.length(); i++) {
            string name = function_names[i];
            uint location = uint(ctx.constants[uint(ctx.user_function_indices[name])].number_value);

            if (location == x) {
                comment = colored_keyword(" // function ") + name;
                break;
            }
        }

        for (uint i = 0; i < state.triggers.length(); i++) {
            if (state.triggers[i].function_entry_pointer == x) {
                comment = colored_keyword(" // trigger ") + state.triggers[i].name;
            }
        }

        Log(info, x + ": " + instruction_to_string(ctx.code[x]) + comment);
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

void compile_everything() {
    auto time = GetPerformanceCounter();

    Variable_Scope global_variables;

    for (uint variable_index = 0; variable_index < state.global_variables.length(); variable_index++) {
        Variable@ variable = state.global_variables[variable_index];
        global_variables.local_variable_indices[variable.name] = variable_index;
    }

    Api_Builder@ api_builder = build_api();
    
    Translation_Context translation_context;
    @translation_context.function_definitions = api_builder.functions;
    translation_context.global_variable_scope = global_variables;

    compile_user_functions(translation_context);

    for (uint trigger_index = 0; trigger_index < state.triggers.length(); trigger_index++) {
        Trigger@ trigger = state.triggers[trigger_index];
        Function_Definition@ function_definition = convert_trigger_to_function_definition(trigger);

        trigger.function_entry_pointer = compile_single_function_definition(translation_context, function_definition);
    }

    vm.code = translation_context.code;
    @vm.function_executors = translation_context.function_executors;
    @vm.constant_pool = translation_context.constants;

    Log(info, "load_state_and_compile_code :: " + translation_context.expressions_translated + " expressions translated, took " + get_time_delta_in_ms(time) + "ms");

    print_compilation_debug_info(translation_context);
}

void Init(string p_level_name) {
    initialize_state_and_vm();
    compile_everything();
}

void ReceiveMessage(string message) {
    // Spam
    if (message == "tutorial") {
        return;
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

        if (ImGui_Button("Unload trigger state")) {
            state.triggers.resize(0);
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
                    set_up_instruction_executors_temp();

                    thread_step_forward(thread);

                    clean_up_instruction_executors_temp();
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
    environment::update();

    if (!(vm is null)) {
        if (vm.threads.length() > 0) {
            if (!vm.is_in_debugger_mode) {
                auto t = GetPerformanceCounter();
                update_vm_state(vm);
                //Log(info, "Time :: " + get_time_delta_in_ms(t) + "ms");
            }
        }
    }

    if (environment::is_in_dialogue_mode) {
        vec3 cam_rot(-40.0f, 0.0f, 0.0f);
        vec3 cam_pos(10.0f);
        float cam_zoom = 90.0f;
        camera.SetXRotation(cam_rot.x);
        camera.SetYRotation(cam_rot.y);
        camera.SetZRotation(cam_rot.z);
        camera.SetPos(cam_pos);
        camera.SetDistance(0.0f);
        camera.SetFOV(cam_zoom);
    }
}

void PostScriptReload() {
    initialize_state_and_vm();
    compile_everything();
}

void PreScriptReload() {
    @state = null;
    @vm = null;
}

void SetWindowDimensions(int w, int h) {
}

int HasCameraControl() {
    return environment::is_in_dialogue_mode ? 1 : 0;
}

bool DialogueCameraControl() {
    return environment::is_in_dialogue_mode;
}
