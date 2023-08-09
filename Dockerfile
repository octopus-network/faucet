# Use an official Node.js runtime as the base image
FROM node:18-bullseye

# Set the working directory in the container
WORKDIR /usr/src/app

# Copy package.json and package-lock.json to the container
COPY package*.json ./

# Install project dependencies
RUN npm install

# Copy the entire project to the container
COPY . .

# Specify the port number that the container should expose
EXPOSE 80

# Define the command to run your Node.js application
CMD ["npm", "start"]
