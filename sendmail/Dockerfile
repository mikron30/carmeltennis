FROM node:22-bookworm-slim

ENV NODE_ENV=production \
    PORT=8080

WORKDIR /app

COPY package*.json ./
RUN npm ci --omit=dev

COPY index.js ./

USER node

EXPOSE 8080

CMD ["node", "index.js"]
