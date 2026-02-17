# 1. Usar imagen oficial de Node.js
FROM node:18-slim

# 2. Directorio de trabajo
WORKDIR /usr/src/app

# 3. Copiamos archivos de dependencias
COPY servidor/package*.json ./

# 4. INSTALACIÓN DE SEGURIDAD (Aquí resolvemos tu error)
# Instalamos TODO lo que tu código necesita para que no vuelva a fallar por "Module Not Found"
RUN npm install
RUN npm install dotenv @grpc/grpc-js @grpc/proto-loader @aws-sdk/client-s3 redis

# 5. Copiamos el código del servidor
COPY servidor/ .

# 6. Copiamos la carpeta proto
COPY proto/ ./proto/

# 7. Puerto gRPC
EXPOSE 50051

# 8. Iniciar servidor
CMD [ "node", "index.js" ]