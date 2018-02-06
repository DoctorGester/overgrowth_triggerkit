enum Instruction_Type {
    INSTRUCTION_TYPE_ADD,
    INSTRUCTION_TYPE_MUL,
    INSTRUCTION_TYPE_SUB,
    INSTRUCTION_TYPE_DIV,

    INSTRUCTION_TYPE_DUP,
    INSTRUCTION_TYPE_INC,
    INSTRUCTION_TYPE_DEC,
    INSTRUCTION_TYPE_NOT,

    INSTRUCTION_TYPE_LOAD_CONST,

    INSTRUCTION_TYPE_CONST_0,
    INSTRUCTION_TYPE_CONST_1,

    INSTRUCTION_TYPE_LOAD,
    INSTRUCTION_TYPE_STORE,

    INSTRUCTION_TYPE_ARRAY_LOAD,
    INSTRUCTION_TYPE_ARRAY_STORE,

    INSTRUCTION_TYPE_EQ_ZERO,
    INSTRUCTION_TYPE_EQ_NOT_ZERO,
    INSTRUCTION_TYPE_EQ,
    INSTRUCTION_TYPE_LT,
    INSTRUCTION_TYPE_GT,

    INSTRUCTION_TYPE_POP,

    INSTRUCTION_TYPE_NATIVE_CALL,
    INSTRUCTION_TYPE_JMP,
    INSTRUCTION_TYPE_JMP_IF
}

const uint MAX_STACK_SIZE = 256;

class Instruction {
    Instruction_Type type;

    int int_arg;
}

class Virtual_Machine {
    array<Thread> threads;

    bool is_in_debugger_mode = false;
}

class Thread_Step_Details {
    bool should_continue;
    bool has_finished_working;
}

// Could have easily been a union, gg
class Memory_Cell {
    string string_value;
    float number_value;
    array<string> string_array_value;
    array<float> number_array_value;
}

class Thread {
    Virtual_Machine@ vm;

    array<Native_Function_Executor@>@ function_executors;
    array<Memory_Cell>@ constant_pool;

    array<Memory_Cell> stack;
    array<Instruction> code;
    uint stack_top = 0;
    uint current_instruction = 0;
    uint stack_offset = 0;

    bool has_finished_working;
    bool is_paused;
    float is_waiting_until;

    int instructions_executed = 0;
}

class Native_Call_Context {
    private Thread@ thread;

    Native_Call_Context(Thread@ thread) {
        @this.thread = thread;
    }

    void thread_sleep_for(float time) {
        this.thread.is_paused = true;
        this.thread.is_waiting_until = the_time + time;
    }

    float take_number() {
        return thread_stack_pop(this.thread).number_value;
    }

    string take_string() {
        return thread_stack_pop(this.thread).string_value;
    }

    void return_number(float value) {
        thread_stack_push_number(this.thread, value);
    }
}

Virtual_Machine@ make_vm() {
    Virtual_Machine vm;

    return vm;
}

Thread@ make_thread(Virtual_Machine@ vm) {
    Thread thread;

    @thread.vm = vm;
    thread.stack.resize(MAX_STACK_SIZE);

    return thread;
}

void set_thread_up_from_translation_context(Thread@ thread, Translation_Context@ translation_context) {
    // TODO temporary code reserving space for locals
    for (uint i = 0; i < translation_context.local_variable_index; i++) {
        thread.code.insertAt(0, make_instruction(INSTRUCTION_TYPE_CONST_0));
    }

    for (uint instruction_index = 0; instruction_index < translation_context.code.length(); instruction_index++) {
        thread.code.insertLast(translation_context.code[instruction_index]);
    }

    @thread.function_executors = translation_context.function_executors;
    @thread.constant_pool = translation_context.constants;
    thread.stack_offset = translation_context.local_variable_index;
}

string instruction_to_string(Instruction@ instruction) {
    switch (instruction.type) {
        case INSTRUCTION_TYPE_ADD: return "ADD";

        case INSTRUCTION_TYPE_CONST_0: return "CONST 0";
        case INSTRUCTION_TYPE_CONST_1: return "CONST 1";
        case INSTRUCTION_TYPE_POP: return "POP";

        case INSTRUCTION_TYPE_LOAD_CONST: return "LOAD CONST " + instruction.int_arg;
        case INSTRUCTION_TYPE_LOAD: return "LOAD " + instruction.int_arg;
        case INSTRUCTION_TYPE_STORE: return "STORE " + instruction.int_arg;

        case INSTRUCTION_TYPE_EQ: return "EQ";
        case INSTRUCTION_TYPE_EQ_ZERO: return "EQ ZERO";
        case INSTRUCTION_TYPE_EQ_NOT_ZERO: return "EQ NOT ZERO";
        case INSTRUCTION_TYPE_LT: return "LT";

        case INSTRUCTION_TYPE_NOT: return "NOT";
        case INSTRUCTION_TYPE_DUP: return "DUP";
        case INSTRUCTION_TYPE_INC: return "INC";
        case INSTRUCTION_TYPE_DEC: return "DEC";

        case INSTRUCTION_TYPE_JMP: return "JMP " + instruction.int_arg;
        case INSTRUCTION_TYPE_JMP_IF: return "JMP_IF " + instruction.int_arg;
        case INSTRUCTION_TYPE_NATIVE_CALL: return "NATIVE CALL " + instruction.int_arg;
    }

    return instruction.type + "";
}

int get_relative_code_location(uint to, array<Instruction>@ target) {
    return to - target.length();
}

Memory_Cell@ thread_stack_pop(Thread@ thread) {
    if (thread.stack_top == 0) {
        PrintCallstack();
        assert(false);
    }

    Memory_Cell@ value = thread.stack[--thread.stack_top];

    return value;
}

Memory_Cell@ thread_stack_peek(Thread@ thread) {
    if (thread.stack_top == 0) {
        PrintCallstack();
        assert(false);
    }

    return thread.stack[thread.stack_top - 1];
}

void thread_stack_push_number(Thread@ thread, float number) {
    thread.stack[thread.stack_top++].number_value = number;
}

// TODO doesn't support a lot of other stuff
void thread_stack_push(Thread@ thread, Memory_Cell@ value) {
    Memory_Cell@ cell = thread.stack[thread.stack_top++];
    cell.number_value = value.number_value;
    cell.string_value = value.string_value;
    cell.number_array_value = value.number_array_value;
    cell.string_array_value = value.string_array_value;
}

void thread_stack_store(Thread@ thread, uint in_slot, Memory_Cell@ value) {
    Memory_Cell@ cell = thread.stack[in_slot];
    cell.number_value = value.number_value;
}

float bool_to_number(bool bool_value) {
    return bool_value ? 1 : 0;
}

void execute_current_instruction(Thread@ thread) {
    Instruction@ instruction = thread.code[thread.current_instruction];
    array<Memory_Cell>@ stack = thread.stack;

    // Log(info, instruction_to_string(instruction));

    switch (instruction.type) {
        case INSTRUCTION_TYPE_CONST_0: {
            thread_stack_push_number(thread, 0);
            break;
        }

        case INSTRUCTION_TYPE_CONST_1: {
            thread_stack_push_number(thread, 1);
            break;
        }

        case INSTRUCTION_TYPE_LOAD_CONST: {
            thread_stack_push(thread, thread.constant_pool[instruction.int_arg]);

            break;
        }

        case INSTRUCTION_TYPE_DUP: {
            thread_stack_push(thread, thread_stack_peek(thread));

            break;
        }

        case INSTRUCTION_TYPE_INC: {
            float value = thread_stack_pop(thread).number_value;
            thread_stack_push_number(thread, value + 1);

            break;
        }

        case INSTRUCTION_TYPE_DEC: {
            float value = thread_stack_pop(thread).number_value;
            thread_stack_push_number(thread, value - 1);

            break;
        }

        case INSTRUCTION_TYPE_NOT: {
            bool value = thread_stack_pop(thread).number_value != 0;
            thread_stack_push_number(thread, bool_to_number(!value));

            break;
        }

        case INSTRUCTION_TYPE_EQ_ZERO: {
            float value = thread_stack_pop(thread).number_value;

            thread_stack_push_number(thread, bool_to_number(value == 0));

            break;
        }

        case INSTRUCTION_TYPE_EQ_NOT_ZERO: {
            float value = thread_stack_pop(thread).number_value;

            thread_stack_push_number(thread, bool_to_number(value != 0));

            break;
        }

        case INSTRUCTION_TYPE_EQ: {
            float left = thread_stack_pop(thread).number_value;
            float right = thread_stack_pop(thread).number_value;

            thread_stack_push_number(thread, bool_to_number(left == right));

            break;
        }

        case INSTRUCTION_TYPE_LT: {
            float left = thread_stack_pop(thread).number_value;
            float right = thread_stack_pop(thread).number_value;

            thread_stack_push_number(thread, bool_to_number(right < left));

            break;
        }

        case INSTRUCTION_TYPE_GT: {
            float left = thread_stack_pop(thread).number_value;
            float right = thread_stack_pop(thread).number_value;

            thread_stack_push_number(thread, bool_to_number(right > left));

            break;
        }

        case INSTRUCTION_TYPE_LOAD: {
            thread_stack_push_number(thread, stack[instruction.int_arg].number_value);

            break;
        }

        case INSTRUCTION_TYPE_STORE: {
            thread_stack_store(thread, instruction.int_arg, thread_stack_pop(thread));

            break;
        }

        case INSTRUCTION_TYPE_JMP: {
            thread.current_instruction += instruction.int_arg;

            break;
        }

        case INSTRUCTION_TYPE_JMP_IF: {
            bool top = thread_stack_pop(thread).number_value != 0;

            if (top) {
                thread.current_instruction += instruction.int_arg;
            }

            break;
        }

        case INSTRUCTION_TYPE_ADD: {
            float left = thread_stack_pop(thread).number_value;
            float right = thread_stack_pop(thread).number_value;

            thread_stack_push_number(thread, left + right);

            break;
        }

        case INSTRUCTION_TYPE_SUB: {
            float left = thread_stack_pop(thread).number_value;
            float right = thread_stack_pop(thread).number_value;

            thread_stack_push_number(thread, right - left);

            break;
        }

        case INSTRUCTION_TYPE_NATIVE_CALL: {
            Native_Call_Context context(thread);

            thread.function_executors[instruction.int_arg](context);

            break;
        }

        default: {
            Log(error, "Skipping instruction " + instruction_to_string(instruction));
            break;
        }
    }
}

bool advance_thread_instruction_pointer_and_check_if_it_finished_working(Thread@ thread) {
    thread.current_instruction++;

    return thread.current_instruction == thread.code.length();
}

void dump_thread_stack(Thread@ thread) {
    Log(error, "Thread memory stack");

    for (uint cell_index = 0; cell_index < thread.stack_top; cell_index++) {
        Log(info, cell_index + ": " + memory_cell_to_string(thread.stack[cell_index]));
    }
}

void exhaust_thread_stack(Thread@ thread) {
    for (uint i = 0; i < thread.stack_offset; i++) {
        thread_stack_pop(thread);
    }
}

void thread_step_forward(Thread@ thread, Thread_Step_Details@ details) {
    uint previous_instruction_index = thread.current_instruction;

    execute_current_instruction(thread);

    bool has_advanced_during_the_execution = previous_instruction_index != thread.current_instruction; // TODO dirty, should return a struct from execute_...
    bool has_finished_working = has_advanced_during_the_execution ? 
        thread.current_instruction == thread.code.length() : // TODO eugh! Condition hardcoding
        advance_thread_instruction_pointer_and_check_if_it_finished_working(thread);

    thread.instructions_executed++;

    details.has_finished_working = has_finished_working;
    details.should_continue = !thread.is_paused;
}

void update_vm_state(Virtual_Machine@ virtual_machine) {
    Thread_Step_Details details;

    for (uint thread_index = 0; thread_index < virtual_machine.threads.length(); thread_index++) {
        Thread@ thread = virtual_machine.threads[thread_index];

        if (thread.is_paused) {
            if (thread.is_waiting_until <= the_time) {
                thread.is_paused = false;
            }
        }
            
        if (!thread.is_paused) {
            while (true) {
                thread_step_forward(thread, @details);

                if (details.has_finished_working) {
                    Log(info, "Thread finished working :: Executed " + thread.instructions_executed + " instructions");

                    exhaust_thread_stack(thread);

                    if (thread.stack_top > 0) {
                        dump_thread_stack(thread);
                    }
                    
                    virtual_machine.threads.removeAt(thread_index);
                    thread_index--;

                    break;
                }

                if (!details.should_continue) {
                    break;
                }
            }
        }
    }
}