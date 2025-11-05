"""
arm_bits_calc.py
----------------
Calculadora en alto nivel que opera sobre operandos BINARIOS (dos complementos)
con ancho parametrizable (WIDTH). Devuelve resultado en:
- entero con signo (decimal),
- entero sin signo (decimal),
- binario (zero-padded a WIDTH),
y las banderas Z, N, C, V.

Operaciones soportadas: +, -, *, /, &, |, ^

USO BÁSICO (importado):
    from arm_bits_calc import eval_bits

    r = eval_bits("00000101", "+", "00000011", width=8)
    # r es un dict con: res_signed, res_unsigned, res_bin, flags{Z,N,C,V}

EJECUCIÓN DIRECTA (ejemplos al final del archivo en __main__).
"""

from typing import Tuple, Dict

# -------------------------
# Utilidades de ancho y máscaras
# -------------------------
def _mask(width: int) -> int:
    """Máscara de width bits: 0..(2^width - 1)."""
    if not (1 <= width <= 64):
        raise ValueError("El ancho debe estar entre 1 y 64 bits.")
    return (1 << width) - 1

def _sign_bit(width: int) -> int:
    """Bit de signo para dos complementos (bit más significativo)."""
    return 1 << (width - 1)

# -------------------------
# Conversión de binario <-> enteros
# -------------------------
def _to_unsigned(bits: str, width: int) -> int:
    """
    Convierte 'bits' (solo 0/1) a entero sin signo, rellenando a la izquierda
    si es más corto que width. Error si excede el ancho o hay caracteres inválidos.
    """
    if any(ch not in "01" for ch in bits):
        raise ValueError("Los bits deben contener solo caracteres '0' o '1'.")
    if len(bits) > width:
        raise ValueError("Los bits exceden el ancho especificado.")
    return int(bits.zfill(width), 2)

def _to_signed(u: int, width: int) -> int:
    """
    Interpreta 'u' como entero con signo en dos complementos de 'width' bits.
    """
    m = _mask(width)
    sbit = _sign_bit(width)
    u &= m
    return u - (1 << width) if (u & sbit) else u

def _bin_str(u: int, width: int) -> str:
    """Entero a binario zero-padded a 'width' bits."""
    return format(u & _mask(width), f"0{width}b")

# -------------------------
# Cálculo de banderas
# -------------------------
def _flags_add(a_u: int, b_u: int, res_u: int, width: int) -> Tuple[int,int,int,int]:
    """
    Banderas Z, N, C, V para suma con dos complementos.
    C: carry sin signo
    V: overflow con signo
    """
    m, sbit = _mask(width), _sign_bit(width)
    Z = int((res_u & m) == 0)
    N = int((res_u & sbit) != 0)
    C = int((a_u & m) + (b_u & m) > m)

    A = _to_signed(a_u, width)
    B = _to_signed(b_u, width)
    R = _to_signed(res_u, width)
    V = int((A >= 0 and B >= 0 and R < 0) or (A < 0 and B < 0 and R >= 0))
    return Z, N, C, V

def _flags_sub(a_u: int, b_u: int, res_u: int, width: int) -> Tuple[int,int,int,int]:
    """
    Banderas Z, N, C, V para resta (a - b).
    C: borrow (1 si hubo préstamo) -> aquí como a_u < b_u en sin signo.
    V: overflow con signo
    """
    m, sbit = _mask(width), _sign_bit(width)
    Z = int((res_u & m) == 0)
    N = int((res_u & sbit) != 0)
    C = int((a_u & m) < (b_u & m))  # borrow

    A = _to_signed(a_u, width)
    B = _to_signed(b_u, width)
    R = _to_signed(res_u, width)
    V = int((A >= 0 and B < 0 and R < 0) or (A < 0 and B >= 0 and R >= 0))
    return Z, N, C, V

def _flags_mul(a_u: int, b_u: int, res_u: int, width: int) -> Tuple[int,int,int,int]:
    """
    Banderas para multiplicación truncada a 'width' bits:
    Z y N según resultado truncado; C=0; V=1 si hubo derrame (bits fuera de width).
    """
    m, sbit = _mask(width), _sign_bit(width)
    Z = int((res_u & m) == 0)
    N = int((res_u & sbit) != 0)
    full = (a_u & m) * (b_u & m)
    V = int(full >> width != 0)
    C = 0
    return Z, N, C, V

def _flags_logic(res_u: int, width: int) -> Tuple[int,int,int,int]:
    """Banderas para &, |, ^ : Z y N; C=0; V=0."""
    m, sbit = _mask(width), _sign_bit(width)
    Z = int((res_u & m) == 0)
    N = int((res_u & sbit) != 0)
    C, V = 0, 0
    return Z, N, C, V

# -------------------------
# Evaluador principal
# -------------------------
def eval_bits(a_bits: str, op: str, b_bits: str, *, width: int = 32) -> Dict[str, object]:
    """
    Evalúa la operación entre dos operandos binarios de ancho 'width'.
    Devuelve un diccionario con:
    - res_signed: resultado como entero con signo.
    - res_unsigned: resultado como entero sin signo.
    - res_bin: resultado en binario (zero-padded).
    - flags: banderas Z, N, C, V.
    """
    a_u = _to_unsigned(a_bits, width)
    b_u = _to_unsigned(b_bits, width)

    if op == "+":
        res_u = a_u + b_u
        flags = _flags_add(a_u, b_u, res_u, width)
    elif op == "-":
        res_u = a_u - b_u
        flags = _flags_sub(a_u, b_u, res_u, width)
    elif op == "*":
        res_u = a_u * b_u
        flags = _flags_mul(a_u, b_u, res_u, width)
    elif op == "&":
        res_u = a_u & b_u
        flags = _flags_logic(res_u, width)
    elif op == "|":
        res_u = a_u | b_u
        flags = _flags_logic(res_u, width)
    elif op == "^":
        res_u = a_u ^ b_u
        flags = _flags_logic(res_u, width)
    else:
        raise ValueError(f"Operación no soportada: {op}")

    return {
        "res_signed": _to_signed(res_u, width),
        "res_unsigned": res_u & _mask(width),
        "res_bin": _bin_str(res_u, width),
        "flags": {
            "Z": flags[0],
            "N": flags[1],
            "C": flags[2],
            "V": flags[3],
        },
    }

# -------------------------
# Simulación de periféricos
# -------------------------
def simulate_keyboard_input() -> str:
    """Simula la entrada de datos desde un teclado."""
    return input("Ingrese un número binario: ")

def simulate_uart_output(data: str):
    """Simula el envío de datos a través de UART."""
    print(f"Enviando datos por UART: {data}")

# -------------------------
# Ejecución directa
# -------------------------
if __name__ == "__main__":
    print("Simulación de calculadora ARM.")
    a = simulate_keyboard_input()
    b = simulate_keyboard_input()
    op = input("Ingrese la operación (+, -, *, &, |, ^): ")

    try:
        result = eval_bits(a, op, b, width=8)
        print("Resultado:")
        print(f"  Entero con signo: {result['res_signed']}")
        print(f"  Entero sin signo: {result['res_unsigned']}")
        print(f"  Binario: {result['res_bin']}")
        print("  Banderas:")
        for flag, value in result['flags'].items():
            print(f"    {flag}: {value}")

        simulate_uart_output(result['res_bin'])
    except ValueError as e:
        print(f"Error: {e}")

