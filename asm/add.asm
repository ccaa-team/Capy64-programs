mov $0, 0
mov $1, 0xff

loop:
    ife $0, $1, finish
    psh $0
    psh 1
    add

    mov $0, %-1
    pop 1

    jmp loop

finish:
    out $0