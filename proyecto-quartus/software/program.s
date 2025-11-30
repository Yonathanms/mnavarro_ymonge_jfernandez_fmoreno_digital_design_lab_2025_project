    .global _start
    .text

@ Programa de la CALCULADORA (versión 0.1)
@ Convención en RAM (base = 0x1000_0000):
@   [R4, #0]  -> operando A (32 bits)
@   [R4, #4]  -> operando B (32 bits)
@   [R4, #8]  -> opcode de operación:
@                  0 = A + B
@                  1 = A - B
@                  2 = A * B   (usa mul_software)
@                  3 = A / B   (usa div_software)
@   [R4, #12] -> resultado principal (32 bits)
@   [R4, #16] -> extra (por ahora: residuo en división)

_start:
    @ R4 = base de RAM de datos (región 0x1000_0000)
    LDR     R4, =0x10000000

    @ --- Valores de prueba internos (por ahora) ---
    @ A = 12, B = 5, opcode = 0 (suma)
    MOV     R0, #12              @ A
    MOV     R1, #5               @ B
    STR     R0, [R4, #0]         @ RAM[A]
    STR     R1, [R4, #4]         @ RAM[B]

    MOV     R2, #0               @ opcode = 0 (suma)
    STR     R2, [R4, #8]

main_loop:
    @ Cargar A, B y opcode desde RAM
    LDR     R0, [R4, #0]         @ A
    LDR     R1, [R4, #4]         @ B
    LDR     R2, [R4, #8]         @ opcode

    @ Seleccionar operación según opcode
    CMP     R2, #0
    BEQ     do_add

    CMP     R2, #1
    BEQ     do_sub

    CMP     R2, #2
    BEQ     do_mul

    CMP     R2, #3
    BEQ     do_div

    @ Si opcode inválido, solo repetir
    B       main_loop

@ --------- Operaciones básicas ---------

do_add:
    ADD     R3, R0, R1           @ R3 = A + B
    STR     R3, [R4, #12]        @ resultado
    B       main_loop

do_sub:
    SUB     R3, R0, R1           @ R3 = A - B
    STR     R3, [R4, #12]
    B       main_loop

do_mul:
    @ mul_software: entrada R0=A, R1=B, salida R0 = A*B
    BL      mul_software
    STR     R0, [R4, #12]
    B       main_loop

do_div:
    @ div_software: entrada R0=A, R1=B
    @ salida: R0 = cociente, R1 = residuo
    CMP     R1, #0
    BEQ     main_loop            @ evitar división entre cero
    BL      div_software
    STR     R0, [R4, #12]        @ cociente
    STR     R1, [R4, #16]        @ residuo
    B       main_loop


@--------------------------------------------------------------
@ mul_software:
@   Entrada : R0 = multiplicando, R1 = multiplicador
@   Salida  : R0 = resultado (acumulador)
@   Regs usados: R2,R3,R5 (clobber)
@--------------------------------------------------------------
mul_software:
    MOV     R2, #0                 @ Acumulador
    MOV     R3, R1                 @ Copia del multiplicador

mul_loop:
    CMP     R3, #0
    BEQ     mul_fin
    AND     R5, R3, #1             @ bit LSB es 1?
    BEQ     mul_shift
    ADD     R2, R2, R0             @ Sumar multiplicando al acumulador
mul_shift:
    MOV     R0, R0, LSL #1         @ Desplazar multiplicando
    MOV     R3, R3, LSR #1         @ Desplazar multiplicador
    B       mul_loop

mul_fin:
    MOV     R0, R2
    MOV     PC, LR


@--------------------------------------------------------------
@ div_software:
@   Entrada : R0 = dividendo, R1 = divisor
@   Salida  : R0 = cociente, R1 = residuo
@   Regs usados: R2,R3 (clobber)
@--------------------------------------------------------------
div_software:
    CMP     R1, #0
    BEQ     div_div0               @ Divisor cero -> devolver 0/0
    MOV     R2, #0                 @ Cociente
    MOV     R3, R0                 @ Residuo parcial

div_loop:
    CMP     R3, R1
    BLT     div_fin
    SUB     R3, R3, R1
    ADD     R2, R2, #1
    B       div_loop

div_fin:
    MOV     R0, R2
    MOV     R1, R3
    MOV     PC, LR

div_div0:
    MOV     R0, #0
    MOV     R1, #0
    MOV     PC, LR


@--------------------------------------------------------------
@ bin_to_decimal:
@   Entrada : R0 = valor, R1 = puntero a buffer (palabras de 32 bits)
@   Salida  : ASCII en RAM, terminador 0, R0 restaurado
@   Regs usados: R2-R9 (clobber)
@--------------------------------------------------------------
bin_to_decimal:
    MOV     R8, R0                 @ Respaldar el valor original
    MOV     R3, R0                 @ Copia de trabajo
    MOV     R9, R1                 @ Puntero de salida
    LDR     R2, =powers_of_10      @ Tabla de potencias de 10
    MOV     R6, #0                 @ Flag de digitos escritos

bin_outer:
    LDR     R4, [R2]               @ Cargar potencia actual
    ADD     R2, R2, #4
    CMP     R4, #0
    BEQ     bin_no_more_const
    MOV     R5, #0                 @ Digito actual

bin_count:
    CMP     R3, R4
    BLT     bin_emit_check
    SUB     R3, R3, R4
    ADD     R5, R5, #1
    B       bin_count

bin_emit_check:
    CMP     R5, #0
    BNE     bin_emit
    CMP     R6, #0
    BEQ     bin_outer              @ Omitir ceros a la izquierda

bin_emit:
    ADD     R7, R5, #'0'
    STR     R7, [R9]
    ADD     R9, R9, #4
    MOV     R6, #1
    B       bin_outer

bin_no_more_const:
    CMP     R6, #0
    BNE     bin_store_terminator
    MOV     R7, #'0'               @ Valor era 0
    STR     R7, [R9]
    ADD     R9, R9, #4

bin_store_terminator:
    MOV     R7, #0
    STR     R7, [R9]
    MOV     R0, R8                 @ Restaurar valor
    MOV     PC, LR

    .data
    .align 4
powers_of_10:
    .word 1000000000
    .word 100000000
    .word 10000000
    .word 1000000
    .word 100000
    .word 10000
    .word 1000
    .word 100
    .word 10
    .word 1
    .word 0
