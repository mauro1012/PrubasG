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
        id: "1725634122", 
        nombre: "Richar Mauricio",
        carrera: "Sistemas"
    };

    console.log(`Conectando al servidor gRPC en ${SERVER_IP}:${SERVER_PORT}...`);

    client.EnviarEstudiante(nuevoEstudiante, (error, response) => {
        if (!error) {
            console.log(" Éxito:", response.mensaje);
        } else {
            console.error(" Error gRPC:", error.message);
            console.log("Tip: Revisa que el ALB esté en estado 'Healthy' en la consola de AWS.");
        }
    });

} catch (e) {
    console.error(" Error cargando el archivo .proto:", e.message);
}