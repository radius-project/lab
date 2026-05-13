FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
ARG API_URL=http://localhost:3000
ENV API_URL=$API_URL
RUN npm run build
EXPOSE 3000
CMD ["npm", "start"]
