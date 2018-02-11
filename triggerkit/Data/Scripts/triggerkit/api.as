funcdef void Native_Function_Executor(Native_Call_Context@ context);

enum Function_Category {
    CATEGORY_OTHER,
    CATEGORY_DIALOGUE,
    CATEGORY_WAIT
}

class Event_Definition {
    Event_Type type;
    string pretty_name;
    string format;
    array<Literal_Type> argument_types;
    array<Literal_Type> variable_types;
    array<string> variable_names;

    Event_Definition@ takes(Literal_Type argument_type) {
        argument_types.insertLast(argument_type);
        return this;
    }

    Event_Definition@ defines(string variable_name, Literal_Type literal_type) {
        variable_types.insertLast(literal_type);
        variable_names.insertLast(variable_name);
        return this;
    }

    Event_Definition@ fmt(string format_string) {
        format = format_string;
        return this;
    }

    Event_Definition@ list_name(string pretty_name) {
        this.pretty_name = pretty_name;
        return this;
    }
}

class Function_Definition {
    array<Literal_Type> argument_types;
    array<string> argument_names;
    Literal_Type return_type = LITERAL_TYPE_VOID;
    Function_Category function_category = CATEGORY_OTHER;
    string pretty_name;
    string format;
    string function_name;
    Native_Function_Executor@ native_executor;
    array<Expression@>@ user_code = {};
    bool native = false;

    Function_Definition(){}

    Function_Definition@ takes(Literal_Type argument_type) {
        argument_types.insertLast(argument_type);
        return this;
    }

    Function_Definition@ takes(Literal_Type argument_type, string argument_name) {
        argument_types.insertLast(argument_type);
        argument_names.insertLast(argument_name);
        return this;
    }

    Function_Definition@ returns(Literal_Type return_type) {
        this.return_type = return_type;
        return this;
    }

    Function_Definition@ fmt(string format_string) {
        format = format_string;
        return this;
    }

    Function_Definition@ name(string name) {
        this.function_name = name;
        return this;
    }

    Function_Definition@ category(Function_Category function_category) {
        this.function_category = function_category;
        return this;
    }

    Function_Definition@ list_name(string pretty_name) {
        this.pretty_name = pretty_name;
        return this;
    }
}

class Api_Builder {
    array<Function_Definition@>@ functions = {};
    array<Event_Definition@>@ events = {};

    Api_Builder() {
        events.resize(EVENT_LAST);
    }

    Function_Definition@ func(string name, Native_Function_Executor@ native_executor) {
        Function_Definition instance;
        instance.name(name);
        instance.returns(LITERAL_TYPE_VOID);
        instance.native = true;
        @instance.native_executor = native_executor;

        functions.insertLast(instance);

        return instance;
    }

    Function_Definition@ func(string name, array<Expression@>@ user_code) {
        Function_Definition instance;
        instance.name(name);
        instance.returns(LITERAL_TYPE_VOID);
        instance.native = false;
        @instance.user_code = user_code;

        functions.insertLast(instance);

        return instance;
    }

    Event_Definition@ event(Event_Type event_type) {
        Event_Definition instance;
        instance.type = event_type;

        @events[event_type] = instance;

        return instance;
    }
}

Function_Definition@ convert_trigger_to_function_definition(Trigger@ trigger) {
    Function_Definition result;

    Event_Definition@ trigger_event = state.native_events[trigger.event_type];

    for (uint variable_index = 0; variable_index < trigger_event.variable_types.length(); variable_index++) {
        Literal_Type variable_type = trigger_event.variable_types[variable_index];
        string variable_name = trigger_event.variable_names[variable_index]; 

        result.takes(variable_type, variable_name);
    }

    uint total_conditions = trigger.conditions.length();

    if (total_conditions == 0) {
        result.user_code = trigger.actions;
        return result;
    }

    Expression@ assembled_condition = trigger.conditions[0];

    if (total_conditions > 1) {
        for (uint condition_index = 1; condition_index < total_conditions; condition_index++) {
            assembled_condition = make_op_expr(OPERATOR_AND, assembled_condition, trigger.conditions[condition_index]);
        }
    }

    Expression@ condition_wrapper = make_if(assembled_condition, trigger.actions);

    return result;
}

void try_handle_event_from_message(string message) {
    array<string> words = split_into_words_and_quoted_pieces(message);

    if (words.length() == 0) {
        return;
    }

    string event_type_as_string = words[0];
    Event_Type event_type = serializeable_string_to_event_type(event_type_as_string);

    if (event_type == EVENT_LAST) {
        Log(error, "Unrecognized event type from string " + event_type_as_string);
        return;
    }

    Parser_State event_parser;
    event_parser.words = words;
    event_parser.current_word = 1;

    array<Memory_Cell@> parameters;

    parse_parameters_for_event_type(event_type, event_parser, parameters);
    try_run_triggers_for_event_type(event_type, parameters);
}

void parse_parameters_for_event_type(Event_Type event_type, Parser_State@ parser_state, array<Memory_Cell@>@ parameters) {
    switch (event_type) {
        case EVENT_CHARACTER_ENTERS_REGION: {
            string character_id_as_string = parser_next_word(parser_state);
            string hotspot_id_as_string = parser_next_word(parser_state);

            string character_name = ReadObjectFromID(atoi(character_id_as_string)).GetName();

            parameters.insertLast(make_memory_cell(character_name));

            break;
        }
    }
}

void try_run_triggers_for_event_type(Event_Type event_type, array<Memory_Cell@>@ parameters) {
    for (uint trigger_index = 0; trigger_index < state.triggers.length(); trigger_index++) {
        if (state.triggers[trigger_index].event_type == event_type) {
            run_trigger(state.triggers[trigger_index], parameters);
        }
    }
}

Thread@ run_trigger(Trigger@ trigger, array<Memory_Cell@>@ parameters) {
    Log(info, "Running trigger \"" + trigger.name + "\"");

    auto time = GetPerformanceCounter();

    Function_Definition@ trigger_function = convert_trigger_to_function_definition(trigger);
    Translation_Context@ context = translate_expressions_into_bytecode(trigger_function);

    Log(info, "Translation :: " + context.expressions_translated + " expressions translated, took " + get_time_delta_in_ms(time) + "ms");

    Thread@ thread = make_thread(vm);
    set_thread_up_from_translation_context(thread, context);

    for (uint parameter_index = 0; parameter_index < parameters.length(); parameter_index++) {
        uint slot = parameters.length() - parameter_index - 1;
        thread_stack_store(thread, slot, parameters[parameter_index]);

        Log(info, "Storing :: " + memory_cell_to_string(parameters[parameter_index]) + " at " + slot);
    }

    vm.threads.insertLast(thread);

    return thread;
}

Api_Builder@ build_api() {
    Api_Builder builder;

    builder
        .event(EVENT_CHARACTER_ENTERS_REGION)
        .list_name("Character enters a region")
        .defines("Entering Character", LITERAL_TYPE_STRING)
        .fmt("A character enters a region");

    builder
        .func("log1", api::log1)
        .list_name("Test function 1")
        .fmt("Log 1");

    builder
        .func("log2", api::log2)
        .list_name("Test function 2")
        .fmt("Test function 2");

    builder
        .func("print", api::print)
        .list_name("Print a number to console")
        .fmt("Print {} to console")
        .takes(LITERAL_TYPE_NUMBER);

    builder
        .func("print_str", api::print_str)
        .list_name("Display text")
        .fmt("Display {}")
        .takes(LITERAL_TYPE_STRING);

    builder
        .func("rnd", api::rnd)
        .list_name("Random number")
        .fmt("Random number")
        .returns(LITERAL_TYPE_NUMBER);

    builder
        .func("get_game_time", api::get_game_time)
        .list_name("Current game time")
        .fmt("Current game time")
        .returns(LITERAL_TYPE_NUMBER);

    builder
        .func("dialogue_say", api::dialogue_say)
        .fmt("> {}: {}")
        .category(CATEGORY_DIALOGUE)
        .takes(LITERAL_TYPE_STRING)
        .takes(LITERAL_TYPE_STRING);

    builder
        .func("start_dialogue", api::start_dialogue)
        .fmt("Show dialogue screen");

    builder
        .func("end_dialogue", api::end_dialogue)
        .fmt("Hide dialogue screen");

    builder
        .func("is_in_dialogue", api::is_in_dialogue)
        .fmt("Is waiting for a dialogue line to end");

    builder
        .func("sleep", api::sleep)
        .category(CATEGORY_WAIT)
        .fmt("Sleep until the next update");

    // Userland functions

    builder
        .func("wait_until_dialogue_line_is_complete", api::wait_until_dialogue_line_is_complete())
        .category(CATEGORY_WAIT)
        .fmt("Wait for the dialogue line to end");

    builder
        .func("wait", api::wait())
        .fmt("Wait for {} seconds")
        .takes(LITERAL_TYPE_NUMBER, "seconds")
        .category(CATEGORY_WAIT);

    builder
        .func("sub_test", api::sub_func())
        .fmt("Math: {} - {}")
        .takes(LITERAL_TYPE_NUMBER, "left")
        .takes(LITERAL_TYPE_NUMBER, "right")
        .returns(LITERAL_TYPE_NUMBER)
        .category(CATEGORY_WAIT);

    return builder;
}

namespace environment {
    bool is_in_dialogue_mode = false;

    void update() {
        if (is_in_dialogue_mode) {
            dialogue::update();
        }
    }

    void draw() {
        if (is_in_dialogue_mode) {
            dialogue::draw_ui();
        }
    }

    void draw2() {
        if (is_in_dialogue_mode) {
            dialogue::draw_text();
        }
    }
}

namespace api {
    void dialogue_say(Native_Call_Context@ ctx) {
        string who = ctx.take_string();
        string what = ctx.take_string();

        dialogue::say(who, what);
    }

    void start_dialogue(Native_Call_Context@ ctx) {
        environment::is_in_dialogue_mode = true;

        dialogue::reset_ui();
    }

    void end_dialogue(Native_Call_Context@ ctx) {
        environment::is_in_dialogue_mode = false;
    }

    void is_in_dialogue(Native_Call_Context@ ctx) {
        ctx.return_bool(dialogue::is_waiting_for_a_line_to_end);
    }

    void log1(Native_Call_Context@ ctx) {
        Log(info, "log1");
    }

    void log2(Native_Call_Context@ ctx) {
        Log(info, "log2");
    }

    void sleep(Native_Call_Context@ ctx) {
        ctx.thread_sleep();
    }

    void print(Native_Call_Context@ ctx) {
        float value = ctx.take_number();

        Log(info, "print: " + value);
    }

    void rnd(Native_Call_Context@ ctx) {
        ctx.return_number(rand());
    }

    void print_str(Native_Call_Context@ ctx) {
        string value = ctx.take_string();

        Log(info, "print_str: " + value);
    }

    void get_game_time(Native_Call_Context@ ctx) {
        ctx.return_number(the_time);
    }

    array<Expression@>@ wait_until_dialogue_line_is_complete() {
        return array<Expression@> = {
            make_while(make_function_call("is_in_dialogue"), array<Expression@> = {
                make_function_call("sleep")
            })
        };
    }

    array<Expression@>@ wait() {
        Expression@ get_time = make_function_call("get_game_time");
        Expression@ target_time = make_op_expr(OPERATOR_ADD, get_time, make_ident("seconds"));
        Expression@ target_time_declaration = make_declaration(LITERAL_TYPE_NUMBER, "target_time", target_time);
        Expression@ condition = make_op_expr(OPERATOR_LT, get_time, make_ident("target_time"));

        return array<Expression@> = {
            target_time_declaration,
            make_while(condition, array<Expression@> = {
                make_function_call("sleep")
            })
        };
    }

    array<Expression@>@ sub_func() {
        return array<Expression@> = {
            make_return(make_op_expr(OPERATOR_SUB, make_ident("left"), make_ident("right")))
        };
    }
}