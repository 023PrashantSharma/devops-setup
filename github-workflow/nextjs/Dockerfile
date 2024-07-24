FROM node:18

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .

# Define build arguments
ARG NEXT_PUBLIC_API_URL

# Set environment variables from build arguments
ENV NEXT_PUBLIC_API_URL=${NEXT_PUBLIC_API_URL}

RUN npm run build

EXPOSE 3000

CMD ["npm", "run", "start"]
