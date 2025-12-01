# ESTADO DEL PROYECTO – ARMv4 Calculator

## Fecha: 2025-11-28

---

## FASE 0: Preparación y Migración de Memoria

### Estado: COMPLETADA Y VERIFICADA EN HARDWARE

---

## Resumen de FASE 0

Se migró exitosamente el sistema de memoria de ROM/RAM hardcodeadas a módulos IP Catalog con archivos `.mif`. El CPU uniciclo funciona correctamente con el nuevo sistema de direccionamiento de 10 bits y decodificador memory-mapped de 4 regiones.

---

## Tareas completadas en Fase 0

### 1. Revisión de arquitectura actual

- CPU uniciclo funcional con etapas de ejecución
- Decodificador, ALU, banco de registros, CPSR implementados
- PC de 32 bits, direccionamiento de 10 bits para memoria

### 2. Creación de mem_system.sv

- Módulo centralizado de memoria con decodificador
- Soporta 4 regiones memory-mapped:
  - Región 0x0: ROM (0x0000_0000 - 0x0000_03FF)
  - Región 0x1: RAM (0x1000_0000 - 0x1000_03FF)
  - Región 0x2: PS/2 (0x2000_0000 - 0x2000_00FF) [Reservado]
  - Región 0x3: VRAM (0x3000_0000 - 0x3000_03FF) [Reservado]
- Multiplexor de lectura según región
- Lógica de escritura a RAM con decodificación de región

### 3. Modificación de cpu_top.sv

- Reemplazo de instr_mem.sv (ROM hardcodeada) con mem_system (ROM IP Catalog)
- Reemplazo de data_mem.sv con mem_system para acceso a RAM
- Dos instancias de mem_system:
  - U_MEM: Lectura de instrucciones desde ROM (en fetch)
  - U_MEM_DATA: Lectura/escritura de datos en RAM (en execute/memory)
- Mantenimiento de interfaz de debug

### 4. Creación de rom_data.mif

- Programa de prueba con 5 instrucciones:
  - Direcciones 0-3: Código de prueba (ADD, STR, LDR)
  - Dirección 4: Salto a dirección 16
  - Direcciones 16-19: Más instrucciones de prueba
  - Dirección 20: Salto de vuelta a dirección 0
- Loop infinito que alterna entre bit[4]=0 y bit[4]=1 para visualizar debug

### 5. Creación de ram_data.mif

- RAM de datos inicializada completamente con ceros
- Lista para recibir datos del programa en tiempo de ejecución

### 6. Modificación de top_fpga.sv

- Integración de salidas a LEDs para debug
- LED0: dbg_alu (instrucción aritmética ejecutada)
- LED1: dbg_mem (instrucción memoria ejecutada)
- LED2: dbg_br (instrucción branch ejecutada)
- LED4: PC bit[4] con divisor de frecuencia para visualización humana
- Divisor de frecuencia (50 MHz / 2^24) para obtener parpadeo visible (~1.5 Hz)

---

## Archivos creados en Fase 0

1. **mem_system.sv** - Sistema centralizado de memoria con decodificador
2. **rom_data.mif** - Datos iniciales de ROM
3. **ram_data.mif** - Datos iniciales de RAM

## Archivos modificados en Fase 0

1. **cpu_top.sv** - Integración de mem_system en lugar de instr_mem y data_mem
2. **top_fpga.sv** - Añadido divisor de frecuencia para LED[4]

---

## Problemas encontrados y soluciones

### [PROBLEMA-1] Formato incorrecto de archivos .mif

**Descripción**: Los archivos `.mif` iniciales utilizaban sintaxis incorrecta (DEPTH/WIDTH al inicio con = en lugar de =).

**Causa**: Error en la sintaxis del formato estándar de Quartus.

**Solución**: Corregir al formato estándar de Quartus:

```
WIDTH=32;
DEPTH=1024;
ADDRESS_RADIX=UNS;
DATA_RADIX=HEX;
```

**Estado**: RESUELTO

---

### [PROBLEMA-2] Módulos duplicados en compilación

**Descripción**: Error "module rom_module cannot be declared more than once" durante compilación.

**Causa**: Ambos `rom_module.v` y `rom_module_bb.v` estaban siendo compilados, causando conflicto.

**Solución**: Remover archivos `.v` del proyecto y mantener solo `_bb.v` (blackbox).

**Estado**: RESUELTO

---

### [PROBLEMA-3] Archivo vram_2puertos_module_inst.v causando error de sintaxis

**Descripción**: Error de sintaxis Verilog en archivo `_inst.v`.

**Causa**: El archivo `_inst.v` es solo un ejemplo/plantilla de Quartus, no código compilable.

**Solución**: Remover `vram_2puertos_module_inst.v` del proyecto.

**Estado**: RESUELTO

---

### [PROBLEMA-4] LED[4] no parpadeaba visiblemente

**Descripción**: LED[4] asignado a `debug_pc[4]` que alterna a 12.5 MHz, apareciendo constantemente encendido.

**Causa**: Frecuencia demasiado alta (12.5 MHz) para percepción humana (ojo puede ver hasta ~30 Hz).

**Solución**: Implementar divisor de frecuencia en top_fpga.sv:

- Contador de 25 bits incrementado cada ciclo de 50 MHz
- Usar bit [24] del contador (~1.5 Hz)
- AND con debug_pc[4] para obtener parpadeo visible

**Estado**: RESUELTO

**Lección aprendida**: Los tests de hardware deben considerar limitaciones de percepción humana. Frecuencias > 30 Hz necesitan divisores de frecuencia para ser visibles.

---

## Verificación en Hardware

### Comportamiento observado

- **LED0 (LEDR[0])**: Encendido permanentemente ✓
  - Indica ejecución de instrucción ADD
- **LED1 (LEDR[1])**: Encendido permanentemente ✓
  - Indica ejecución de instrucciones STR/LDR
- **LED2 (LEDR[2])**: Encendido permanentemente ✓
  - Indica ejecución de instrucción B (branch)
- **LED4 (LEDR[4])**: Parpadeando claramente a ~1.5 Hz ✓
  - Muestra debug_pc[4] alternando entre 0 y 1
  - Confirma que el CPU está ejecutando correctamente el loop
- **LEDs 3, 5-9**: Apagados ✓

### Conclusión

**FASE 0 EXITOSA**: El sistema de memoria migrado funciona correctamente. El CPU:

- Lee instrucciones desde ROM (IP Catalog)
- Ejecuta programa sin errores
- Lee y escribe en RAM correctamente
- Sistema de debug (LEDs) funciona como se esperaba
- El loop infinito ejecuta sin interrupciones

---

## Notas técnicas importantes

- Todas las memorias (ROM, RAM, VRAM) son 1024 palabras x 32 bits
- Dirección interna del CPU: 10 bits (extrayendo bits [11:2] del direccionamiento de 32 bits)
- mem_system decodifica región usando bits [31:28] de dirección completa
- ROM y RAM usan IP Catalog de Quartus (altsyncram) inicializados con `.mif`
- Programa en ROM es ejecutado correctamente con transiciones entre regiones de bit[4]
- Divisor de frecuencia: 50 MHz / 2^24 = ~1.5 Hz para visualización

---

## Lecciones aprendidas

1. **Percepción humana en tests**: Frecuencias > 30 Hz se ven como luz constante. Usar divisores de reloj para debug visible.

2. **Gestión de archivos IP Catalog**: Los archivos `_bb.v` (blackbox) y `.qip` son suficientes. No compilar archivos `_inst.v` (ejemplos).

3. **Formato de archivos .mif**: Seguir estrictamente el formato de Quartus (WIDTH/DEPTH sin espacios alrededor de =).

4. **Dos instancias de mem_system**: Necesarias para separar fetch (ROM) y data access (RAM/VRAM) sin conflictos.

---

---

---

## FASE 1: Rutinas de Software (MUL/DIV/DECIMAL)

### Estado: COMPLETADA Y VERIFICADA EN HARDWARE

---

## Resumen de FASE 1

Se implementaron las rutinas de multiplicacion, division y conversion binario a decimal en ensamblador ARMv4 y se valido el flujo completo ROM/RAM usando la toolchain GNU y archivos `.mif`. Se extendio el CPU para soportar operandos inmediatos, escritura del link register (BL) y lectura del PC como `PC+8`, habilitando programas reales.

---

## Tareas completadas en Fase 1

1. **Ampliacion de hardware base**: `decoder.sv`, `cpu_top.sv` y `regfile.sv` se actualizaron para exponer el bit I, expandir el inmediato rotado, resetear el banco de registros y permitir escritura de R14/R15 durante `BL` o cuando el destino es PC.
2. **Mejora del flujo de toolchain**: `software/gen_mif.py` ahora genera simultaneamente `software/program.mif` y `rom_data.mif`, asegurando que la ROM IP siempre cargue el binario mas reciente.
3. **Rutinas de software (`software/program.s`)**: Se implementaron `mul_software`, `div_software` y `bin_to_decimal`, con un programa de prueba que guarda producto (60), cociente (12), residuo (4) y la cadena "3456".
4. **Verificacion en hardware**: Se habilito runtime modification en la RAM IP, se compilo con SignalTap y se capturaron las escrituras de RAM (0x1000_0000, 0x1000_0004, 0x1000_0008 y 0x1000_0040).

---

## Problemas encontrados y soluciones (Fase 1)

### [PROBLEMA-5] Falta de soporte para inmediatos y BL

**Descripcion**: El CPU no aceptaba operandos inmediatos ni almacenaba el link register.
**Solucion**: Se anadio `op2_is_imm`, el expansor del inmediato rotado, reset al `regfile` y logica para escribir R14/R15 cuando la instruccion es `BL` o escribe el PC.

### [PROBLEMA-6] Flujo de `.mif` inconsistente

**Descripcion**: `gen_mif.py` generaba `program.mif`, pero la ROM seguia apuntando a `rom_data.mif`.
**Solucion**: El script ahora actualiza ambos archivos en un solo paso.

### [PROBLEMA-7] Herramientas de debug no encontraban la RAM

**Descripcion**: Memory Content Editor/SignalTap no detectaban la RAM por falta de runtime modification y archivos `alt_sld_fab` corruptos.
**Solucion**: Se habilito la opcion "Allow In-System Memory Content Editor..." en la RAM IP y se restauraron los scripts `alt_sld_fab*.tcl` en la instalacion de Quartus.

### [PROBLEMA-8] Dificultad para capturar `MemWrite`

**Descripcion**: El pulso de `MemWrite` dura un ciclo y el trigger no coincidia.
**Solucion**: Se aumento la profundidad de captura, se filtro con `MemWrite=1` y se utilizo el boton de reset para sincronizar el evento.

---

## Verificacion en Hardware (Fase 1)

- **SignalTap**: Pulsos con `MemWrite=1` y `addr=0x1000_0000/04/08` mostraron los datos 0x3C, 0x0C y 0x04. Un trigger en `addr=0x1000_0040` registro los ASCII `0x33`, `0x34`, `0x35`, `0x36` y `0x00`.
- **Toolchain**: `build_armv4.bat` + `gen_mif.py` generan los binarios y `.mif` finales que se cargan en la ROM IP.
- **Resultado**: Las rutinas de MUL/DIV/DECIMAL escriben los valores correctos en RAM y la conversion a ASCII funciona, cerrando la Fase 1.

---

## Lecciones aprendidas (Fase 1)

1. Es indispensable soportar el subconjunto minimo de la ISA (inmediatos, BL y lectura de PC) para ejecutar software real.
2. El script que genera `.mif` debe actualizar el archivo que Quartus usa realmente.
3. Habilitar herramientas de observabilidad (runtime modification y SignalTap) desde el inicio evita bloqueos de depuracion.
4. Para eventos unicos, sincronizar SignalTap con reset asegura capturar los pulsos correctos.

---

---

---

## FASE 2: Periferico VGA con VRAM dual-port

### Estado: EN PROGRESO (Arquitectura aprobada, implementacion iniciada)

### Avance al 30/11/2025

- **VRAM true dual-port** regenerada con clocks independientes (50 MHz CPU / 25 MHz VGA), modo `BIDIR_DUAL_PORT` y 32×1024 palabras. El puerto A está conectado en `mem_system.sv`/`cpu_top.sv`; `top_fpga.sv` ya genera `clk_25` y expone el puerto B para el renderer.
- **Validación CPU→VRAM en hardware**: se añadió una rutina temporal en `software/program.s` que escribe “HELLO ARM!” (`0x48,0x45,0x4C,0x4C,0x4F,0x20,0x41,0x52,0x4D,0x21,0x00`) en 0x3000_0000. SignalTap (`output_files/fase2_vramdebug_auto_signaltap_0.txt`) muestra `MemWrite=1` con `addr = 0x3000_0000 + n*4` y `write_data` iguales a esos valores, confirmando que la ruta CPU→VRAM funciona.
- **Problema resuelto**: inicialmente las rutinas `mul/div/bin_to_decimal` sobrescribían R5/R6 y el literal `0x30000000` se perdía, por lo que `write_data` quedaba en `0x00000D80`. Se movió la base a registros libres (R10/R11) y finalmente se reemplazó el bucle por `MOV/STR` explícitos. El log "C:\proyectoarm\proyecto-quartus\output_files\fase2_vramdebug_auto_signaltap_0.txt" reciente ya muestra los ASCII correctos.

---

## Plan de FASE 2

**Objetivo**: Mostrar texto 40x25 en VGA 640x480@60Hz usando una VRAM de doble puerto (32 bits x 1024 palabras) compartida entre el CPU y el subsistema VGA.

### Arquitectura propuesta

1. **VRAM dual-port real** (`vram_2puertos_module`)

   - Regenerar IP en modo true dual-port con clocks independientes y salidas `q_a`/`q_b`.
   - Puerto A (CPU): read/write en `clk_50`, direcciones `[11:2]`, datos `[31:0]`.
   - Puerto B (VGA): read-only en `clk_25`, direcciones calculadas por el renderer.
   - Formato palabra: `[7:0]` ASCII, `[15:8]` flags de color futuros, `[31:16]` reservado.

2. **`mem_system.sv`**

   - Añadir región 0x3 (0x3000_0000) con señales `vram_addr`, `vram_we`, `vram_q_a`.
   - Reutilizar bits `[11:2]` para la dirección local.
   - Mantener región 0x2 reservada para PS/2.

3. **`top_fpga.sv`**

   - Instanciar VGA core y nueva VRAM.
   - Divisor `clk_25MHz` (`always @(posedge clk_50) clk_25 <= ~clk_25;`).
   - Exponer `hsync`, `vsync`, `rgb[2:0]` a los pines VGA.

4. **Modulos nuevos**

   - `vga_timing.sv`: contadores horizontales/verticales (640x480@60Hz), genera `pixel_x`, `pixel_y`, `video_on`, `hsync`, `vsync`.
   - `font_rom.sv`: ROM 2048x8 inicializada con `font_8x16.hex` (256 caracteres x 16 filas).
   - `software/gen_font_hex.py`: script Python que genera `font_8x16.hex` a partir de una tabla ASCII.
   - `vga_renderer.sv`: calcula `char_row`, `char_col`, `vram_rd_addr`, consulta `font_rom` y produce `rgb`. Escala horizontal a 40 columnas (duplica píxeles).
   - Opcional futuro: `vram_layout_pkg` o `.inc` compartido con software para offsets (titulo, operandos, etc.).

5. **Flujo de datos**

   - CPU escribe ASCII en VRAM usando direcciones 0x3000_0000 + offset.
   - VGA lee continuo desde puerto B sincronizado a `pixel_x/pixel_y`.
   - `read_during_write_mode = OLD_DATA` evita glitches cuando CPU actualiza mientras VGA lee.

6. **Pruebas planificadas**
   - **Paso A**: regenerar VRAM IP, actualizar `mem_system`. Uso de SignalTap para verificar escrituras CPU→VRAM (direcciones 0x3000_xxxx).
   - **Paso B**: implementar `vga_timing` + `font_rom` + `vga_renderer`, conectar en `top_fpga` con patrón de prueba (texto fijo).
   - **Paso C**: enlazar VRAM real, programa de prueba escribe “HELLO” y se observa en el monitor.
   - **Paso D**: documentar layout VRAM (offsets 0x000, 0x140, etc.) y reservar bits de color para futuras mejoras.

### Riesgos y mitigaciones

| Riesgo                            | Mitigacion                                                                     |
| --------------------------------- | ------------------------------------------------------------------------------ |
| Desfase de clocks entre CPU y VGA | Usar true dual-port + `OLD_DATA`, ambos puertos con resets bien definidos      |
| Timing VGA (25 MHz)               | Mantener lógica simple, agregar restricción `create_generated_clock` en `.sdc` |
| Layout VRAM inconsistente         | Definir offsets en archivo compartido (header `.inc` y package SV)             |
| Consumo de recursos               | VRAM 4KB (1 M10K) + font ROM (otro M10K); dentro del presupuesto               |

### Próximos pasos inmediatos

1. Regenerar `vram_2puertos_module` con reloj doble y salidas separadas.
2. Modificar `mem_system.sv` y `cpu_top.sv` para exponer señales `vram_addr`, `vram_we`, `vram_q_a`.
3. Crear `vga_timing.sv` y `font_rom.sv` (plantillas vacías).
4. Integrar VRAM + VGA en `top_fpga.sv` con patrón fijo para validar sincronización antes de conectar al CPU.

Con estos pasos, la Fase 2 quedará lista para pruebas de hardware (monitor detecta 640x480@60Hz y muestra texto fijo). Luego podremos alimentar la VRAM desde software y continuar hacia PS/2 y calculadora.
