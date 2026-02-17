# 1. Usar imagen oficial
FROM node:18

# 2. Directorio de trabajo
WORKDIR /usr/src/app

# 3. Copiamos las dependencias ESPECIFICANDO la carpeta servidor
# Al usar el contexto de la raíz (el . del build), debemos entrar a 'servidor'
COPY servidor/package*.json ./
RUN npm install

# 4. Copiamos el código del servidor
COPY servidor/ .

# 5. Copiamos la carpeta proto (que está al mismo nivel que servidor en la raíz)
# Esto crea la carpeta /usr/src/app/proto/ dentro del contenedor
COPY proto/ ./proto/

# 6. Exponer puerto gRPC
EXPOSE 50051

# 7. Iniciar el servidor
CMD [ "node", "index.js" ]