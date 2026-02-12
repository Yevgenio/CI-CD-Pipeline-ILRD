FROM docker:27-cli AS dockercli
FROM jenkins/inbound-agent:latest

USER root

COPY --from=dockercli /usr/local/bin/docker /usr/local/bin/docker

RUN groupadd -g 1001 docker && \
    usermod -aG docker jenkins

USER jenkins