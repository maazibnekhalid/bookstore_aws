FROM node:20-alpine AS base
WORKDIR /app

COPY package.json ./
RUN npm install --omit=dev

COPY src ./src

ENV NODE_ENV=production
EXPOSE 8080

# ECS task definition provides DB_HOST/DB_NAME/DB_USER/DB_PASSWORD,
# ORDERS_QUEUE_URL, COGNITO_USER_POOL_ID, COGNITO_CLIENT_ID as env vars
CMD ["node", "src/index.js"]
