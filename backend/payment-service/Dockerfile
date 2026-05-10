# ============================================================
# Payment Service — Dockerfile (Node)
# ============================================================

FROM node:20-alpine AS base
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm install
COPY . .
EXPOSE 8085

FROM base AS development
ENV NODE_ENV=development
CMD ["npm", "run", "dev"]

FROM base AS production
ENV NODE_ENV=production
CMD ["npm", "start"]

