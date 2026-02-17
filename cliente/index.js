require('dotenv').config();
const grpc = require('@grpc/grpc-js');
const protoLoader = require('@grpc/proto-loader');

// Configuración de variables de entorno
const SERVER_IP = process.env.SERVER_IP || 'localhost';
const SERVER_PORT = process.env.SERVER_PORT || '50051';

// Cargar el archivo .proto
const packageDefinition = protoLoader.loadSync('../proto/estudiante.proto', {
    keepCase: true,
    longs: String,
    enums: String,
    defaults: true,
    oneofs: true
});

const proto = grpc.loadPackageDefinition(packageDefinition);

// Crear el cliente gRPC
const client = new proto.EstudianteService(
    `${SERVER_IP}:${SERVER_PORT}`,
    grpc.credentials.createInsecure()
);

const nuevoEstudiante = {
    id: "UCE-002",
    nombre: "Richar Mauricio",
    carrera: "Sistemas"
};

client.EnviarEstudiante(nuevoEstudiante, (error, response) => {
    if (!error) {
        console.log("Respuesta del servidor:", response.mensaje);
    } else {
        console.error("Error en la comunicación:", error);
    }
});