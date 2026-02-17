#!/bin/bash
set -e  # Exit on any error
set -x  # Print commands for debugging

# Log everything to a file for easier debugging
exec > >(tee /var/log/jenkins-agent-setup.log)
exec 2>&1

echo "Starting Jenkins agent setup..."

# Wait for network to be fully ready
echo "Waiting for network connectivity..."
for i in {1..30}; do
    if curl -s --head --request GET http://www.google.com | grep "200 OK" > /dev/null; then 
        echo "Network is ready!"
        break
    else
        echo "Waiting for network... attempt $i/30"
        sleep 10
    fi
done

# Double check we can reach the Jenkins controller
echo "Checking Jenkins controller connectivity..."
for i in {1..10}; do
    if curl -s -I http://jenkins-controller.internal:8080/ | grep "HTTP" > /dev/null; then
        echo "Jenkins controller is reachable!"
        break
    else
        echo "Waiting for Jenkins controller... attempt $i/10"
        sleep 10
    fi
done

# Update package lists with retry
echo "Updating package lists..."
for i in {1..5}; do
    sudo apt-get update && break || {
        echo "apt update failed, retrying in 10s..."
        sleep 10
    }
done

# Install Java and pipeline dependencies
echo "Installing Java, Python, pip, and Docker..."
for i in {1..5}; do
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
        openjdk-17-jre \
        python3 \
        python3-pip \
        docker.io \
        && break || {
        echo "Installation failed, retrying in 10s..."
        sleep 10
    }
done

# Verify installations
echo "Verifying installations..."
java -version
python3 --version
pip3 --version
docker --version

# Add ubuntu user to docker group so pipeline can run docker commands
sudo usermod -aG docker ubuntu

# Install AWS CLI
echo "Installing AWS CLI..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y unzip
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
unzip -q /tmp/awscliv2.zip -d /tmp
sudo /tmp/aws/install
rm -rf /tmp/awscliv2.zip /tmp/aws
aws --version

# Install kubectl
echo "Installing kubectl..."
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.35/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.35/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y kubectl
kubectl version --client

# Create Jenkins agent directory AS UBUNTU USER
echo "Creating agent directory..."
sudo -u ubuntu mkdir -p /home/ubuntu/jenkins-agent
cd /home/ubuntu/jenkins-agent

# Download agent.jar AS UBUNTU USER
echo "Downloading agent.jar..."
for i in {1..10}; do
    if sudo -u ubuntu curl -sO http://jenkins-controller.internal:8080/jnlpJars/agent.jar; then
        echo "agent.jar downloaded successfully!"
        break
    else
        echo "Download failed, retrying in 10s... attempt $i/10"
        sleep 10
    fi
done

# Verify download
if [ ! -f agent.jar ]; then
    echo "ERROR: Failed to download agent.jar after all retries"
    exit 1
fi

# Ensure proper ownership
sudo chown -R ubuntu:ubuntu /home/ubuntu/jenkins-agent

echo "Agent directory ownership:"
ls -lh /home/ubuntu/jenkins-agent/

# Create systemd service
echo "Creating systemd service..."
sudo tee /etc/systemd/system/jenkins-agent.service <<'EOF'
[Unit]
Description=Jenkins Agent
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/jenkins-agent
ExecStart=/usr/bin/java -jar /home/ubuntu/jenkins-agent/agent.jar -url http://jenkins-controller.internal:8080/ -secret 036da4a234ed7bc0c8acea8a874fc33ad0ef258a5018fd4a6a481f0c51eaf2f0 -name "agent-2" -webSocket -workDir "/home/ubuntu/jenkins-agent"
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the service
echo "Starting Jenkins agent service..."
sudo systemctl daemon-reload
sudo systemctl enable jenkins-agent
sudo systemctl start jenkins-agent

# Give it a moment to start
sleep 5

echo "Jenkins agent setup complete!"
sudo systemctl status jenkins-agent --no-pager

# Wait for EKS cluster to be ready, then configure kubeconfig
echo "Waiting for EKS cluster to become ACTIVE..."
for i in {1..60}; do
    STATUS=$(aws eks describe-cluster --name dev-eks --region us-east-1 --query 'cluster.status' --output text 2>/dev/null)
    if [ "$STATUS" = "ACTIVE" ]; then
        echo "EKS cluster is ACTIVE!"
        break
    else
        echo "Cluster status: $STATUS - waiting... attempt $i/60"
        sleep 30
    fi
done

echo "Configuring kubeconfig for EKS..."
sudo -u ubuntu aws eks update-kubeconfig --name dev-eks --region us-east-1

echo "Setup finished at $(date)"