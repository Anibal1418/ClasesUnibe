# Microservicio Actor Model y AWS Lambda

Proyecto en Java 17 con Akka Typed. Un supervisor administra tres workers y distribuye tareas por round-robin. La operación `fail` lanza una excepción intencional, la estrategia de supervisión reinicia al worker y el handler devuelve un error controlado por timeout.

## Requisitos

- JDK 17
- Maven 3.9 o superior
- AWS SAM CLI y una cuenta AWS solamente para el despliegue

## Compilación y prueba local

```bash
mvn clean package
java -cp target/actor-serverless.jar com.luis.actorserverless.LocalDemo
```

## Prueba con AWS SAM

```bash
sam build
sam local invoke ActorTaskFunction -e events/sum.json
sam local start-api
```

Con `sam local start-api`, el endpoint local es:

```bash
curl -X POST http://127.0.0.1:3000/tasks \
  -H "Content-Type: application/json" \
  -d '{"operation":"sum","numbers":[4,7,10]}'
```

## Despliegue

```bash
sam deploy --guided
```

## Operaciones JSON

- `{"operation":"sum","numbers":[4,7,10]}`
- `{"operation":"uppercase","text":"hola"}`
- `{"operation":"reverse","text":"serverless"}`
- `{"operation":"fail"}`
