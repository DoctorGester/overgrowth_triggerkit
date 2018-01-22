// Compiler: Native function library, proper native calls
// Compiler: Types in general, lol
// Compiler: Compile into multiple targets with the global compilation context
// Compiler: EXPRESSION_OPERATOR and Operator_Type
// VM/Compiler: Resize stack dynamically or just figure out maximum stack size and set it to that
// VM: Exceptions (divide by zero, etc)
// VM: Array types
// General: Code persistence

#include "triggerkit/ui.as"
#include "triggerkit/vm.as"
#include "triggerkit/compiler.as"
#include "triggerkit/parser.as"
#include "triggerkit/persistence.as"


enum Expression_Type {
    EXPRESSION_LITERAL,
    EXPRESSION_DECLARATION,
    EXPRESSION_ASSIGNMENT,
    EXPRESSION_IDENTIFIER,
    EXPRESSION_OPERATOR,

    EXPRESSION_REPEAT,
    EXPRESSION_IF,

    EXPRESSION_NATIVE_CALL
}

enum Operator_Type {
    OPERATOR_OR,
    OPERATOR_AND,

    OPERATOR_ADD,
    OPERATOR_SUB,
    OPERATOR_MUL,
    OPERATOR_DIV,

    OPERATOR_EQ,
    OPERATOR_GT,
    OPERATOR_LT,

    OPERATOR_LAST
}

enum Literal_Type {
    LITERAL_TYPE_VOID,
    LITERAL_TYPE_NUMBER,
    LITERAL_TYPE_STRING,
    LITERAL_TYPE_BOOL,
    LITERAL_TYPE_OBJECT,
    LITERAL_TYPE_ITEM,
    LITERAL_TYPE_HOTSPOT,
    LITERAL_TYPE_CHARACTER,
    LITERAL_TYPE_VECTOR,
    LITERAL_TYPE_FUNCTION,
    LITERAL_TYPE_ARRAY,
    LITERAL_TYPE_LAST
}

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

class Function_Definition {

}

// WE HAVE AN ARRAY FILLING UP SOMEWHERE WHICH IS WHY IT RUNS OUT OF MEMORY AND HOT RELOADING IS SLOW!!!!!!!!!!!!!!!!!!!!!
// ----------- Bytecode ------------

Virtual_Machine@ vm;
Trigger_Kit_State@ state;

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

Expression@ make_native_call_expr(string name) {
    Expression@ expr = Expression();
    expr.type = EXPRESSION_NATIVE_CALL;
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

    Expression@ log1 = make_native_call_expr("log1");
    Expression@ log2 = make_native_call_expr("log2");
    Expression@ wait = make_native_call_expr("wait");

    Expression@ print = make_native_call_expr("print");
    Expression@ rnd = make_native_call_expr("rnd");
    print.arguments.insertLast(rnd);

    Expression@ print_str = make_native_call_expr("print_str");
    print_str.arguments.insertLast(make_lit("donger"));


    Expression@ condition = Expression();
    condition.type = EXPRESSION_IF;
    @condition.value_expression = make_op_expr(OPERATOR_LT, make_ident("my_var2"), make_lit(5));
    condition.block_body = array<Expression@> = {
        log2
    };

    condition.else_block_body = array<Expression@> = {
        log2
        //wait
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

void test_simple_code() {
    Thread@ thread = make_thread(vm);

    array<Expression@>@ expressions = make_test_expression_array();

    Log(info, "----");

    auto t = GetPerformanceCounter();
    translate_expressions_into_bytecode_and_set_thread_up(expressions, thread);
    Log(info, "Translation :: " + get_time_delta_in_ms(t) + "ms");

    Log(info, "Constants");

    for (uint index = 0; index < thread.constant_pool.length(); index++) {
        Log(info, index + ": " + memory_cell_to_string(thread.constant_pool[index]));
    }

    Log(info, "Stack offset: " + thread.stack_offset);

    for (uint x = 0; x < thread.code.length(); x++) {
        Log(info, x + ": " + instruction_to_string(thread.code[x]));
    }

    vm.threads.insertLast(thread);
}

string memory_cell_to_string(Memory_Cell@ cell) {
    return cell.number_value + "/" + cell.string_value;
}

void ScriptReloaded() {
    Init("");
}

void Init(string p_level_name) {
    Log(info, "rld");
}

void ReceiveMessage(string msg) {
    // Spam
    if (msg == "tutorial ") {
        return;
    }

    //script.ReceiveMessage(msg);
}

string serialized = "";
string serialized_and_then_deserialized = "";

void DrawGUI() {
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

        if (ImGui_Button("Run test code")) {
            test_simple_code();
        }

        if (ImGui_Button("Populate first trigger with test code")) {
            state.triggers[0].content = make_test_expression_array();
        }
        
        if (ImGui_Button("Save and load code")) {
            state.triggers = parse_triggers_from_string(serialize_triggers_into_string(state.triggers));
        }

        if (ImGui_Button("Compile code")) {
            Thread thread;
            translate_expressions_into_bytecode_and_set_thread_up(make_test_expression_array(), thread);
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

                if (ImGui_Button("Step forward")) {
                    thread_step_forward(thread, Thread_Step_Details());
                }

                ImGui_ListBoxHeader("Code");

                for (uint i = 0; i < thread.code.length(); i++) {
                    string clr = i == thread.current_instruction ? "##22FF11FF" : "";

                    ImGui_Text(clr + i + ": " + instruction_to_string(thread.code[i]));
                }

                ImGui_ListBoxFooter();


                ImGui_ListBoxHeader("Stack");

                for (uint i = 0; i < thread.stack_top; i++) {
                    ImGui_Text(i + ": " + thread.stack[i].number_value);
                }

                ImGui_ListBoxFooter();
            }
        }

        ImGui_End();

        draw_trigger_kit();

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

void Update(int paused) {
    if (!(vm is null)) {
        if (vm.threads.length() > 0) {
            if (!vm.is_in_debugger_mode) {
                auto t = GetPerformanceCounter();
                update_vm_state(vm);
                Log(info, "Time :: " + get_time_delta_in_ms(t) + "ms");
            }
        }
    }
}

void SetWindowDimensions(int w, int h)
{
}