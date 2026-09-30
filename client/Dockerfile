# Etapa 1: Construcción de la aplicación React
FROM node:18-alpine AS build

WORKDIR /app

COPY package*.json ./
RUN npm install --legacy-peer-deps

COPY . .
# React incorpora estas URLs al JavaScript durante la compilación.
ARG REACT_APP_API_URL
ARG REACT_APP_PUBLIC_FOLDER
ARG REACT_APP_SOCKET_URL
RUN npm run build

# Etapa 2: Servidor liviano para producción
FROM node:18-alpine

WORKDIR /app

RUN npm install -g serve

COPY --from=build /app/build ./build

EXPOSE 3000

CMD ["serve", "-s", "build", "-l", "3000"]
