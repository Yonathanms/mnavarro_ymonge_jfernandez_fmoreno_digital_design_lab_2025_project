
# calculadora_arm.py
# ------------------------------------------------------------
# Demo mínima:
# - Ancho fijo de 32 bits (dos complementos).
# - Entrada guiada con PLANTILLA: "0000 0000 ... 0000"
# - Simula UART: imprime TX/RX después de cada entrada.
# - Carga registros básicos (R1=A, R2=B), ejecuta ALU y muestra Rdest.
# - SIEMPRE imprime banderas (Z N C V).
#
# Operaciones: add, sub, mul, div, and, or, xor
#
# Uso:
#   python calculadora_arm.py
#   (seguir las indicaciones en consola)

from typing import Tuple, Dict

WIDTH = 32
OPS = {"add", "sub", "mul", "div", "and", "or", "xor"}

# ---------------- Utilidades de 32 bits ----------------
def _mask() -> int:
    return (1 << WIDTH) - 1

def _sign_bit() -> int:
    return 1 << (WIDTH - 1)

def _to_signed(u: int) -> int:
    u &= _mask()
    return u - (1 << WIDTH) if (u & _sign_bit()) else u

def _bin_str(u: int) -> str:
    return format(u & _mask(), f"0{WIDTH}b")

def _group_bits(s: str) -> str:
    # Agrupa en nibbles: "0000 0000 ... 0000"
    return " ".join(s[i:i+4] for i in range(0, len(s), 4))

def _normalize_bits_input(user_text: str, default_bits32: str) -> str:
    """
    Acepta:
      - Cadena vacía: usa la plantilla por defecto (32 ceros)
      - Cadena corta (1 hasta 31 bits): se rellena a la izquierda hasta 32 con 0s si ingresa un 101 por ejemplo
      - Solo '0' y '1'
    Devuelve SIEMPRE 32 bits sin espacios.
    """
    s = (user_text or "").strip()
    if s == "":
        s = default_bits32
    s = s.replace(" ", "").replace("_", "")
    if any(ch not in "01" for ch in s):
        raise ValueError("Solo se aceptan '0' y '1' (se permiten espacios/guiones bajos para separar grupos).")
    if len(s) > WIDTH:
        raise ValueError(f"Se recibieron más de {WIDTH} bits.")
    return s.zfill(WIDTH)

# ---------------- Banderas (ALU) ----------------
def _flags_add(a_u: int, b_u: int, res_u: int) -> Tuple[int,int,int,int]:
    Z = int((res_u & _mask()) == 0)
    N = int((res_u & _sign_bit()) != 0)
    C = int((a_u & _mask()) + (b_u & _mask()) > _mask())
    A = _to_signed(a_u); B = _to_signed(b_u); R = _to_signed(res_u)
    V = int((A >= 0 and B >= 0 and R < 0) or (A < 0 and B < 0 and R >= 0))
    return Z, N, C, V

def _flags_sub(a_u: int, b_u: int, res_u: int) -> Tuple[int,int,int,int]:
    Z = int((res_u & _mask()) == 0)
    N = int((res_u & _sign_bit()) != 0)
    C = int((a_u & _mask()) < (b_u & _mask()))   # borrow
    A = _to_signed(a_u); B = _to_signed(b_u); R = _to_signed(res_u)
    V = int((A >= 0 and B < 0 and R < 0) or (A < 0 and B >= 0 and R >= 0))
    return Z, N, C, V

def _flags_mul(a_u: int, b_u: int, res_u: int) -> Tuple[int,int,int,int]:
    Z = int((res_u & _mask()) == 0)
    N = int((res_u & _sign_bit()) != 0)
    full = (a_u & _mask()) * (b_u & _mask())
    V = int(full >> WIDTH != 0)   # hubo derrame fuera de 32 bits
    C = 0
    return Z, N, C, V

def _flags_logic(res_u: int) -> Tuple[int,int,int,int]:
    Z = int((res_u & _mask()) == 0)
    N = int((res_u & _sign_bit()) != 0)
    return Z, N, 0, 0

# ---------------- ALU pura ----------------
def eval_bits(a_bits32: str, op: str, b_bits32: str) -> Dict[str, object]:
    """
    Evalúa a_bits <op> b_bits (32 bits, dos complementos).
    Retorna:
      - res_signed (int), res_unsigned (int), res_bin (str),
      - flags dict: {'Z','N','C','V'}
    """
    if op not in OPS:
        raise ValueError("Operación inválida. Use: add, sub, mul, div, and, or, xor")
    a_u = int(a_bits32, 2)
    b_u = int(b_bits32, 2)

    if op == "add":
        res_u = (a_u + b_u) & _mask()
        Z,N,C,V = _flags_add(a_u, b_u, res_u)
    elif op == "sub":
        res_u = (a_u - b_u) & _mask()
        Z,N,C,V = _flags_sub(a_u, b_u, res_u)
    elif op == "mul":
        res_u = (a_u * b_u) & _mask()
        Z,N,C,V = _flags_mul(a_u, b_u, res_u)
    elif op == "div":
        A = _to_signed(a_u); B = _to_signed(b_u)
        if B == 0:
            raise ZeroDivisionError("División por cero")
        res_s = int(A / B)  # trunc hacia 0 (C/ARM)
        res_u = res_s & _mask()
        Z,N,C,V = int(res_u == 0), int(res_u & _sign_bit() != 0), 0, 0
    elif op == "and":
        res_u = (a_u & b_u) & _mask()
        Z,N,C,V = _flags_logic(res_u)
    elif op == "or":
        res_u = (a_u | b_u) & _mask()
        Z,N,C,V = _flags_logic(res_u)
    elif op == "xor":
        res_u = (a_u ^ b_u) & _mask()
        Z,N,C,V = _flags_logic(res_u)

    res_s = _to_signed(res_u)
    return {
        "res_signed":   res_s,
        "res_unsigned": res_u,
        "res_bin":      _bin_str(res_u),
        "flags":        {"Z": Z, "N": N, "C": C, "V": V},
    }

# ---------------- UART simulado + REGs + I/O ----------------
def _uart_tx(label: str, payload_bits32: str):
    print(f"[UART] TX {label}: { _group_bits(payload_bits32) }")

def _uart_rx(label: str):
    print(f"[UART] RX {label}: recibido por CPU")

def _show_reg(name: str, u: int):
    print(f"[REG] {name} = { _group_bits(_bin_str(u)) } | signed={_to_signed(u)}  unsigned={u}")

def _template_bits32() -> str:
    return _group_bits("0"*WIDTH)  # "0000 0000 ... 0000"

def _read_operand(label: str) -> str:
    tpl = _template_bits32()
    print(f"Ingrese {label} = {tpl}")
    user = input(f"{label} (cambie 0→1 donde necesite; ENTER para usar la plantilla tal cual): ")
    return _normalize_bits_input(user, "0"*WIDTH)

# ---------------- Programa principal ----------------
def main():
    print("=== DEMO UART + REG + ALU — 32 bits (dos complementos) ===")
    print("Sugerencia: para encender el bit más significativo (MSB), cambie solo el primer 0 de la plantilla A por 1.")
    try:
        a_bits32 = _read_operand("A")
        _uart_tx("A", a_bits32); _uart_rx("A")

        b_bits32 = _read_operand("B")
        _uart_tx("B", b_bits32); _uart_rx("B")

        op = input("Operación [add, sub, mul, div, and, or, xor]: ").strip().lower()

        # Cargar "registros" R1, R2 (enteros 32-bit)
        R1 = int(a_bits32, 2)
        R2 = int(b_bits32, 2)
        _show_reg("R1", R1)
        _show_reg("R2", R2)

        # ALU + resultado
        try:
            out = eval_bits(a_bits32, op, b_bits32)
            Rdest = int(out["res_unsigned"])
            print("[ALU] Operación ejecutada.")
            _show_reg("Rdest", Rdest)

            # Banderas SIEMPRE
            Z,N,C,V = out["flags"]["Z"], out["flags"]["N"], out["flags"]["C"], out["flags"]["V"]
            print(f"[FLAGS] Z={Z} N={N} C={C} V={V}")

            # Salida clara
            print(f">>> OUT dec(signed)={out['res_signed']} | dec(unsigned)={out['res_unsigned']} | bin={_group_bits(out['res_bin'])}")

        except ZeroDivisionError as e:
            print("[ALU] EXCEPCIÓN:", e)
            print("[FLAGS] Z=0 N=0 C=0 V=0 (no actualizadas por excepción)")

    except Exception as e:
        print("ERROR:", e)

if __name__ == "__main__":
    main()
