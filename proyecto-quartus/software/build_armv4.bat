@echo off
setlocal

set FILE=program
set ROM_ADDR=0x0

echo ===============================
echo  ENSAMBLANDO (ARMv4)
echo ===============================
arm-none-eabi-as -march=armv4 -mcpu=arm7tdmi -o %FILE%.o %FILE%.s
if %errorlevel% neq 0 (
    echo ERROR: Fallo el ensamblado.
    pause
    exit /b 1
)

echo ===============================
echo  LINKING
echo ===============================
arm-none-eabi-ld %FILE%.o -Ttext=%ROM_ADDR% -e _start -o %FILE%.elf

echo ===============================
echo  GENERANDO HEX
echo ===============================
arm-none-eabi-objcopy -O ihex %FILE%.elf %FILE%.hex

echo ===============================
echo  GENERANDO BIN (para el MIF)
echo ===============================
arm-none-eabi-objcopy -O binary %FILE%.elf %FILE%.bin

echo ===============================
echo  GENERANDO MIF con Python
echo ===============================
python gen_mif.py

echo ===============================
echo  LIMPIANDO ARCHIVOS INTERMEDIOS
echo ===============================
del %FILE%.o
del %FILE%.elf
del %FILE%.bin

echo ===============================
echo   ¡TODO LISTO!
echo ===============================
echo Archivos finales:
echo   %FILE%.hex
echo   %FILE%.mif
echo ===============================

pause
