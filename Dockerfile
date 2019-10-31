FROM node:10
WORKDIR /app
COPY . /app
RUN npm install
CMD ["npm", "start"]
ENV SECRET_WORD "Elephant"
EXPOSE 8080