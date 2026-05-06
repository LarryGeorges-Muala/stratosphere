FROM node:22

WORKDIR /app 

COPY package*.json ./

RUN npm install

COPY . .

RUN npm run lint

EXPOSE 3306 4001 5173 5672 6379

CMD [ "npm","run","server" ]


### PROD

# # Stage 1: Build
# FROM node:22 AS build
# WORKDIR /app
# COPY package*.json ./
# RUN npm install
# COPY . .
# RUN npm run build

# # Stage 2: Serve
# FROM nginx:alpine
# COPY --from=build /app/dist /usr/share/nginx/html
# EXPOSE 80
# CMD ["nginx", "-g", "daemon off;"]
