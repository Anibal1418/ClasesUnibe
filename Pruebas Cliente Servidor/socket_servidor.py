import socket

HOST = "127.0.0.1"
PORT = 5000
BUFFER_SIZE = 1024


def main():
    """Inicia el servidor, espera una conexión, recibe un mensaje y responde."""
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as servidor:
            servidor.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            servidor.bind((HOST, PORT))
            servidor.listen(1)
            print(f"Servidor de sockets escuchando en {HOST}:{PORT}...")

            conexion, direccion = servidor.accept()
            with conexion:
                print(f"Conexión recibida desde {direccion[0]}:{direccion[1]}")
                datos = conexion.recv(BUFFER_SIZE)

                if not datos:
                    print("El cliente no envió datos.")
                    return

                mensaje = datos.decode("utf-8")
                print(f"Mensaje recibido del cliente: {mensaje}")

                respuesta = "Confirmación del servidor: mensaje recibido correctamente."
                conexion.sendall(respuesta.encode("utf-8"))
                print("Respuesta enviada al cliente.")

    except OSError as error:
        print(f"Error de red o de puerto en el servidor: {error}")
    except Exception as error:
        print(f"Error inesperado en el servidor: {error}")


if __name__ == "__main__":
    main()
