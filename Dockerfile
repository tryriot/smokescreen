# Build stage
FROM golang:1.25-trixie AS builder

WORKDIR /app

# Copy Go module files
COPY go.mod go.sum ./

RUN go mod download

COPY . .

RUN go build -o smokescreen main.go

# Runtime stage
FROM debian:trixie-slim

WORKDIR /app

# Copy binary from builder stage
COPY --from=builder /app/smokescreen ./

ARG DD_API_KEY=replace_with_your_api_key_if_needed
ENV DD_API_KEY=${DD_API_KEY}
ENV DD_AGENT_MAJOR_VERSION=7
ENV DD_INSTALL_ONLY=true

RUN apt-get update && apt-get install -y curl bash && \
    bash -c "$(curl -L https://s3.amazonaws.com/dd-agent/scripts/install_script_agent7.sh)" && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

ENV DD_SITE=datadoghq.eu
ENV DD_LOGS_ENABLED=true
ENV DD_SERVICE=smokescreen
ENV DD_VERSION=1.0.0
ENV DD_ENV=production
ENV DD_LOGS_CONFIG_CONTAINER_COLLECT_ALL=true

EXPOSE 4750

ENV DD_HOSTNAME=smokescreen-container

RUN echo '#!/bin/bash' > /start.sh && \
    echo 'export DD_HOSTNAME=${DD_HOSTNAME:-$(hostname)}' >> /start.sh && \
    echo 'mkdir -p /etc/datadog-agent/conf.d/smokescreen.d' >> /start.sh && \
    echo 'cat > /etc/datadog-agent/conf.d/smokescreen.d/conf.yaml << EOF' >> /start.sh && \
    echo 'logs:' >> /start.sh && \
    echo '  - type: file' >> /start.sh && \
    echo '    path: "/var/log/smokescreen/smokescreen.log"' >> /start.sh && \
    echo '    service: "smokescreen"' >> /start.sh && \
    echo '    source: "go"' >> /start.sh && \
    echo 'EOF' >> /start.sh && \
    echo '/opt/datadog-agent/bin/agent/agent run &' >> /start.sh && \
    echo 'sleep 2' >> /start.sh && \
    echo 'mkdir -p /var/log/smokescreen' >> /start.sh && \
    echo 'exec ./smokescreen --statsd-address localhost:8125 >> /var/log/smokescreen/smokescreen.log 2>&1' >> /start.sh && \
    chmod +x /start.sh

CMD ["/start.sh"]


