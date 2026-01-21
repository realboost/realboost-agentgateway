FROM node:18-alpine AS builder

WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci

COPY . .
RUN npm run build

FROM nginx:alpine

# Copy the static build output to Nginx's html directory
# Since basePath is /ui, Next.js static export might put files in out/ui or similar, 
# or we just serve 'out' at /usr/share/nginx/html and simple requests to /ui work.
# Actually, with basePath: /ui, the export will typically create 'out' with the assets.
# We usually want to alias /ui to this directory in nginx.config.

COPY --from=builder /app/out /usr/share/nginx/html/ui
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
