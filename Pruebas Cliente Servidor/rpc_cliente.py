import sys
from xmlrpc.client import ServerProxy, Fault, ProtocolError

URL_SERVIDOR = "http://127.0.0.1:8000"


def obtener_numero():
    """Obtiene el número desde argumento de terminal o desde input()."""
    if len(sys.argv) > 1:
        return int(sys.argv[1])
    return int(input("Ingrese un número entero: "))


def main():
    """Solicita un entero, llama al servidor RPC y muestra el cuadrado."""
    try:
        numero = obtener_numero()

        with ServerProxy(URL_SERVIDOR, allow_none=True) as proxy:
            resultado = proxy.cuadrado(numero)

        print(f"Número enviado al servidor RPC: {numero}")
        print(f"Cuadrado recibido desde el servidor: {resultado}")

    except ValueError:
        print("Entrada inválida. Debes escribir un número entero.")
    except ConnectionRefusedError:
        print("No se pudo conectar. Verifica que el servidor RPC esté ejecutándose.")
    except Fault as error:
        print(f"El servidor RPC reportó un error: {error}")
    except ProtocolError as error:
        print(f"Error de protocolo RPC: {error}")
    except OSError as error:
        print(f"Error de comunicación con el servidor RPC: {error}")


if __name__ == "__main__":
    main()
