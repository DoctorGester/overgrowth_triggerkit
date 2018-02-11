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

    INSTRUCTION_TYPE_CALL,
    INSTRUCTION_TYPE_NATIVE_CALL,
    INSTRUCTION_TYPE_JMP,
    INSTRUCTION_TYPE_JMP_IF,
    INSTRUCTION_TYPE_RET,
    INSTRUCTION_TYPE_RETURN,

    INSTRUCTION_TYPE_RESERVE,

    INSTRUCTION_TYPE_LAST
}

const uint MAX_STACK_SIZE = 256;

funcdef void Instruction_Executor(Thread@ thread, Instruction@ instruction);

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
    uint current_call_frame_pointer = 0;
    uint current_instruction = 0;

    bool has_finished_working;
    bool is_paused;

    int instructions_executed = 0;
}

class Native_Call_Context {
    private Thread@ thread;

    Native_Call_Context(Thread@ thread) {
        @this.thread = thread;
    }

    void thread_sleep() {
        this.thread.is_paused = true;
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

    void return_bool(bool value) {
        thread_stack_push_number(this.thread, bool_to_number(value));
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
    for (uint instruction_index = 0; instruction_index < translation_context.code.length(); instruction_index++) {
        thread.code.insertLast(translation_context.code[instruction_index]);
    }

    @thread.function_executors = translation_context.function_executors;
    @thread.constant_pool = translation_context.constants;
    thread.current_instruction = translation_context.main_function_pointer;
}

string instruction_to_string(Instruction@ instruction) {
    switch (instruction.type) {
        case INSTRUCTION_TYPE_ADD: return "ADD";
        case INSTRUCTION_TYPE_SUB: return "SUB";

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
        case INSTRUCTION_TYPE_CALL: return "CALL " + instruction.int_arg;
        case INSTRUCTION_TYPE_RET: return "RET";
        case INSTRUCTION_TYPE_RETURN: return "RETURN";

        case INSTRUCTION_TYPE_RESERVE: return "RESERVE " + instruction.int_arg;
    }

    return instruction.type + "";
}

int get_relative_code_location(uint to, array<Instruction>@ target) {
    return to - target.length();
}

Memory_Cell@ thread_stack_pop(Thread@ thread) {
    /*if (thread.stack_top == 0) {
        PrintCallstack();
        assert(false);
    }*/

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
    cell.string_value = value.string_value;
}

float bool_to_number(bool bool_value) {
    return bool_value ? 1 : 0;
}

namespace instructions {
    void const_0(Thread@ thread, Instruction@ instruction) {
        thread_stack_push_number(thread, 0);
    }

    void const_1(Thread@ thread, Instruction@ instruction) {
        thread_stack_push_number(thread, 1);
    }

    void load_const(Thread@ thread, Instruction@ instruction) {
        thread_stack_push(thread, thread.constant_pool[instruction.int_arg]);
    }

    void dup(Thread@ thread, Instruction@ instruction) {
        thread_stack_push(thread, thread_stack_peek(thread));
    }

    void pop(Thread@ thread, Instruction@ instruction) {
        thread_stack_pop(thread);
    }

    void inc(Thread@ thread, Instruction@ instruction) {
        float value = thread_stack_pop(thread).number_value;
        thread_stack_push_number(thread, value + 1);
    }

    void dec(Thread@ thread, Instruction@ instruction) {
        float value = thread_stack_pop(thread).number_value;
        thread_stack_push_number(thread, value - 1);
    }

    void bnot(Thread@ thread, Instruction@ instruction) {
        bool value = thread_stack_pop(thread).number_value != 0;
        thread_stack_push_number(thread, bool_to_number(!value));
    }

    void eq_zero(Thread@ thread, Instruction@ instruction) {
        float value = thread_stack_pop(thread).number_value;

        thread_stack_push_number(thread, bool_to_number(value == 0));
    }

    void eq_not_zero(Thread@ thread, Instruction@ instruction) {
        float value = thread_stack_pop(thread).number_value;

        thread_stack_push_number(thread, bool_to_number(value != 0));
    }

    void eq(Thread@ thread, Instruction@ instruction) {
        float left = thread_stack_pop(thread).number_value;
        float right = thread_stack_pop(thread).number_value;

        thread_stack_push_number(thread, bool_to_number(left == right));
    }

    void lt(Thread@ thread, Instruction@ instruction) {
        float left = thread_stack_pop(thread).number_value;
        float right = thread_stack_pop(thread).number_value;

        thread_stack_push_number(thread, bool_to_number(right < left));
    }

    void gt(Thread@ thread, Instruction@ instruction) {
        float left = thread_stack_pop(thread).number_value;
        float right = thread_stack_pop(thread).number_value;

        thread_stack_push_number(thread, bool_to_number(right > left));
    }

    void load(Thread@ thread, Instruction@ instruction) {
        thread_stack_push(thread, thread.stack[thread.current_call_frame_pointer + instruction.int_arg]);
    }

    void store(Thread@ thread, Instruction@ instruction) {
        thread_stack_store(thread, thread.current_call_frame_pointer + instruction.int_arg, thread_stack_pop(thread));
    }

    void jmp(Thread@ thread, Instruction@ instruction) {
        thread.current_instruction += instruction.int_arg;
    }

    void jmp_if(Thread@ thread, Instruction@ instruction) {
        bool top = thread_stack_pop(thread).number_value != 0;

        if (top) {
            thread.current_instruction += instruction.int_arg;
        }
    }

    void call(Thread@ thread, Instruction@ instruction) {
        // TODO ugh! Dirty implicit constant
        uint function_pointer = uint(thread.constant_pool[instruction.int_arg].number_value);
        uint number_of_arguments = uint(thread.constant_pool[instruction.int_arg + 1].number_value);

        // Log(info, "CALL :: " + function_pointer + " :: " + number_of_arguments);

        array<Memory_Cell> arguments_array_copy;

        for (uint argument_index = 0; argument_index < number_of_arguments; argument_index++) {
            arguments_array_copy.insertLast(thread_stack_pop(thread));
        }

        thread_stack_push_number(thread, thread.current_call_frame_pointer);
        thread_stack_push_number(thread, thread.current_instruction + 1);

        thread.current_call_frame_pointer = thread.stack_top;
        thread.current_instruction = function_pointer;

        for (uint argument_index = 0; argument_index < number_of_arguments; argument_index++) {
            thread_stack_store(thread, thread.stack_top + argument_index, arguments_array_copy[argument_index]);
        }
    }

    void ret(Thread@ thread, Instruction@ instruction) {
        // Means we are returning from main
        if (thread.stack_top == 0) {
            return;
        }

        uint return_address = uint(thread_stack_pop(thread).number_value);
        uint call_frame_pointer = uint(thread_stack_pop(thread).number_value);

        thread.current_instruction = return_address;
        thread.current_call_frame_pointer = call_frame_pointer;
    }

    void ireturn(Thread@ thread, Instruction@ instruction) {
        Memory_Cell@ return_value = thread_stack_pop(thread);

        thread_stack_store(thread, thread.current_call_frame_pointer - 3, return_value);
    }

    void add(Thread@ thread, Instruction@ instruction) {
        float left = thread_stack_pop(thread).number_value;
        float right = thread_stack_pop(thread).number_value;

        thread_stack_push_number(thread, left + right);
    }

    void sub(Thread@ thread, Instruction@ instruction) {
        float left = thread_stack_pop(thread).number_value;
        float right = thread_stack_pop(thread).number_value;

        thread_stack_push_number(thread, right - left);
    }

    void native_call(Thread@ thread, Instruction@ instruction) {
        Native_Call_Context context(thread);

        thread.function_executors[instruction.int_arg](context);
    }

    void reserve(Thread@ thread, Instruction@ instruction) {
        thread.stack_top += instruction.int_arg;
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

void thread_step_forward(Thread@ thread, Thread_Step_Details@ details) {
    uint previous_instruction_index = thread.current_instruction;

    Instruction@ current_instruction = @thread.code[thread.current_instruction];
    instruction_executors[current_instruction.type](thread, current_instruction);

    // Log(info, instruction_to_string(current_instruction));

    bool has_advanced_during_the_execution = previous_instruction_index != thread.current_instruction; // TODO dirty, should return a struct from execute_...
    bool has_finished_working = has_advanced_during_the_execution ? 
        thread.current_instruction == thread.code.length() : // TODO eugh! Condition hardcoding
        advance_thread_instruction_pointer_and_check_if_it_finished_working(thread);

    thread.instructions_executed++;

    details.has_finished_working = has_finished_working;
    details.should_continue = !thread.is_paused;
}

array<Instruction_Executor@> instruction_executors;

// TODO should be called once!
void set_up_instruction_executors_temp() {
    instruction_executors.resize(INSTRUCTION_TYPE_LAST);

    @instruction_executors[INSTRUCTION_TYPE_ADD] = instructions::add;
    //@instruction_executors[INSTRUCTION_TYPE_MUL] = instructions::i_INSTRUCTION_TYPE_MUL;
    @instruction_executors[INSTRUCTION_TYPE_SUB] = instructions::sub;
    //@instruction_executors[INSTRUCTION_TYPE_DIV] = instructions::i_INSTRUCTION_TYPE_DIV;

    @instruction_executors[INSTRUCTION_TYPE_DUP] = instructions::dup;
    @instruction_executors[INSTRUCTION_TYPE_INC] = instructions::inc;
    @instruction_executors[INSTRUCTION_TYPE_DEC] = instructions::dec;
    @instruction_executors[INSTRUCTION_TYPE_NOT] = instructions::bnot;

    @instruction_executors[INSTRUCTION_TYPE_LOAD_CONST] = instructions::load_const;

    @instruction_executors[INSTRUCTION_TYPE_CONST_0] = instructions::const_0;
    @instruction_executors[INSTRUCTION_TYPE_CONST_1] = instructions::const_1;

    @instruction_executors[INSTRUCTION_TYPE_LOAD] = instructions::load;
    @instruction_executors[INSTRUCTION_TYPE_STORE] = instructions::store;

    //@instruction_executors[INSTRUCTION_TYPE_ARRAY_LOAD] = instructions::i_INSTRUCTION_TYPE_ARRAY_LOAD;
    //@instruction_executors[INSTRUCTION_TYPE_ARRAY_STORE] = instructions::i_INSTRUCTION_TYPE_ARRAY_STORE;

    @instruction_executors[INSTRUCTION_TYPE_EQ_ZERO] = instructions::eq_zero;
    @instruction_executors[INSTRUCTION_TYPE_EQ_NOT_ZERO] = instructions::eq_not_zero;
    @instruction_executors[INSTRUCTION_TYPE_EQ] = instructions::eq;
    @instruction_executors[INSTRUCTION_TYPE_LT] = instructions::lt;
    @instruction_executors[INSTRUCTION_TYPE_GT] = instructions::gt;

    @instruction_executors[INSTRUCTION_TYPE_POP] = instructions::pop;

    @instruction_executors[INSTRUCTION_TYPE_NATIVE_CALL] = instructions::native_call;
    @instruction_executors[INSTRUCTION_TYPE_JMP] = instructions::jmp;
    @instruction_executors[INSTRUCTION_TYPE_JMP_IF] = instructions::jmp_if;
    @instruction_executors[INSTRUCTION_TYPE_CALL] = instructions::call;
    @instruction_executors[INSTRUCTION_TYPE_RET] = instructions::ret;
    @instruction_executors[INSTRUCTION_TYPE_RETURN] = instructions::ireturn;

    @instruction_executors[INSTRUCTION_TYPE_RESERVE] = instructions::reserve;
}

void clean_up_instruction_executors_temp() {
    instruction_executors.resize(0);
}

void update_vm_state(Virtual_Machine@ virtual_machine) {
    Thread_Step_Details details;

    set_up_instruction_executors_temp();

    for (uint thread_index = 0; thread_index < virtual_machine.threads.length(); thread_index++) {
        Thread@ thread = virtual_machine.threads[thread_index];

        if (thread.is_paused) {
            thread.is_paused = false;
        } else {
            while (true) {
                thread_step_forward(thread, @details);

                if (details.has_finished_working) {
                    Log(info, "Thread finished working :: Executed " + thread.instructions_executed + " instructions");

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

    clean_up_instruction_executors_temp();
}