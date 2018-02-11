// UI: Conditions! You can compose conditions and actions into a single tree before passing them into the compiler
// UI: Event parameters and event variables
// UI/Compiler/VM: Global variables window
// UI: User functions!
// Style: replace most native_ calls and variable names, they are not native anymore mostly!
// Compiler: Make the compiler multipass, currently can't call routines which were not parsed yet
// Compiler: Types in general, lol
// Compiler: Compile into multiple targets with the global compilation context
// Compiler: Actual function types
// VM/Compiler: Resize stack dynamically or just figure out maximum stack size and set it to that
// VM: Exceptions (divide by zero, etc)
// VM: Array types
// VM/Compiler: _RESERVE seems like a useless instruction? What are we doing wrong here exactly? There has to be
//              a way to move the stack pointer without it


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

    // Identifier/Native call/Declaration/Assignment
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

Expression@ make_say_expr(string who, string what) {
    Expression@ expr = make_function_call("dialogue_say");
    expr.arguments.insertLast(make_lit(who));
    expr.arguments.insertLast(make_lit(what));

    return expr;
}

array<Expression@>@ make_test_dialogue_expression_array() {
    /*Expression@ calc = make_function_call("sub_test");
    calc.arguments.insertLast(make_lit(6.0f));
    calc.arguments.insertLast(make_lit(3.0f));

    Expression@ wait_for = make_function_call("wait");
    wait_for.arguments.insertLast(calc);*/

    Expression@ print_name = make_function_call("print_str");
    print_name.arguments.insertLast(make_ident("Entering Character"));

    array<Expression@>@ expressions = {
        /*make_function_call("log1"),
        wait_for,
        make_function_call("log2"),
        calc*/
        make_function_call("start_dialogue"),
        make_say_expr("Bongus", "Mega hail to you my fiend friend"),
        make_function_call("wait_until_dialogue_line_is_complete"),
        make_say_expr("Dingo", "Hi to u as well noob"),
        make_function_call("wait_until_dialogue_line_is_complete"),
        make_function_call("end_dialogue"),
        print_name
    };

    return expressions;
}

array<Expression@>@ make_simple_test_expression_array() {
    Expression@ condition = Expression();
    condition.type = EXPRESSION_IF;
    @condition.value_expression = make_op_expr(OPERATOR_LT, make_lit(3), make_lit(5));
    condition.block_body = array<Expression@> = {
    };

    condition.else_block_body = array<Expression@> = {
        //wait
    };

    Expression@ repeat = Expression();
    repeat.type = EXPRESSION_REPEAT;
    @repeat.value_expression = make_lit(10);
    //repeat.block_body.insertLast(sub);
    repeat.block_body = array<Expression@> = {
    };


    array<Expression@>@ expressions = {
    };

    return expressions;
}

void print_bytecode(Thread@ thread) {
    for (uint x = 0; x < thread.code.length(); x++) {
        Log(info, x + ": " + instruction_to_string(thread.code[x]));
    }
}

void test_simple_code(array<Expression@>@ expressions) {
    Thread@ thread = make_thread(vm);

    Log(info, "----");

    auto t = GetPerformanceCounter();
    Translation_Context@ context = translate_expressions_into_bytecode(expressions);
    set_thread_up_from_translation_context(thread, context);
    Log(info, "Translation :: " + context.expressions_translated + " expressions translated in " + get_time_delta_in_ms(t) + "ms");

    Log(info, "Constants");

    for (uint index = 0; index < thread.constant_pool.length(); index++) {
        Log(info, index + ": " + memory_cell_to_string(thread.constant_pool[index]));
    }

    print_bytecode(thread);

    vm.threads.insertLast(thread);
}

string memory_cell_to_string(Memory_Cell@ cell) {
    return cell.number_value + "/" + cell.string_value;
}

void Init(string p_level_name) {
    @vm = make_vm();
    @state = load_trigger_state_from_level_params();
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
            @vm = make_vm();
            @state = load_trigger_state_from_level_params();
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

        if (ImGui_Button("Run test dialogue code")) {
            test_simple_code(make_test_dialogue_expression_array());
        }

        if (ImGui_Button("Populate first trigger with test code")) {
            state.triggers[0].actions = make_test_expression_array();
        }

        if (ImGui_Button("Populate second trigger with dialogue code")) {
            state.triggers[1].actions = make_test_dialogue_expression_array();
        }
        
        if (ImGui_Button("Save and load code")) {
            state.triggers = parse_triggers_from_string(serialize_triggers_into_string(state.triggers));
        }

        if (ImGui_Button("Compile code")) {
            translate_expressions_into_bytecode(make_test_expression_array());
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

                    thread_step_forward(thread, Thread_Step_Details());

                    clean_up_instruction_executors_temp();
                }

                ImGui_ListBoxHeader("Code");

                for (uint i = 0; i < thread.code.length(); i++) {
                    string clr = i == thread.current_instruction ? "\x1B22FF11FF" : "";

                    ImGui_Text(clr + i + ": " + instruction_to_string(thread.code[i]));
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
}

void PostScriptReload() {
    @state = load_trigger_state_from_level_params();
}

void PreScriptReload() {
    @state = null;
}

void SetWindowDimensions(int w, int h) {
}