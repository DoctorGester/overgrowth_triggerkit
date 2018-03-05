funcdef void Native_Function_Executor(Native_Call_Context@ context);

enum Function_Category {
    CATEGORY_OTHER,
    CATEGORY_DIALOGUE,
    CATEGORY_CAMERA,
    CATEGORY_WAIT
}

class Event_Definition {
    Event_Type type;
    string pretty_name;
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

    // Used internally
    uint call_site;
    bool anonymous = false;

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

class Operator_Definition {
    Literal_Type left_operand_type;
    Literal_Type right_operand_type;

    Operator_Group@ parent_group;

    Operator_Type operator_type;
    Native_Function_Executor@ native_executor;
    Instruction_Type instruction_type;
    bool represented_as_a_native_executor;
    bool invert_result;

    bool opEquals(Operator_Definition@ compare_to) {
        return
            compare_to.left_operand_type == left_operand_type &&
            compare_to.right_operand_type == right_operand_type &&
            compare_to.operator_type == operator_type;
    }
}

class Operator_Group {
    Literal_Type return_type;
    string name;
    array<Operator_Definition@> operators;

    private Operator_Definition@ current_instance;

    Operator_Group@ operator(Operator_Type operator_type) {
        @current_instance = Operator_Definition();
        @current_instance.parent_group = this;
        current_instance.operator_type = operator_type;
        current_instance.invert_result = false;

        operators.insertLast(current_instance);

        return this;
    }

    Operator_Group@ with_operands(Literal_Type left, Literal_Type right) {
        current_instance.left_operand_type = left;
        current_instance.right_operand_type = right;

        return this;
    }

    Operator_Group@ with_both_operands_as(Literal_Type type) {
        return with_operands(type, type);
    }


    Operator_Group@ as_native_executor(Native_Function_Executor@ native_executor) {
        @current_instance.native_executor = native_executor;
        current_instance.represented_as_a_native_executor = true;

        return this;
    }

    Operator_Group@ as_singular_instruction(Instruction_Type instruction_type) {
        current_instance.instruction_type = instruction_type;
        current_instance.represented_as_a_native_executor = false;

        return this;
    }

    Operator_Group@ invert_result() {
        current_instance.invert_result = true;

        return this;
    }
}

class Api_Builder {
    array<Function_Definition@>@ functions = {};
    array<Event_Definition@>@ events = {};
    array<Operator_Group@>@ operator_groups = {};

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

    Operator_Group@ operator_group(string name, Literal_Type return_type) {
        Operator_Group instance;
        instance.name = name;
        instance.return_type = return_type;

        operator_groups.insertLast(instance);

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

    for (uint condition_index = 1; condition_index < total_conditions; condition_index++) {
        @assembled_condition = make_op_expr(OPERATOR_AND, assembled_condition, trigger.conditions[condition_index]);
    }

    Expression@ condition_wrapper = make_if(assembled_condition, trigger.actions);

    @result.user_code = array<Expression@> = { condition_wrapper };

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

            int character_id = atoi(character_id_as_string);
            int region_id = atoi(hotspot_id_as_string);

            parameters.insertLast(make_memory_cell(character_id));
            parameters.insertLast(make_memory_cell(region_id));

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

    Thread@ thread = make_thread(vm);
    thread.current_instruction = trigger.function_entry_pointer;

    for (uint slot = 0; slot < parameters.length(); slot++) {
        thread_stack_store(thread, slot, parameters[slot]);

        Log(info, "Storing :: " + memory_cell_to_string(parameters[slot]) + " at " + slot);
    }

    vm.threads.insertLast(thread);

    return thread;
}

Api_Builder@ build_api() {
    Api_Builder api;

    // TODO types shorthand like Literal_Type type_number = LITERAL_TYPE_NUMBER?

    api
        .event(EVENT_LEVEL_START)
        .list_name("Level starts");

    api
        .event(EVENT_CHARACTER_ENTERS_REGION)
        .list_name("Character enters a region")
        .defines("Entering Character", LITERAL_TYPE_CHARACTER)
        .defines("Region being entered", LITERAL_TYPE_REGION);

    api
        .operator_group("Arithmetics", LITERAL_TYPE_NUMBER)
            .operator(OPERATOR_ADD)
            .with_both_operands_as(LITERAL_TYPE_NUMBER)
            .as_singular_instruction(INSTRUCTION_TYPE_ADD)

            .operator(OPERATOR_SUB)
            .with_both_operands_as(LITERAL_TYPE_NUMBER)
            .as_singular_instruction(INSTRUCTION_TYPE_SUB)

            .operator(OPERATOR_MUL)
            .with_both_operands_as(LITERAL_TYPE_NUMBER)
            .as_singular_instruction(INSTRUCTION_TYPE_MUL)

            .operator(OPERATOR_DIV)
            .with_both_operands_as(LITERAL_TYPE_NUMBER)
            .as_singular_instruction(INSTRUCTION_TYPE_DIV)
    ;

    api
        .operator_group("Vector arithmetics", LITERAL_TYPE_VECTOR_3)
            .operator(OPERATOR_ADD)
            .with_both_operands_as(LITERAL_TYPE_VECTOR_3)
            .as_native_executor(operators::vector_add)

            .operator(OPERATOR_SUB)
            .with_both_operands_as(LITERAL_TYPE_VECTOR_3)
            .as_native_executor(operators::vector_sub)
    ;

    api
        .operator_group("Boolean comparison", LITERAL_TYPE_BOOL)
            .operator(OPERATOR_EQ)
            .with_both_operands_as(LITERAL_TYPE_BOOL)
            .as_singular_instruction(INSTRUCTION_TYPE_EQ)

            .operator(OPERATOR_NEQ)
            .with_both_operands_as(LITERAL_TYPE_BOOL)
            .as_singular_instruction(INSTRUCTION_TYPE_NEQ)
    ;

    api
        .operator_group("Number comparison", LITERAL_TYPE_BOOL)
            .operator(OPERATOR_EQ)
            .with_both_operands_as(LITERAL_TYPE_NUMBER)
            .as_singular_instruction(INSTRUCTION_TYPE_EQ)

            .operator(OPERATOR_NEQ)
            .with_both_operands_as(LITERAL_TYPE_NUMBER)
            .as_singular_instruction(INSTRUCTION_TYPE_NEQ)

            .operator(OPERATOR_GT)
            .with_both_operands_as(LITERAL_TYPE_NUMBER)
            .as_singular_instruction(INSTRUCTION_TYPE_GT)

            .operator(OPERATOR_LT)
            .with_both_operands_as(LITERAL_TYPE_NUMBER)
            .as_singular_instruction(INSTRUCTION_TYPE_LT)

            .operator(OPERATOR_GE)
            .with_both_operands_as(LITERAL_TYPE_NUMBER)
            .as_singular_instruction(INSTRUCTION_TYPE_GE)

            .operator(OPERATOR_LE)
            .with_both_operands_as(LITERAL_TYPE_NUMBER)
            .as_singular_instruction(INSTRUCTION_TYPE_LE)
    ;

    api
        .operator_group("String comparison", LITERAL_TYPE_BOOL)
            .operator(OPERATOR_EQ)
            .with_both_operands_as(LITERAL_TYPE_STRING)
            .as_native_executor(operators::are_strings_equal)

            .operator(OPERATOR_NEQ)
            .with_both_operands_as(LITERAL_TYPE_STRING)
            .as_native_executor(operators::are_strings_equal)
            .invert_result()
    ;

    api
        .operator_group("String concatenation", LITERAL_TYPE_STRING)
            .operator(OPERATOR_ADD)
            .with_both_operands_as(LITERAL_TYPE_STRING)
            .as_native_executor(operators::concatenate_strings)
    ;

    define_handle_comparison_operators(api, "Character comparison", LITERAL_TYPE_CHARACTER);
    define_handle_comparison_operators(api, "Region comparison", LITERAL_TYPE_REGION);

    api
        .operator_group("And", LITERAL_TYPE_BOOL)
            .operator(OPERATOR_AND)
            .with_both_operands_as(LITERAL_TYPE_BOOL)
    ;

    api
        .operator_group("Or", LITERAL_TYPE_BOOL)
            .operator(OPERATOR_OR)
            .with_both_operands_as(LITERAL_TYPE_BOOL)
    ;

    api
        .func("do_nothing", api::do_nothing)
        .list_name("Do nothing")
        .fmt("Do nothing");

    api
        .func("fork", api::fork)
        .list_name("Fork")
        .fmt("Fork");

    api
        .func("print_str", api::print_str)
        .list_name("Display text")
        .fmt("Display {}")
        .takes(LITERAL_TYPE_STRING);

    api
        .func("rnd", api::rnd)
        .list_name("Random number")
        .fmt("Random number")
        .returns(LITERAL_TYPE_NUMBER);

    api
        .func("get_game_time", api::get_game_time)
        .list_name("Current game time")
        .fmt("Current game time")
        .returns(LITERAL_TYPE_NUMBER);

    api
        .func("dialogue_say", api::dialogue_say)
        .fmt("> {}: {}")
        .category(CATEGORY_DIALOGUE)
        .takes(LITERAL_TYPE_STRING)
        .takes(LITERAL_TYPE_STRING);

    api
        .func("start_dialogue", api::start_dialogue)
        .fmt("Show dialogue screen")
        .category(CATEGORY_DIALOGUE);

    api
        .func("end_dialogue", api::end_dialogue)
        .fmt("Hide dialogue screen")
        .category(CATEGORY_DIALOGUE);

    api
        .func("take_camera_control", api::take_camera_control)
        .fmt("Take camera control")
        .category(CATEGORY_CAMERA);

    api
        .func("release_camera_control", api::release_camera_control)
        .fmt("Release camera control")
        .category(CATEGORY_CAMERA);

    api
        .func("set_current_camera", api::set_current_camera)
        .fmt("Set camera to {}")
        .category(CATEGORY_CAMERA)
        .takes(LITERAL_TYPE_CAMERA);

    api
        .func("set_character_animation", api::set_character_animation)
        .fmt("Set {}'s animation to {}")
        .category(CATEGORY_DIALOGUE)
        .takes(LITERAL_TYPE_CHARACTER)
        .takes(LITERAL_TYPE_STRING);

    api
        .func("add_character_to_dialogue", api::add_character_to_dialogue)
        .fmt("Add {} to current dialogue")
        .category(CATEGORY_DIALOGUE)
        .takes(LITERAL_TYPE_CHARACTER);

    api
        .func("transition_camera", api::transition_camera)
        .fmt("Move camera from {} to {} over {} seconds")
        .category(CATEGORY_CAMERA)
        .takes(LITERAL_TYPE_CAMERA)
        .takes(LITERAL_TYPE_CAMERA)
        .takes(LITERAL_TYPE_NUMBER)
        .takes(LITERAL_TYPE_CAMERA_INTERPOLATION_TYPE);

    api
        .func("transition_camera_2", api::transition_camera)
        .fmt("Move camera from {} to {} over {} seconds with {} interpolation")
        .category(CATEGORY_CAMERA)
        .takes(LITERAL_TYPE_CAMERA)
        .takes(LITERAL_TYPE_CAMERA)
        .takes(LITERAL_TYPE_NUMBER)
        .takes(LITERAL_TYPE_CAMERA_INTERPOLATION_TYPE);

    api
        .func("end_dialogue", api::end_dialogue)
        .fmt("Hide dialogue screen");

    api
        .func("is_in_dialogue", api::is_in_dialogue)
        .returns(LITERAL_TYPE_BOOL)
        .fmt("Is waiting for a dialogue line to end");

    api
        .func("sleep", api::sleep)
        .category(CATEGORY_WAIT)
        .fmt("Sleep until the next update");

    api
        .func("set_camera_location", api::set_camera_location)
        .fmt("Camera {} -> {}")
        .takes(LITERAL_TYPE_VECTOR_3)
        .takes(LITERAL_TYPE_VECTOR_3);

    api
        .func("n2s", api::n2s)
        .list_name("Number to text")
        .fmt("{} as text")
        .takes(LITERAL_TYPE_NUMBER)
        .returns(LITERAL_TYPE_STRING);

    // Userland functions

    api
        .func("wait_until_dialogue_line_is_complete", api::wait_until_dialogue_line_is_complete())
        .category(CATEGORY_WAIT)
        .fmt("Wait for the dialogue line to end");

    api
        .func("wait", api::wait())
        .fmt("Wait for {} seconds")
        .takes(LITERAL_TYPE_NUMBER, "seconds")
        .category(CATEGORY_WAIT);

    api
        .func("move_camera_to", api::move_camera_to())
        .fmt("Move camera from {} to {}")
        .takes(LITERAL_TYPE_VECTOR_3, "from")
        .takes(LITERAL_TYPE_VECTOR_3, "to");

    return api;
}

void define_handle_comparison_operators(Api_Builder@ api, string group_name, Literal_Type handle_type) {
    api
        .operator_group(group_name, LITERAL_TYPE_BOOL)
            .operator(OPERATOR_EQ)
            .with_both_operands_as(handle_type)
            .as_native_executor(operators::are_handles_equal)

            .operator(OPERATOR_NEQ)
            .with_both_operands_as(handle_type)
            .as_native_executor(operators::are_handles_equal)
            .invert_result()
    ;
}

namespace environment {
    enum Camera_Mode {
        CAMERA_MODE_NONE,
        CAMERA_MODE_STATIC,
        CAMERA_MODE_TRAVELLING
    }

    bool is_in_dialogue_mode = false;
    bool has_camera_control = false;
    int current_static_camera = 0;
    Camera_Mode current_camera_mode = CAMERA_MODE_NONE;

    Interpolation_Type camera_interpolation_type;
    int camera_travelling_from;
    int camera_travelling_to;
    float camera_travel_time;
    float camera_travel_should_finish_at;

    array<int> dialogue_participants;

    void set_camera_location_and_rotation(vec3 position, quaternion rotation) {
        const float MPI = 3.14159265359;

        // From: Overgrowth/dialogue.as
        // Set camera euler angles from rotation matrix
        vec3 front = Mult(rotation, vec3(0, 0, 1));
        float y_rot = atan2(front.x, front.z) * 180.0f / MPI;
        float x_rot = asin(front[1]) * -180.0f / MPI;
        vec3 up = Mult(rotation, vec3(0, 1, 0));
        vec3 expected_right = normalize(cross(front, vec3(0, 1, 0)));
        vec3 expected_up = normalize(cross(expected_right, front));

        float z_rot = atan2(dot(up, expected_right), dot(up, expected_up)) * 180.0f / MPI;

        camera.SetPos(position);
        camera.SetXRotation(floor(x_rot * 100.0f + 0.5f) / 100.0f);
        camera.SetYRotation(floor(y_rot * 100.0f + 0.5f) / 100.0f);
        camera.SetZRotation(floor(z_rot * 100.0f + 0.5f) / 100.0f);
        camera.SetDistance(0.0f);
    }

    float ease_out_circular(float t) {
        t = t - 1;
        return sqrt(1 - t * t);
    }

    void update() {
        if (has_camera_control) {
            switch (current_camera_mode) {
                case CAMERA_MODE_STATIC: {
                    Object@ camera_object = ReadObjectFromID(current_static_camera);

                    set_camera_location_and_rotation(camera_object.GetTranslation(), camera_object.GetRotation());

                    break;
                }

                case CAMERA_MODE_TRAVELLING: {
                    float travel_progress = min(1.0f - (camera_travel_should_finish_at - the_time) / camera_travel_time, 1.0f);

                    if (camera_interpolation_type == INTERPOLATION_EASE_OUT_CIRCULAR) {
                        travel_progress = ease_out_circular(travel_progress);
                    }

                    Object@ camera_from = ReadObjectFromID(camera_travelling_from);
                    Object@ camera_to = ReadObjectFromID(camera_travelling_to);

                    quaternion new_rotation = mix(camera_from.GetRotation(), camera_to.GetRotation(), travel_progress);
                    vec3 new_position = mix(camera_from.GetTranslation(), camera_to.GetTranslation(), travel_progress);

                    set_camera_location_and_rotation(new_position, new_rotation);

                    break;
                }
            }
        }

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

namespace operators {
    void concatenate_strings(Native_Call_Context@ ctx) {
        string left = ctx.take_string();
        string right = ctx.take_string();

        // Operator order
        // TODO we could probably change that
        ctx.return_string(right + left);
    }

    void vector_add(Native_Call_Context@ ctx) {
        vec3 left = ctx.take_vec3();
        vec3 right = ctx.take_vec3();

        ctx.return_vec3(right + left);
    }

    void vector_sub(Native_Call_Context@ ctx) {
        vec3 left = ctx.take_vec3();
        vec3 right = ctx.take_vec3();

        ctx.return_vec3(right - left);
    }

    void are_strings_equal(Native_Call_Context@ ctx) {
        ctx.return_bool(ctx.take_string() == ctx.take_string());
    }

    void are_handles_equal(Native_Call_Context@ ctx) {
        ctx.return_bool(ctx.take_handle_id() == ctx.take_handle_id());
    }
}

namespace api {
    void do_nothing(Native_Call_Context@ ctx){
    }

    void fork(Native_Call_Context@ ctx){
        ctx.fork_to(uint(ctx.take_number()));
    }

    void n2s(Native_Call_Context@ ctx) {
        ctx.return_string(ctx.take_number() + "");
    }

    void dialogue_say(Native_Call_Context@ ctx) {
        string who = ctx.take_string();
        string what = ctx.take_string();

        dialogue::say(who, what);
    }

    void start_dialogue(Native_Call_Context@ ctx) {
        // TODO warning if is already in it

        environment::is_in_dialogue_mode = true;

        dialogue::reset_ui();
    }

    void end_dialogue(Native_Call_Context@ ctx) {
        // TODO warning if not in it

        environment::is_in_dialogue_mode = false;

        for (uint participant_index = 0; participant_index < environment::dialogue_participants.length(); participant_index++) {
            int participant_id = environment::dialogue_participants[participant_index];

            if (MovementObjectExists(participant_id)) {
                ReadCharacterID(participant_id).ReceiveScriptMessage("set_dialogue_control false");
            }
        }

        environment::dialogue_participants.resize(0);
    }

    void is_in_dialogue(Native_Call_Context@ ctx) {
        ctx.return_bool(dialogue::is_waiting_for_a_line_to_end);
    }

    void sleep(Native_Call_Context@ ctx) {
        ctx.thread_sleep();
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

    void take_camera_control(Native_Call_Context@ ctx) {
        // TODO warning if already has it

        if (!environment::has_camera_control) {
            environment::current_camera_mode = environment::CAMERA_MODE_NONE;
            environment::has_camera_control = true;
        }
    }

    void release_camera_control(Native_Call_Context@ ctx) {
        // TODO warning if has no camera control
        environment::has_camera_control = false;
    }

    void set_current_camera(Native_Call_Context@ ctx) {
        // TODO warning if has no camera control
        environment::current_camera_mode = environment::CAMERA_MODE_STATIC;
        environment::current_static_camera = ctx.take_handle_id();
    }

    void transition_camera(Native_Call_Context@ ctx) {
        // TODO warning if has no camera control
        environment::current_camera_mode = environment::CAMERA_MODE_TRAVELLING;
        environment::camera_travelling_from = ctx.take_handle_id();
        environment::camera_travelling_to = ctx.take_handle_id();
        environment::camera_travel_time = ctx.take_number();
        environment::camera_travel_should_finish_at = the_time + environment::camera_travel_time;
        environment::camera_interpolation_type = Interpolation_Type(ctx.take_enum_value());
    }

    // TODO maybe we could actually use this
    void set_camera_location(Native_Call_Context@ ctx) {
        vec3 position = ctx.take_vec3();
        vec3 look_at = ctx.take_vec3();

        /*environment::camera_position = position;
        environment::camera_look_at = look_at;*/
    }

    void add_character_to_dialogue(Native_Call_Context@ ctx) {
        int character_id = ctx.take_handle_id();

        // TODO error/warning if not in dialogue!
        // TODO warning if already added

        if (MovementObjectExists(character_id)) {
            Object@ character_as_object = ReadObjectFromID(character_id);
            MovementObject@ character = ReadCharacterID(character_id);
            vec3 position = character_as_object.GetTranslation();
            mat4 rotation = Mat4FromQuaternion(character_as_object.GetRotation());
            character.ReceiveScriptMessage("set_dialogue_control true");
            character.ReceiveScriptMessage("set_dialogue_position " + position.x + " " + position.y + " " + position.z);

            float rotZ = atan2(-rotation[8], rotation[0]);
            character.ReceiveScriptMessage("set_rotation "+ (rotZ * (180.0f / 3.14f)));
            //Log(info, (rotation.z * (180.0f / 3.14f) + " ROTATO"));
            environment::dialogue_participants.insertLast(character_id);
        } else {
            // TODO error handling
        }
    }

    void set_character_animation(Native_Call_Context@ ctx) {
        int character_id = ctx.take_handle_id();
        string animation = ctx.take_string();

        // TODO error/warning if not in dialogue!

        if (MovementObjectExists(character_id)) {
            ReadCharacterID(character_id).ReceiveScriptMessage("set_animation \"" + animation + "\"");
            ReadCharacterID(character_id).Execute("this_mo.SetAnimation(\"" + animation + "\", 3.0f, _ANM_FROM_START);");
        } else {
            // TODO error handling
        }
    }

    array<Expression@>@ wait_until_dialogue_line_is_complete() {
        // TODO error/warning if not in dialogue!

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

    array<Expression@> move_camera_to() {
        string code = """
            fork ( 
                declare Number "Start Time" call get_game_time ( ) 
                declare Vector3 "Current Location" $ Vector3 10 10 10
                while op < call get_game_time ( ) op + @ "Start Time" $ Number 5 ( 
                    assign "Current Location" op + @ "Current Location" $ Vector3 0.03 0 0 
                    call set_camera_location ( @ "Current Location" $ Vector3 0 0 0 ) 
                    call sleep ( ) 
                ) 
            )
        """;

        return parse_text_into_expression_array(code);
    }
}