FROM node:22

WORKDIR /app 

COPY package*.json ./

RUN npm install

COPY . .

RUN npm run lint

EXPOSE 3306 4001 5173 5672 6379

CMD [ "node","--env-file=node.env","index.js" ]
