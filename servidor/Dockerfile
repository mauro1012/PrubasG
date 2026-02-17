# 1. Usar imagen oficial de Node.js
FROM node:18

# 2. Crear directorio de trabajo
WORKDIR /usr/src/app

# 3. Copiar archivos de dependencias
COPY package*.json ./

# 4. Instalar dependencias
RUN npm install

# 5. Copiar el código del servidor
COPY . .

# 6. Copiar el archivo .proto (Importante: según tu imagen, está una carpeta arriba)
# Lo copiamos desde la raíz del contexto de build que definiremos en Actions
COPY ../proto/estudiante.proto ./proto/estudiante.proto

# 7. Exponer puerto gRPC
EXPOSE 50051

# 8. Comando para iniciar
CMD [ "node", "index.js" ]