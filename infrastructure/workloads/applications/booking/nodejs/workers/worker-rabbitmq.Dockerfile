FROM node:22

WORKDIR /app 

COPY package*.json ./

RUN npm install

COPY ./workers/worker-rabbitmq.js ./workers/worker-rabbitmq.js

COPY _mysql_modules.js ./

COPY _helpers_modules.js ./

COPY node.env ./

EXPOSE 3000 3306 5672 6379

CMD [ "node","--env-file=node.env","./workers/worker-rabbitmq.js" ]
