funcdef void Native_Function_Executor(Native_Call_Context@ context);

enum Event_Type {
    EVENT_CHARACTER_ENTERS_REGION
}

class Event_Handler {
    Event_Type type;
    Trigger@ trigger;
}

class Function_Description {
    array<Literal_Type> argument_types = {};
    Literal_Type return_type = LITERAL_TYPE_VOID;
    string pretty_name;
    string format;
    string function_name;
    Native_Function_Executor@ native_executor;

    Function_Description(){}

    // int opCmp(Function_Description@ description) {
        // return prettyName.opCmp(description.name);
    // }

    Function_Description@ takes(Literal_Type argument_type) {
        argument_types.insertLast(argument_type);
        return this;
    }

    Function_Description@ returns(Literal_Type return_type) {
        this.return_type = return_type;
        return this;
    }

    Function_Description@ fmt(string format_string) {
        format = format_string;
        return this;
    }

    Function_Description@ name(string name) {
        this.function_name = name;
        return this;
    }

    Function_Description@ list_name(string pretty_name) {
        this.pretty_name = pretty_name;
        return this;
    }
}

class Api_Builder {
    dictionary@ api;
    array<Function_Description@>@ functions = {};

    Api_Builder(dictionary@ api) {
        @this.api = api;
    }

    Function_Description@ func(string name, Native_Function_Executor@ native_executor) {
        Function_Description instance;
        instance.name(name);
        instance.returns(LITERAL_TYPE_VOID);

        if (api !is null) {
            @api[name] = native_executor;
        }

        functions.insertLast(instance);

        return instance;
    }
}

void handle_event_from_message(string message) {

}

void fire_event_handler(Event_Handler@ handler) {
    Log(info, "Firing event handler of type: " + handler.type + " for trigger \"" + handler.trigger.name + "\"");

    auto time = GetPerformanceCounter();

    Translation_Context@ context = translate_expressions_into_bytecode(handler.trigger.content);

    Log(info, "Translation :: " + context.expressions_translated + " expressions translated, took " + get_time_delta_in_ms(time) + "ms");

    Thread@ thread = make_thread(vm);
    set_thread_up_from_translation_context(thread, context);

    vm.threads.insertLast(thread);
}

array<Function_Description@>@ populate_native_functions(dictionary@ api) {
    Api_Builder builder(api);

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

    return builder.functions;
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