require('dotenv').config();
const grpc = require('@grpc/grpc-js');
const protoLoader = require('@grpc/proto-loader');
const redis = require('redis');
const { S3Client, PutObjectCommand } = require("@aws-sdk/client-s3");

// Configuración de Clientes
const s3 = new S3Client({ region: "us-east-1" });
const REDIS_HOST = process.env.REDIS_HOST || 'localhost';
const REDIS_PORT = process.env.REDIS_PORT || '6379';
const GRPC_PORT = process.env.PORT || '50051';
const BUCKET_NAME = process.env.BUCKET_NAME; 

// 1. Conexión a Redis
const client = redis.createClient({ url: `redis://${REDIS_HOST}:${REDIS_PORT}` });
client.on('error', (err) => console.log('Error en Redis:', err));
client.on('connect', () => console.log('Conectado a Redis (Caché)'));

(async () => { await client.connect(); })();

// 2. Cargar .proto
const packageDefinition = protoLoader.loadSync('../proto/estudiante.proto', {
    keepCase: true, longs: String, enums: String, defaults: true, oneofs: true
});
const proto = grpc.loadPackageDefinition(packageDefinition);
const server = new grpc.Server();

// 3. Implementación del Servicio
server.addService(proto.EstudianteService.service, {
    EnviarEstudiante: async (call, callback) => {
        try {
            const { id, nombre, carrera } = call.request;
            
            // A. Guardar en Redis
            await client.set(id, JSON.stringify({ nombre, carrera, fecha: new Date() }));
            console.log(`[gRPC] Estudiante "${nombre}" guardado en Redis.`);

            // B. Guardar Log en S3 (Demostración para el profesor)
            if (BUCKET_NAME) {
                await s3.send(new PutObjectCommand({
                    Bucket: BUCKET_NAME,
                    Key: `logs-estudiantes/log-${id}.txt`,
                    Body: `Registro: Estudiante ${nombre} de la carrera ${carrera} procesado con éxito.`
                }));
                console.log(`[S3] Log de estudiante ${id} subido al bucket.`);
            }

            callback(null, { 
                mensaje: `Estudiante ${nombre} procesado en Redis y S3.`, 
                exito: true 
            });
        } catch (error) {
            console.error('Error en el procesamiento:', error);
            callback({
                code: grpc.status.INTERNAL,
                details: "Error interno del servidor"
            });
        }
    }
});

// 4. Iniciar servidor
server.bindAsync(`0.0.0.0:${GRPC_PORT}`, grpc.ServerCredentials.createInsecure(), (error, port) => {
    if (error) {
        console.error(`Error al iniciar: ${error.message}`);
        return;
    }
    console.log(`Servidor gRPC corriendo en puerto ${GRPC_PORT}`);
});