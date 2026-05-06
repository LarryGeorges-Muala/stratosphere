FROM node:22

WORKDIR /app 

COPY package*.json ./

RUN npm install

COPY ./workers/worker-mysql.js ./workers/worker-mysql.js

COPY _mysql_modules.js ./

COPY _helpers_modules.js ./

COPY node.env ./

EXPOSE 3001 3306

CMD [ "node","--env-file=node.env","./workers/worker-mysql.js" ]
