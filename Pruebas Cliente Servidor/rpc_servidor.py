from xmlrpc.server import SimpleXMLRPCServer

HOST = "127.0.0.1"
PORT = 8000


def cuadrado(numero):
    """Recibe un número entero y devuelve su cuadrado."""
    try:
        numero = int(numero)
        return numero * numero
    except (TypeError, ValueError):
        raise ValueError("El valor recibido debe ser un número entero.")


def main():
    """Registra la función remota y deja el servidor esperando llamadas."""
    try:
        with SimpleXMLRPCServer((HOST, PORT), allow_none=True, logRequests=True) as servidor:
            servidor.register_function(cuadrado, "cuadrado")
            print(f"Servidor RPC escuchando en http://{HOST}:{PORT}")
            print("Función remota disponible: cuadrado(numero)")
            servidor.serve_forever()
    except OSError as error:
        print(f"Error al iniciar el servidor RPC: {error}")
    except KeyboardInterrupt:
        print("Servidor RPC detenido por el usuario.")


if __name__ == "__main__":
    main()
