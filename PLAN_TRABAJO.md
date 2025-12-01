# Plan de Implementación: Calculadora ARMv4 32 bits con PS/2 y VGA

## Resumen Ejecutivo

**Objetivo**: Completar procesador ARMv4 uniciclo en DE10-Standard con calculadora de 7 operaciones (add, sub, mul, div, and, or, xor), entrada PS/2 y salida VGA.

**Estado Actual**: CPU funcional (80%), sin periféricos PS/2/VGA, sin programa de calculadora.

**Estrategia**: Desarrollo ágil enfocado en demo funcional (20-25 días), priorizando velocidad sobre robustez. Pruebas directas en hardware, testbenches solo para casos críticos.

---

## Decisiones Arquitecturales Principales

### 1. Software de operaciones + Sistema de memoria (ROM/RAM en .mif)

**Decisión principal**:  
Las operaciones complejas (MUL y DIV) se implementarán por **software en ensamblador ARMv4**, y el almacenamiento de instrucciones y datos se realizará mediante **memorias ROM y RAM inicializadas con archivos `.mif` en Quartus**.

### Algoritmos de multiplicación y división

Se usarán algoritmos simples e iterativos:

- **MUL (multiplicación)**: algoritmo shift-and-add (hasta 32 iteraciones)
- **DIV (división)**: resta iterativa sucesiva (hasta 32 iteraciones)
- **BIN2DEC**: Conversión binario→decimal (división por 10 iterativa)

### Uso de archivos `.mif` (ROM y RAM)

Se reemplaza la memoria de instrucciones hardcodeada por **IP Catalog de Quartus + archivos `.mif`**.

**Flujo de trabajo:**

```
Código ARMv4 → Ensamblador online → Código HEX
Código HEX → rom_data.mif / ram_data.mif
rom_data.mif / ram_data.mif → Quartus → FPGA
```

### ⚠️ Decisión CRÍTICA de memoria

ROM, RAM y VRAM tendrán:

- **32 bits de ancho**
- **1024 palabras de profundidad**

Por lo tanto:

```
1024 palabras = 2¹⁰ → 10 bits de dirección
```

🚨 **El bus de direcciones del CPU debe trabajar con 10 bits**

Cambios requeridos:

```verilog
// De:
[7:0] → 8 bits (256 palabras)

// A:
[9:0] → 10 bits (1024 palabras)

// ROM:
instr_addr = PC[11:2];  // 10 bits → 1024 instrucciones

// RAM:
data_addr = ALU_result[11:2];  // 10 bits
```

---

## 2. VGA: Renderer de Texto 8×16 con VRAM Dual-Port y Display Decimal

### Decisión

Salida VGA 640×480@60Hz en modo texto con:

- VRAM dual-port (1024 palabras × 32 bits)
- ROM de caracteres ASCII 8×16
- Conversión binario→decimal por software

### Arquitectura

```
CPU (write) → VRAM Puerto A (32-bit)
                    ↓
              VGA Controller (read) → ROM Fuente 8×16 → Monitor
                  Puerto B
```

- CPU solo escribe ASCII en VRAM
- VGA lee continuamente sin conflictos
- No afecta diseño uniciclo del procesador

### Especificación VRAM

**Módulo:** `vram_2puertos.v`

| Parámetro | Valor                         |
| --------- | ----------------------------- |
| Tipo      | RAM Dual-Port                 |
| Tamaño    | 1024 palabras × 32 bits (4KB) |
| Puerto A  | CPU write-only                |
| Puerto B  | VGA read-only                 |
| Formato   | [7:0] ASCII, [31:8] reservado |

**Mapeo memoria:**

```
Base: 0x3000_0000
Fin:  0x3000_0FFF
```

### Pantalla: 40 columnas × 25 filas

**Cálculo posición:**

```c
vram_index = (fila × 40) + columna
vram_addr = 0x30000000 + (vram_index × 4)
```

**Layout interfaz:**

```
ARMv4 Calculator
─────────────────
Operand 1: 1234567890
Operator : +
Operand 2: 9876543210
─────────────────
Result   : 11111111100

Status   : OK
Last Key : 5
```

| Fila | Contenido    | Offset |
| ---- | ------------ | ------ |
| 0    | Título       | 0x000  |
| 3    | Operando 1   | 0x140  |
| 4    | Operador     | 0x1E0  |
| 5    | Operando 2   | 0x280  |
| 7    | Resultado    | 0x3C0  |
| 9    | Status       | 0x500  |
| 10   | Última tecla | 0x5A0  |

### Renderizado

**ROM fuente:** 2KB (256 chars × 16 líneas × 8 bits)

**Pipeline:**

1. `char_row = y / 16`, `char_col = x / 8`
2. `ascii = VRAM[char_row × 40 + char_col]`
3. `pixel = ROM[ascii][y % 16][7 - (x % 8)]`

### Conversión Decimal

**Algoritmo (división por 10):**

```arm
; r0 = número binario → buffer ASCII
bin2dec:
    MOV r2, #10
loop:
    BL udiv              ; r0/10 → r0, resto→r3
    ADD r3, r3, #'0'     ; Dígito → ASCII
    STRB r3, [r1, #-1]!  ; Guardar
    CMP r0, #0
    BNE loop
```

**Ciclos:** ~60-120 según magnitud

### Reloj VGA

**Timing 640×480@60Hz:**

- Pixel clock: 25 MHz (división de 50MHz)
- H-total: 800 px (visible: 640)
- V-total: 525 líneas (visible: 480)

```verilog
always @(posedge clk_50MHz)
    clk_25MHz <= ~clk_25MHz;
```

### Ventajas

✅ Solo 4KB VRAM vs 300KB framebuffer  
✅ Compatible con pipeline uniciclo  
✅ Interfaz profesional tipo terminal  
✅ Escalable a modo gráfico futuro

---

## 3. PS/2: Receptor Básico con Scancodes

### Decisión

Periférico PS/2 independiente que expone scancodes al CPU mediante registros memory-mapped.  
**No existe conexión directa con RAM ni con VRAM.**

### Componentes

- Sincronizador cross-clock (double-flop)
- FSM receptora de 11 bits (start + 8 data + parity + stop)
- Registros memory-mapped (32 bits):
  - `0x2000_0000`: PS2_DATA (scancode en [7:0])
  - `0x2000_0004`: PS2_STATUS (bit0 = new_data, bit1 = error)

### Nota

El CPU lee PS2_DATA, lo traduce en software y escribe el carácter correspondiente en la VRAM.

---

## 4. Sistema de Memoria: Decodificador + VRAM

### Decisión clave

ROM, RAM y VRAM son de **32 bits × 1024 palabras**, por lo tanto:

> ❗ **Las direcciones internas del CPU deben trabajar con 10 bits.**

### Mapa de Memoria

```
0x0000_0000 - 0x0000_03FF : ROM (1024 palabras, 32 bits)
0x1000_0000 - 0x1000_03FF : RAM (1024 palabras, 32 bits)
0x2000_0000 - 0x2000_00FF : PS/2 (registros)
0x3000_0000 - 0x3000_03FF : VRAM (1024 palabras, 32 bits)
```

**Decodificación:** usando `address[31:28]`

### VRAM (2 puertos)

**Módulo:** `vram_2puertos_module`

| Parámetro | Valor                   |
| --------- | ----------------------- |
| Tamaño    | 1024 palabras × 32 bits |
| Dirección | 10 bits                 |
| Puerto A  | CPU (write)             |
| Puerto B  | VGA (read)              |
| Modo      | OLD_DATA                |

La VRAM se usa como **buffer de texto**, donde cada palabra almacena un carácter ASCII en `[7:0]`.

---

## Plan de Fases Incremental

### FASE 0: Preparación y Migración de Memoria (2 días)

**Objetivo**: Migrar sistema de memoria a ROM/RAM/VRAM de 10 bits y verificar funcionamiento básico del CPU.

**Tareas**:

1. Modificar CPU para direccionamiento de 10 bits:
   - Cambiar `pc_reg.sv`: `PC[11:2]` para ROM
   - Modificar `cpu_top.sv`: direcciones de 10 bits
2. Crear ROM de instrucciones usando IP Catalog:
   - Configurar ROM: 1024×32 bits
   - Crear `rom_data.mif` inicial con programa simple (LEDs test)
3. Crear RAM usando IP Catalog:
   - Configurar RAM: 1024×32 bits
   - Inicializar con `ram_data.mif` (opcional)
4. Crear módulo `mem_system.sv`:
   - Decodificador de 4 regiones (ROM/RAM/PS2/VRAM)
   - Multiplexor de lectura según región
5. Integrar `mem_system` en `cpu_top.sv`
6. Verificar compilación sin errores

**Verificación**:

- **Hardware**: Programa simple enciende LEDs en secuencia
- **Hardware**: Escritura/lectura a RAM funciona (test con LEDs)

**Archivos Nuevos**:

- `mem_system.sv`
- `rom_data.mif`
- `ram_data.mif`

**Archivos Modificados**:

- `cpu_top.sv`
- `pc_reg.sv`

---

### FASE 1: Rutinas de Software (MUL/DIV/DECIMAL) (3-4 días)

**Objetivo**: Implementar y probar rutinas fundamentales en ARMv4.

**Tareas**:

1. Escribir rutinas en ensamblador:

```asm
   mul_software:   ; R1 * R2 → R3
   div_software:   ; R1 / R2 → R3 (cociente), R4 (residuo)
   bin_to_decimal: ; R1 → buffer de dígitos ASCII en RAM
```

2. Crear programa de prueba:
   - Inicializar R1=12, R2=5
   - Llamar `mul_software` (resultado R3=60)
   - Llamar `div_software` (resultado R3=12, R4=2)
   - Guardar resultados en RAM
3. Ensamblar con herramienta online (godbolt.org)
4. Copiar código máquina a `rom_data.mif`
5. Recompilar y cargar en FPGA

**Verificación**:

- **Hardware**: Leer RAM con SignalTap: dirección 0x10000000 contiene 60 (0x3C)
- **Hardware**: Leer RAM: dirección 0x10000004 contiene 12 (0x0C)
- **Hardware**: LEDs muestran resultado final

**Archivos Nuevos**:

- `software/rutinas_base.s`

**Archivos Modificados**:

- `rom_data.mif`

---

### FASE 2: Periférico VGA con VRAM (5-6 días)

**Objetivo**: Implementar sistema VGA completo con VRAM dual-port.

**Tareas**:

1. Crear VRAM usando IP Catalog:
   - Configurar RAM True Dual-Port
   - 1024×32 bits, modo OLD_DATA
   - Puerto A: CPU write, Puerto B: VGA read
2. Módulo `vga_timing.sv`:
   - Contadores H/V para 640×480@60Hz
   - Señales hsync, vsync, coordenadas x/y
3. Crear ROM de fuente:
   - Script Python `gen_font_hex.py` para generar bitmap 8×16
   - Caracteres: 0-9, +, -, \*, /, &, |, ^, =, A-Z básico
   - Guardar en `font_8x16.hex`
4. Módulo `font_rom.sv`:
   - ROM inicializada con `font_8x16.hex`
5. Módulo `vga_renderer.sv`:
   - Calcular posición de carácter desde x/y
   - Leer ASCII de VRAM
   - Buscar bitmap en font_rom
   - Generar pixel RGB
6. Divisor de reloj 50MHz→25MHz:

```verilog
   always @(posedge clk_50MHz)
       clk_25MHz <= ~clk_25MHz;
```

7. Integrar VRAM en `mem_system.sv` (región 0x3)
8. Conectar VGA en `top_fpga.sv`
9. Configurar pines VGA en `.qsf`
10. Programa de prueba: escribir "HELLO" en VRAM desde ROM

**Verificación**:

- **Hardware**: Monitor detecta señal 640×480@60Hz
- **Hardware**: Texto "HELLO" visible en pantalla
- **Hardware**: Escribir diferentes ASCII desde CPU, pantalla actualiza

**Archivos Nuevos**:

- `vram_2puertos.v` (IP Catalog)
- `vga_timing.sv`
- `font_rom.sv`
- `vga_renderer.sv`
- `font_8x16.hex`
- `software/gen_font_hex.py`

**Archivos Modificados**:

- `mem_system.sv` (añadir VRAM)
- `top_fpga.sv`
- `proyecto-disenod.qsf`

---

### FASE 3: Periférico PS/2 (4-5 días)

**Objetivo**: Implementar receptor PS/2 funcional.

**Tareas**:

1. Módulo `ps2_sync.sv`:
   - Double-flop para CLK y DATA
2. Módulo `ps2_receiver.sv`:
   - FSM: IDLE → START → DATA[0:7] → PARITY → STOP
   - Verificación de paridad impar
   - Flag `new_data` y `error`
3. Integrar en `mem_system.sv`:
   - Registros PS2_DATA (0x20000000)
   - Registro PS2_STATUS (0x20000004)
4. Conectar PS/2 en `top_fpga.sv`
5. Configurar pines PS/2 en `.qsf`
6. Programa de prueba:
   - Polling de PS2_STATUS[0]
   - Leer PS2_DATA
   - Mostrar scancode en LEDs

**Verificación**:

- **Hardware**: Presionar tecla '5', LEDs muestran scancode 0x2E
- **Hardware**: Presionar Enter, LEDs muestran 0x5A
- **Hardware**: Probar con múltiples teclados

**Archivos Nuevos**:

- `ps2_sync.sv`
- `ps2_receiver.sv`

**Archivos Modificados**:

- `mem_system.sv`
- `top_fpga.sv`
- `proyecto-disenod.qsf`

**Riesgo ALTO**: Timing asíncrono. Mitigación: Sincronizador robusto.

---

### FASE 4: Programa Calculadora en Ensamblador (5-7 días)

**Objetivo**: Implementar lógica completa de calculadora.

**Protocolo de Scancodes**:

```
Dígitos: 0x45(0), 0x16(1), 0x1E(2), 0x26(3), 0x25(4),
         0x2E(5), 0x36(6), 0x3D(7), 0x3E(8), 0x46(9)
Operadores: 0x55(+), 0x4E(-), 0x7C(*), 0x4A(/)
            0x1C(&), 0x44(|), 0x22(^)
Control: 0x5A(ENTER), 0x76(CLEAR)
```

**Estructura del Programa**:

```asm
main:
    BL init_display           ; Escribir layout en VRAM
loop_calculadora:
    BL read_operand1          ; Leer dígitos hasta Enter
    BL display_operand1       ; Mostrar en fila 3
    BL read_operator          ; Leer operador
    BL display_operator       ; Mostrar en fila 4
    BL read_operand2          ; Leer dígitos
    BL display_operand2       ; Mostrar en fila 5
    BL calculate              ; Ejecutar operación
    BL bin2dec                ; Convertir resultado
    BL display_result         ; Mostrar en fila 7
    B loop_calculadora

calculate:
    ; Dispatcher según operador
    CMP r2, #0      ; operador == '+'
    BEQ add_op
    CMP r2, #1      ; operador == '-'
    BEQ sub_op
    CMP r2, #2      ; operador == '*'
    BEQ mul_software
    ; ... etc
```

**Tareas**:

1. Implementar rutinas:
   - `init_display`: Escribir strings fijos ("ARMv4 Calculator", etc)
   - `read_scancode`: Polling PS2_STATUS, leer PS2_DATA
   - `scancode_to_digit`: Traducir scancode→0-9
   - `scancode_to_operator`: Traducir scancode→código 0-6
   - `read_operand`: Multi-dígito (operando = operando\*10 + dígito)
   - `display_operand`: Convertir a decimal y escribir en VRAM
   - `calculate`: Dispatcher a rutinas de operación
2. Ensamblar con herramienta online
3. Copiar a `rom_data.mif`
4. Testing iterativo en hardware

**Verificación**:

- **Hardware**: 12 + 34 = 46 (decimal en pantalla)
- **Hardware**: 7 \* 8 = 56
- **Hardware**: 100 / 5 = 20
- **Hardware**: 100 / 0 → ERROR
- **Hardware**: CLEAR limpia operandos

**Archivos Nuevos**:

- `software/calculadora.s`

**Archivos Modificados**:

- `rom_data.mif`

**Riesgo ALTO**: Bugs en FSM. Mitigación: LEDs de debug para estados.

---

### FASE 5: Integración y Pruebas (2-3 días)

**Objetivo**: Sistema completo funcionando.

**Tareas**:

1. Plan de pruebas exhaustivo:
   - Aritméticas: 12+34, 100-25, 7\*8, 100/5, 100/0
   - Lógicas: 255&15, 240|15, 170^85
   - Casos edge: 0+0, overflow, máximo valor
2. Análisis de timing:
   - Verificar setup/hold slack positivo
   - Resolver violations si existen
3. LEDs de debug permanentes:
   - LED[7:0]: último scancode
   - LED[9:8]: estado FSM calculadora
4. Optimizaciones:
   - Ajustar delays si hay problemas de timing
   - Backspace (si hay tiempo)

**Verificación**:

- Todas las operaciones correctas
- Sin glitches en VGA
- PS/2 estable
- Sistema estable >10 minutos

**Archivos Modificados**:

- `top_fpga.sv`
- `proyecto-disenod.sdc` (constraints)

---

### FASE 6: Documentación (1 día)

**Objetivo**: Documentar sistema.

**Tareas**:

1. Actualizar Progreso.md:
   - Instrucciones soportadas
   - Checklist de fases
2. Manual de usuario:
   - Conexión física
   - Uso de calculadora
3. Documentación técnica:
   - Arquitectura
   - Diagramas de bloques

**Archivos Nuevos**:

- `docs/user_manual.md`

---

## Cronograma

```
Fase 0: Preparación + Memoria   [2 días]  ← CRÍTICO
Fase 1: MUL/DIV software        [4 días]
Fase 2: VGA + VRAM              [6 días]  ← CRÍTICO
Fase 3: PS/2                    [5 días]  ← CRÍTICO
Fase 4: Programa calculadora    [7 días]  ← CRÍTICO
Fase 5: Integración             [3 días]
Fase 6: Documentación           [1 día]

Total: 28 días (~6 semanas)
Con imprevistos: 35 días (7 semanas)
```

**Camino crítico**: Fases 0, 2, 3, 4 (20 días)

---

## Archivos Críticos

### Modificar:

1. `cpu_top.sv` - Direcciones 10 bits, integración mem_system
2. `pc_reg.sv` - PC[11:2]
3. `top_fpga.sv` - Integración top-level
4. `rom_data.mif` - Código de calculadora

### Crear:

1. `mem_system.sv` - Decodificador memory-mapped
2. `vram_2puertos.v` - VRAM dual-port (IP)
3. `vga_timing.sv` - Sincronización VGA
4. `vga_renderer.sv` - Renderer de texto
5. `font_rom.sv` - ROM de fuente
6. `ps2_sync.sv` - Sincronizador PS/2
7. `ps2_receiver.sv` - Receptor PS/2
8. `software/calculadora.s` - Programa principal

---

## Riesgos Principales

| Riesgo                   | Probabilidad | Impacto | Mitigación                      |
| ------------------------ | ------------ | ------- | ------------------------------- |
| Direccionamiento 10 bits | Media        | Alto    | Verificar en Fase 0 con LEDs    |
| PS/2 timing              | Alta         | Alto    | Sincronizador robusto           |
| VRAM dual-port           | Baja         | Medio   | Usar IP Catalog probado         |
| Bugs FSM calculadora     | Alta         | Alto    | LEDs debug, testing iterativo   |
| Timing violations        | Media        | Medio   | Reducir frecuencia si necesario |

---

## Métricas de Éxito

**Funcionales**:

- 7 operaciones funcionan
- Display VGA legible
- PS/2 sin pérdida de datos
- División por 0 detectada

**Técnicas**:

- Timing slack positivo
- Recursos <50%
- Sin errores críticos
- Estabilidad >10 minutos

---

## Dependencias

**Herramientas**:

- Quartus Prime
- GNU ARM toolchain (arm-none-eabi-as)
- ModelSim (opcional)

**Hardware**:

- DE10-Standard FPGA
- Teclado PS/2
- Monitor VGA
- Cable USB Blaster

---

## Decisiones Confirmadas

1. **Timeline**: Demo en 4-5 semanas
2. **MUL/DIV**: Software
3. **Display**: Decimal
4. **Ensamblador**: Manual (copy-paste hex)
5. **Testing**: Hardware directo

---

## Próximos Pasos

1. **Iniciar Fase 0**: Migrar a memorias de 10 bits
2. **Verificar**: Programa simple con LEDs

**Recursos**:

- Ensamblador: https://godbolt.org
- ARMv4 ISA: ARM7TDMI Technical Reference
- VGA timing: http://tinyvga.com/vga-timing/640x480@60Hz
