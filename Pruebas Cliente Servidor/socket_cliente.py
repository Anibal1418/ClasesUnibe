import socket
import sys

HOST = "127.0.0.1"
PORT = 5000
BUFFER_SIZE = 1024


def main():
    """Se conecta al servidor, envía un mensaje y muestra la confirmación."""
    mensaje = "Hola servidor, este es un mensaje desde el cliente."
    if len(sys.argv) > 1:
        mensaje = " ".join(sys.argv[1:])

    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as cliente:
            cliente.connect((HOST, PORT))
            print(f"Cliente conectado a {HOST}:{PORT}")

            cliente.sendall(mensaje.encode("utf-8"))
            print(f"Mensaje enviado: {mensaje}")

            datos = cliente.recv(BUFFER_SIZE)
            respuesta = datos.decode("utf-8")
            print(f"Respuesta del servidor: {respuesta}")

    except ConnectionRefusedError:
        print("No se pudo conectar. Verifica que el servidor esté ejecutándose.")
    except OSError as error:
        print(f"Error de red en el cliente: {error}")
    except Exception as error:
        print(f"Error inesperado en el cliente: {error}")


if __name__ == "__main__":
    main()
