; Multiply and divide by 2 in a loop
mov $0, 1 ; initial value
mov $1, 2 ; multiplier
mov $2, 0xff_ff_ff_ff ; max value
mov $3, 1 ; cycles to sleep

psh $0 ; Push initial value to the stack

; multiply loop
multiply:
    psh $1 ; Push multiplier
    mul ; multiply top 2 values on the stack
    out %-1 ; print result
    slp $3 ; sleep
    ifge %-1, $2, divide ; if result is greater or equal than max value, jump to divide loop
    jmp multiply ; else repeat multiply cycle

; divide loop
divide:
    psh $1 ; Push multiplier (or divisor)
    idiv ; divide top 2 values on the stack
    out %-1 ; print result
    slp $3 ; sleep
    ifle %-1, $0, dump ; if result is less or equal than 0, jump to multiply loop
    jmp divide ; else repeat divide cycle

; dump stack and register, then return to multuply loop
dump:
    ;dmp ; dump stack
    jmp multiply