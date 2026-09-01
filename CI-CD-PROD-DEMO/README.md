=========================================================
PRODUCTION PROJECT DEMONSTRATING CI/CD (Continuous Delivery and Continuous Deployment)
=========================================================
Prerequisite
1. Have an ec2 instance
2. Create a docker hub token. 
3. Create a secret on GitHub and name it DOCKERHUB_USERNAME & DOCKERHUB_TOKEN. This is for the DockerHub username and token 
4. When creating the ec2 instance run a script to install docker on the ec2 instance 

=====================
#!/bin/bash

sudo apt update

sudo apt install -y docker.io

sudo systemctl enable docker
sudo systemctl start docker

sudo usermod -aG docker ubuntu
============================

4. Call this script in your resource block when creating the ec2 instance.
5.  Make sure you generate an ssh key pair. This will be used to login.
6. Create another secret on GitHub as below
	EC2_HOST - the value will be the Public IP
	EC2_USERNAME - the value will be the username - ubuntu.
					in the project we used an ubuntu server, hence the username 	
					will be ubuntu.
	EC2_SSH_KEY - this will contain the private ssh key

============================================================
The python Application
————————————
Filename: app.py
——————————
from flask import Flask

app = Flask(__name__)

@app.route("/")
def home():
    return "Hello from Sample App!"


@app.route("/health")
def health():
    return "OK"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)

==============================================================
The Test Script
————————
filename: test_app.py
————————————-
from app import app

def test_home():
    client = app.test_client()

    response = client.get("/")

    assert response.status_code == 200
    assert response.data == b"Hello from Sample App!"

def test_health():
    client = app.test_client()

    response = client.get("/health")

    assert response.status_code == 200
    assert response.data == b"OK"

=============================================================
The Docker File
—————————
Filename: Dockerfile
————————————-
FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 5000

CMD ["python", "app.py"]

==============================================================
The Workflow File
———————————
Filename: deploy.yml
———————————
name: CI-CD-Deployment

on:
  push:
    branches:
      - main
  
  workflow_dispatch:

jobs:
  # ===========
  # CI
  # ===========
  test:
    name: Continuous Integration
    runs-on: ubuntu-latest

    steps:
      # checkout application code
      - name: checkout repository
        uses: actions/checkout@v4
      
      # Setup Python
      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.12"

      # Install dependencies
      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          pip install -r requirements.txt
          pip install pytest

      # Run tests
      - name: Run tests
        run: |
          pytest

      # Build Docker image to verify Dockerfile works
      - name: Build Docker image
        run: |
          docker build \
            -t sample-app${{ github.sha }} .


  # ========================
  # Continuous Delivery
  # ========================
  publish:
    name: Continuous Delivery
    needs: test

    runs-on: ubuntu-latest

    steps:
      # checkout repository
      - name: checkout repository
        uses: actions/checkout@v4

      # Login to DockerHub
      - name: Login to DockerHub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME}}
          password: ${{ secrets.DOCKERHUB_TOKEN}}

      # Build and push Docke Image
      - name: Build and Push Docker Image
        uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          tags: |
            ${{ secrets.DOCKERHUB_USERNAME }}/sample-app:latest
            ${{ secrets.DOCKERHUB_USERNAME }}/sample-app:${{ github.sha }}

  # ====================
  # ACTUAL DEPLOYMENT
  # ====================
  deploy:
    name: Deploy to Production
    needs: publish

    runs-on: ubuntu-latest

    environment:
      name: production

    steps:
      # Install SSH client
      - name: Install SSH client
        run: |
          sudo apt-get update
          sudo apt-get install -y openssh-client

      # Configure SSH
      - name: Configure SSH
        
        run: |
          mkdir -p ~/.ssh 

          echo "${{ secrets.EC2_SSH_KEY }}" > ~/.ssh/ec2_key
          
          chmod 600 ~/.ssh/ec2_key 

          ssh-keyscan -H ${{ secrets.EC2_HOST }} >> ~/.ssh/known_hosts 

      # Deploy application to the EC2
      - name: Deploy to EC2
        run: |
          ssh \
            -i ~/.ssh/ec2_key \
            ${{ secrets.EC2_USERNAME }}@${{ secrets.EC2_HOST }} << 'EOF'

          # Login to DockerHub 
            echo "${{ secrets.DOCKERHUB_TOKEN }}" | \
              docker login \
              -u "${{ secrets.DOCKERHUB_USERNAME }}" \
              --password-stdin 

          # Pull the exact image built by the commit
            docker pull \
              ${{ secrets.DOCKERHUB_USERNAME }}/sample-app:${{ github.sha }}

          # Stop old container if it exits
            docker stop sample-app || true 

          # Remove old container
            docker rm sample-app || true 

          # Start new container
            docker run -d \
              --name sample-app \
              --restart unless-stopped \
              -p 5000:5000 \
              ${{ secrets.DOCKERHUB_USERNAME }}/sample-app:${{ github.sha }} 
          EOF

      
      # Verify deployment
      - name: Verify deployment 
        run: | 
          ssh \
            -i ~/.ssh/ec2_key \
            ${{ secrets.EC2_USERNAME }}@${{ secrets.EC2_HOST }} << 'EOF'

            echo "Running container:" 
            docker ps 

            echo ""
            echo "Container status:"
            docker inspect \
              --format='{{.State.Status}}' \
              sample-app 

          EOF





In this project we demonstrated how CI, Continuous Delivery and Continuous Deployment works.
We implemented how the flow waits for approval to demonstrate the continuous delivery concept before the actual deployment.
The part of the code that says - 
  environment:
      name: production
Demonstrates the delivery - as this connects to GitHub actions and waits for an approval before it continuous.

To configure the approval process on GitHub 
-> Go to your GitHub repo
-> then go to settings -> Environments
-> Create an Environment name and inside the environment
-> check ‘Required reviewers’
-> Type the name of the reviewers (It is recommended that it should be someone different other than you). 
-> You can check ‘Prevent self-review’ to enforce the above statement in brackets
-> check the ‘wait time’ and give it a time or you can leave it. Then save.

The flow is that 
When a developer commits a code. The CI will build the image and push it to docker hub. Then the we ssh into the ce2 instance and pull the image to run. But before we run it we had to wait for the approval. At this point the continuous delivery has ended. Then we move on to the main deployment after the approval have been given.
We then verify the that the application and docker container is running.


The Major issues I had with this project is mainly syntax. Where majority had to do with indentation. 
This demonstrates how important indentation is to your project.