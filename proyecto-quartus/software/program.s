    .global _start
    .text

@ ============================================================
@ Programa de prueba: Integración PS/2 + VRAM
@ ============================================================
@ Lee scancodes del teclado PS/2 y los muestra en la pantalla VGA
@ Los scancodes se escriben en formato hexadecimal en VRAM
@ ============================================================

_start:
    @ Inicializar punteros base
    LDR     R4, =0x20000000        @ Base de registros PS/2
    LDR     R5, =0x30000000        @ Base de VRAM

    @ Escribir título "PS/2 TEST" en fila 0
    MOV     R10, R5                @ R10 = puntero VRAM (0x30000000)
    
    MOV     R7, #0x50              @ 'P'
    STR     R7, [R10]
    ADD     R10, R10, #4
    MOV     R7, #0x53              @ 'S'
    STR     R7, [R10]
    ADD     R10, R10, #4
    MOV     R7, #0x32              @ '2'
    STR     R7, [R10]
    ADD     R10, R10, #4
    MOV     R7, #0x20              @ ' '
    STR     R7, [R10]
    ADD     R10, R10, #4
    MOV     R7, #0x54              @ 'T'
    STR     R7, [R10]
    ADD     R10, R10, #4
    MOV     R7, #0x45              @ 'E'
    STR     R7, [R10]
    ADD     R10, R10, #4
    MOV     R7, #0x53              @ 'S'
    STR     R7, [R10]
    ADD     R10, R10, #4
    MOV     R7, #0x54              @ 'T'
    STR     R7, [R10]
    ADD     R10, R10, #4

    @ Escribir "KEY: " en fila 2 (offset 80 = 40*2)
    ADD     R10, R5, #320          @ R10 = 0x30000000 + 320 bytes (fila 2)
    
    MOV     R7, #0x4B              @ 'K'
    STR     R7, [R10]
    ADD     R10, R10, #4
    MOV     R7, #0x45              @ 'E'
    STR     R7, [R10]
    ADD     R10, R10, #4
    MOV     R7, #0x59              @ 'Y'
    STR     R7, [R10]
    ADD     R10, R10, #4
    MOV     R7, #0x3A              @ ':'
    STR     R7, [R10]
    ADD     R10, R10, #4
    MOV     R7, #0x20              @ ' '
    STR     R7, [R10]
    ADD     R10, R10, #4

    @ R10 ahora apunta donde escribir el scancode en hex

@ ============================================================
@ Loop principal: polling de PS/2
@ ============================================================
main_loop:
    @ Leer PS2_STATUS (0x20000004)
    LDR     R1, [R4, #4]           @ R1 = PS2_STATUS
    AND     R2, R1, #1             @ R2 = bit[0] = new_data
    CMP     R2, #0
    BEQ     main_loop              @ Si no hay datos nuevos, seguir polling

    @ Hay nuevo scancode disponible
    @ Leer PS2_DATA (0x20000000)
    LDR     R3, [R4, #0]           @ R3 = scancode (8 bits en [7:0])
    AND     R3, R3, #0xFF          @ Asegurar solo 8 bits

    @ Convertir scancode a ASCII hexadecimal y mostrar
    @ Scancode = 0xAB → mostrar "AB" en pantalla
    
    @ Nibble alto (bits [7:4])
    MOV     R6, R3, LSR #4         @ R6 = nibble alto
    BL      nibble_to_ascii        @ R6 = ASCII del nibble
    STR     R6, [R10]              @ Escribir primer dígito hex
    ADD     R10, R10, #4           @ Avanzar puntero

    @ Nibble bajo (bits [3:0])
    AND     R6, R3, #0x0F          @ R6 = nibble bajo
    BL      nibble_to_ascii        @ R6 = ASCII del nibble
    STR     R6, [R10]              @ Escribir segundo dígito hex

    @ Esperar un poco para que sea visible (opcional)
    MOV     R8, #0x100000
delay_loop:
    SUBS    R8, R8, #1
    BNE     delay_loop

    @ Continuar polling
    B       main_loop


@ ============================================================
@ Subrutina: Convertir nibble (0-15) a ASCII hexadecimal
@ Entrada: R6 = nibble (0-15)
@ Salida:  R6 = ASCII ('0'-'9' o 'A'-'F')
@ ============================================================
nibble_to_ascii:
    CMP     R6, #10
    BLT     digit_0_9
    @ Es A-F (10-15)
    ADD     R6, R6, #0x37          @ 'A' = 0x41, 0x41 - 10 = 0x37
    MOV     PC, LR

digit_0_9:
    @ Es 0-9
    ADD     R6, R6, #0x30          @ '0' = 0x30
    MOV     PC, LR


    .ltorg



