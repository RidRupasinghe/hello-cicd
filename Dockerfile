# ---- Stage 1: build the static site ----
# --platform=$BUILDPLATFORM runs this stage natively on the CI runner,
# even when we build an image for a different CPU (e.g. arm64 for Apple Silicon).
FROM --platform=$BUILDPLATFORM node:24-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build

# ---- Stage 2: serve it with nginx ----
FROM nginx:alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
