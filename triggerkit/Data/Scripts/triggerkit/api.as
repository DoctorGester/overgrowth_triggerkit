funcdef void Native_Function_Executor(Native_Call_Context@ context);

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
    Literal_Type return_type = LITERAL_TYPE_VOID;
    string pretty_name;
    string format;
    string function_name;
    Native_Function_Executor@ native_executor;

    Function_Definition(){}

    Function_Definition@ takes(Literal_Type argument_type) {
        argument_types.insertLast(argument_type);
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
        @instance.native_executor = native_executor;

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

    // TODO parameter parsing
    try_run_triggers_for_event_type(event_type);
}

void try_run_triggers_for_event_type(Event_Type event_type) {
    for (uint trigger_index = 0; trigger_index < state.triggers.length(); trigger_index++) {
        if (state.triggers[trigger_index].event_type == event_type) {
            run_trigger(state.triggers[trigger_index]);
        }
    }
}

void run_trigger(Trigger@ trigger) {
    Log(info, "Running trigger \"" + trigger.name + "\"");

    auto time = GetPerformanceCounter();

    Translation_Context@ context = translate_expressions_into_bytecode(trigger.content);

    Log(info, "Translation :: " + context.expressions_translated + " expressions translated, took " + get_time_delta_in_ms(time) + "ms");

    Thread@ thread = make_thread(vm);
    set_thread_up_from_translation_context(thread, context);

    vm.threads.insertLast(thread);
}

Api_Builder@ build_api() {
    Api_Builder builder;

    builder
        .event(EVENT_CHARACTER_ENTERS_REGION)
        .list_name("Character enters a region")
        .defines("Entering Character", LITERAL_TYPE_CHARACTER)
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
        .fmt("Print %s to console")
        .takes(LITERAL_TYPE_NUMBER);

    builder
        .func("print_str", api::print_str)
        .list_name("Display text")
        .fmt("Display %s")
        .takes(LITERAL_TYPE_STRING);

    builder
        .func("rnd", api::rnd)
        .list_name("Random number")
        .fmt("Random number")
        .returns(LITERAL_TYPE_NUMBER);

    return builder;
}

namespace api {
    void log1(Native_Call_Context@ ctx) {
        Log(info, "log1");
    }

    void log2(Native_Call_Context@ ctx) {
        Log(info, "log2");
    }

    void wait(Native_Call_Context@ ctx) {
        ctx.thread_sleep_for(1.0);
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
}