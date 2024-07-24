# Use Node.js LTS version as the base image
FROM node:20

# Set the working directory in the container
WORKDIR /app

# Build-time variables
ARG PORT
ARG DATABASE_NAME
ARG ALLOW_ORIGIN
ARG DATABASE_USERNAME
ARG DATABASE_PASSWORD
ARG HOST
ARG DB_PORT

# Define environment variables
ENV PORT=${PORT}
ENV DATABASE_NAME=${DATABASE_NAME}
ENV ALLOW_ORIGIN=${ALLOW_ORIGIN}
ENV DATABASE_USERNAME=${DATABASE_USERNAME}
ENV DATABASE_PASSWORD=${DATABASE_PASSWORD}
ENV HOST=${HOST}
ENV DB_PORT=${DB_PORT}

# Copy package.json and package-lock.json to the container
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy the entire project to the container
COPY . .

# Expose the port for the Node.js application
EXPOSE ${PORT}

# Start the Node.js application
CMD ["npm", "start"]
