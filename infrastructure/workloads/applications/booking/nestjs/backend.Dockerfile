FROM node:22

WORKDIR /app 

COPY package*.json ./

RUN npm install

COPY . .

EXPOSE 3306 4001 5173 5672 6379

CMD [ "npm","run","start:dev" ]
