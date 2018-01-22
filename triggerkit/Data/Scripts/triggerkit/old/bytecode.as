namespace Bytecode {
    enum OpType {
        OP_PUSH,
        OP_POP,
        OP_CALL,
        OP_STORE,
        OP_JMP,
        OP_JMPIF
    }

    class OP {
        OpType type;
        int a;
        int b;
    }
}