require('dotenv').config();
const grpc = require('@grpc/grpc-js');
const protoLoader = require('@grpc/proto-loader');
const path = require('path');

const SERVER_IP = process.env.SERVER_IP || 'localhost';
const SERVER_PORT = process.env.SERVER_PORT || '50051';

const PROTO_PATH = path.join(__dirname, '../proto/estudiante.proto');

try {
    const packageDefinition = protoLoader.loadSync(PROTO_PATH, {
        keepCase: true, longs: String, enums: String, defaults: true, oneofs: true
    });

    const proto = grpc.loadPackageDefinition(packageDefinition);

    const client = new proto.EstudianteService(
        `${SERVER_IP}:${SERVER_PORT}`,
        grpc.credentials.createInsecure()
    );

    const nuevoEstudiante = {
        id: "1750001012", 
        nombre: "Mauricio Correa",
        carrera: "Ingenieria en Sistemas"
    };

    console.log(`Iniciando solicitud gRPC hacia ${SERVER_IP}:${SERVER_PORT}...`);

    client.EnviarEstudiante(nuevoEstudiante, (error, response) => {
        if (!error) {
            console.log("--------------------------------------------------");
            console.log("Respuesta del Servidor:");
            console.log(response.mensaje);
            console.log("Estado: Operacion completada satisfactoriamente.");
            console.log("--------------------------------------------------");
        } else {
            console.error("Fallo en la comunicacion gRPC:", error.message);
            console.log("Referencia: Verifique la conectividad del ALB o la IP de la instancia.");
        }
    });

} catch (e) {
    console.error("Error crítico en la carga de la definicion de servicio:", e.message);
}