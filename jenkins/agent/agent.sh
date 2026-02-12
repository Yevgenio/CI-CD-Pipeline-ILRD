sudo tee /etc/systemd/system/jenkins-agent.service <<EOF
[Unit]
Description=Jenkins Agent
After=network.target docker.service
Requires=docker.service

[Service]
User=ubuntu
WorkingDirectory=/home/ubuntu/jenkins-agent
ExecStart=/usr/bin/java -jar /home/ubuntu/jenkins-agent/agent.jar -url http://<JENKINS_CONTROLLER_IP>:8080 -secret <JENKINS_AGENT_SECRET> -name agent-2 -workDir /home/ubuntu/jenkins-agent
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF