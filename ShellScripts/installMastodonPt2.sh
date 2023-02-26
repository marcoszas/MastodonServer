#!/bin/bash

# This is the second part of the sript. It needs to be divided in two because of the reboot.

# Create application directory
sudo mkdir /opt/mastodon/

# Create directories related to database operations.
sudo mkdir -p /opt/mastodon/database/{postgresql,redis,elasticsearch}

# Create directories related to web applications
sudo mkdir -p /opt/mastodon/web/{public,system}

# Fix permissions on web directories
sudo chown 991:991 /opt/mastodon/web/{public,system}

# Fix permissions on elasticsearch directory
sudo chown 1000 /opt/mastodon/database/elasticsearch

# Create Docker compose file. We should create this in a separate file and then get it from there.
# This way the user can change the configuration. Or maybe we can show where the file is going to be saved.
cat << EOF | sudo tee /opt/mastodon/docker-compose.yml
version: '3'

services:
  postgresql:
    image: postgres:14
    env_file: database.env
    restart: always
    shm_size: 256mb
    healthcheck:
      test: ['CMD', 'pg_isready', '-U', 'postgres']
    volumes:
      - postgresql:/var/lib/postgresql/data
    networks:
      - internal_network

#  pgbouncer:
#    image: edoburu/pgbouncer:1.12.0
#    env_file: database.env
#    depends_on:
#      - postgresql
#    healthcheck:
#      test: ['CMD', 'pg_isready', '-h', 'localhost']
#    networks:
#      - internal_network

  redis:
    image: redis:7
    restart: always
    healthcheck:
      test: ['CMD', 'redis-cli', 'ping']
    volumes:
      - redis:/data
    networks:
      - internal_network

  redis-volatile:
    image: redis:7
    restart: always
    healthcheck:
      test: ['CMD', 'redis-cli', 'ping']
    networks:
      - internal_network

  elasticsearch:
    image: elasticsearch:7.17.3
    restart: always
    env_file: database.env
    environment:
      - cluster.name=elasticsearch-mastodon
      - discovery.type=single-node
      - bootstrap.memory_lock=true
      - xpack.security.enabled=true
      - ingest.geoip.downloader.enabled=false
    ulimits:
      memlock:
        soft: -1
        hard: -1
    healthcheck:
      test: ["CMD-SHELL", "nc -z elasticsearch 9200"]
    volumes:
      - elasticsearch:/usr/share/elasticsearch/data
    networks:
      - internal_network

  website:
    image: tootsuite/mastodon:v4.0.2
    env_file:
      - application.env
      - database.env
    command: bash -c "bundle exec rails s -p 3000"
    restart: always
    depends_on:
      - postgresql
#      - pgbouncer
      - redis
      - redis-volatile
      - elasticsearch
    ports:
      - '127.0.0.1:3000:3000'
    networks:
      - internal_network
      - external_network
    healthcheck:
      test: ['CMD-SHELL', 'wget -q --spider --proxy=off localhost:3000/health || exit 1']
    volumes:
      - uploads:/mastodon/public/system

  shell:
    image: tootsuite/mastodon:v4.0.2
    env_file:
      - application.env
      - database.env
    command: /bin/bash
    restart: "no"
    networks:
      - internal_network
      - external_network
    volumes:
      - uploads:/mastodon/public/system

  streaming:
    image: tootsuite/mastodon:v4.0.2
    env_file:
      - application.env
      - database.env
    command: node ./streaming
    restart: always
    depends_on:
      - postgresql
#      - pgbouncer
      - redis
      - redis-volatile
      - elasticsearch
    ports:
      - '127.0.0.1:4000:4000'
    networks:
      - internal_network
      - external_network
    healthcheck:
      test: ['CMD-SHELL', 'wget -q --spider --proxy=off localhost:4000/api/v1/streaming/health || exit 1']

  sidekiq:
    image: tootsuite/mastodon:v4.0.2
    env_file:
      - application.env
      - database.env
    command: bundle exec sidekiq
    restart: always
    depends_on:
      - postgresql
#      - pgbouncer
      - redis
      - redis-volatile
      - website
    networks:
      - internal_network
      - external_network
    healthcheck:
      test: ['CMD-SHELL', "ps aux | grep '[s]idekiq\ 6' || false"]
    volumes:
      - uploads:/mastodon/public/system

networks:
  external_network:
  internal_network:
    internal: true

volumes:
  postgresql:
    driver_opts:
      type: none
      device: /opt/mastodon/database/postgresql
      o: bind
  redis:
    driver_opts:
      type: none
      device: /opt/mastodon/database/redis
      o: bind
  elasticsearch:
    driver_opts:
      type: none
      device: /opt/mastodon/database/elasticsearch
      o: bind
  uploads:
    driver_opts:
      type: none
      device: /opt/mastodon/web/system
      o: bind
EOF


# Initialize empty application configuration
sudo touch /opt/mastodon/application.env
sudo touch /opt/mastodon/database.env

# Generate secrets
temp_file=$(mktemp)
sudo chmod 660 "$temp_file"
sudo docker-compose -f /opt/mastodon/docker-compose.yml run --rm shell bundle exec rake secret | tail -n 1 | cat >> "$temp_file"
sudo docker-compose -f /opt/mastodon/docker-compose.yml run --rm shell bundle exec rake secret | tail -n 1 | cat >> "$temp_file"

secret_key_base=$(head -n 1 "$temp_file")
otp_secret=$(tail -n 1 "$temp_file")

cat >> ~/secrets.txt << EOF
SECRET_KEY_BASE=$secret_key_base
OTP_SECRET=$otp_secret
EOF

rm -rf "$temp_file"

# Generate VAPID_PRIVATE_KEY and VAPID_PRIVATE_KEY
sudo docker-compose -f /opt/mastodon/docker-compose.yml run --rm shell bundle exec rake mastodon:webpush:generate_vapid_key | cat >> ~/vapidKeys.txt

# Generate postgresql and elasticsearch passwords
postgres_psswd=$(openssl rand -hex 15)
elasticsearch_psswd=$(openssl rand -hex 15)

cat >> ~/pePasswds.txt << EOF
POSTGRES_PASSWORD=$postgres_psswd
ELASTICSEARCH_PASSWORD=$elasticsearch_psswd
EOF


# Create database configuration file
cat << EOF | sudo tee /opt/mastodon/database.env
# postgresql configuration
POSTGRES_USER=mastodon
POSTGRES_DB=mastodon_production
POSTGRES_PASSWORD=$postgres_psswd

# pgbouncer configuration
#POOL_MODE=transaction
#ADMIN_USERS=postgres,mastodon
#DATABASE_URL="postgres://mastodon:$postgres_psswd@postgresql:5432/mastodon_production"

# elasticsearch
ES_JAVA_OPTS=-Xms512m -Xmx512m
ELASTIC_PASSWORD=$elasticsearch_psswd

# mastodon database configuration
#DB_HOST=pgbouncer
DB_HOST=postgresql
DB_USER=mastodon
DB_NAME=mastodon_production
DB_PASS=$postgres_psswd
DB_PORT=5432

REDIS_HOST=redis
REDIS_PORT=6379

CACHE_REDIS_HOST=redis-volatile
CACHE_REDIS_PORT=6379

ES_ENABLED=true
ES_HOST=elasticsearch
ES_PORT=9200
ES_USER=elastic
ES_PASS=$elasticsearch_psswd
EOF

secrets=$(cat ~/secrets.txt)
vapid_keys=$(cat ~/vapidKeys.txt)

# Create application configuration file
cat << EOF | sudo tee /opt/mastodon/application.env
# environment
RAILS_ENV=production
NODE_ENV=production

# domain
LOCAL_DOMAIN=$HOSTNAME

# redirect to the first profile
SINGLE_USER_MODE=true

# do not serve static files
RAILS_SERVE_STATIC_FILES=false

# concurrency
WEB_CONCURRENCY=2
MAX_THREADS=5

# pgbouncer
#PREPARED_STATEMENTS=false

# locale
DEFAULT_LOCALE=en

# email, not used
SMTP_SERVER=localhost
SMTP_PORT=587
SMTP_FROM_ADDRESS=notifications@$HOSTNAME

# secrets
$secrets

$vapid_keys
EOF

# Secure these files
sudo chmod 600 /opt/mastodon/application.env
sudo chmod 600 /opt/mastodon/database.env

# Create temporary volume pointing to /opt/mastodon/web/public directory
sudo docker volume create --opt type=none --opt device=/opt/mastodon/web/public --opt o=bind temporary_static

# Copy static files
sudo docker run --rm -v "temporary_static:/static" tootsuite/mastodon:v4.0.2 bash -c "cp -r /opt/mastodon/public/* /static/"

# Remove temporary volume
sudo docker volume rm temporary_static

# Install nginx web-server
sudo apt install nginx

# Disable default virtual host
sudo unlink /etc/nginx/sites-enabled/default

# Create directory for SSL certificates
sudo mkdir /etc/nginx/ssl

# Create certificate and private key
sudo openssl req -subj "/commonName=$HOSTNAME/" -x509 -nodes -days 730 -newkey rsa:2048 -keyout /etc/nginx/ssl/"$HOSTNAME".key -out /etc/nginx/ssl/"$HOSTNAME".crt

# Create virtual host. PLACING ENV VARIABLES HERE COULD BE A POTENTIAL PROBLEM. REVISE IT.
cat << EOF | sudo tee /etc/nginx/sites-available/mastodon
map '$http_upgrade' '$connection_upgrade' {
  default upgrade;
  ''      close;
}

upstream backend {
    server 127.0.0.1:3000 fail_timeout=0;
}

upstream streaming {
    server 127.0.0.1:4000 fail_timeout=0;
}

proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=CACHE:10m inactive=7d max_size=1g;

server {
  listen 80;
  server_name $HOSTNAME;
  location / { return 301 https://'$host$request_uri'; }
}

server {
  listen 443 ssl http2;
  server_name $HOSTNAME;

  ssl_protocols TLSv1.2 TLSv1.3;
  ssl_ciphers HIGH:!MEDIUM:!LOW:!aNULL:!NULL:!SHA;
  ssl_prefer_server_ciphers on;
  ssl_session_cache shared:SSL:10m;
  ssl_session_tickets off;

  ssl_certificate     /etc/nginx/ssl/$HOSTNAME.crt;
  ssl_certificate_key /etc/nginx/ssl/$HOSTNAME.key;

  keepalive_timeout    70;
  sendfile             on;
  client_max_body_size 80m;

  root /opt/mastodon/web/public;

  gzip on;
  gzip_disable "msie6";
  gzip_vary on;
  gzip_proxied any;
  gzip_comp_level 6;
  gzip_buffers 16 8k;
  gzip_http_version 1.1;
  gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript image/svg+xml image/x-icon;

  add_header Strict-Transport-Security "max-age=31536000" always;

  location / {
    try_files '$uri' @proxy;
  }

  # iOS
  proxy_force_ranges on;

  location ~ ^/(system/accounts/avatars|system/media_attachments/files) {
    add_header Cache-Control "public, max-age=31536000, immutable";
    add_header Strict-Transport-Security "max-age=31536000" always;
    root /opt/mastodon/;
    try_files '$uri' @proxy;
  }

  location ~ ^/(emoji|packs) {
    add_header Cache-Control "public, max-age=31536000, immutable";
    add_header Strict-Transport-Security "max-age=31536000" always;
    try_files '$uri' @proxy;
  }

  location /sw.js {
    add_header Cache-Control "public, max-age=0";
    add_header Strict-Transport-Security "max-age=31536000" always;
    try_files '$uri' @proxy;
  }

  location @proxy {
    proxy_set_header Host '$host';
    proxy_set_header X-Real-IP '$remote_addr';
    proxy_set_header X-Forwarded-For '$proxy_add_x_forwarded_for';
    proxy_set_header X-Forwarded-Proto '$scheme';
    proxy_set_header Proxy "";
    proxy_pass_header Server;

    proxy_pass http://backend;
    proxy_buffering on;
    proxy_redirect off;
    proxy_http_version 1.1;
    proxy_set_header Upgrade '$http_upgrade';
    proxy_set_header Connection '$connection_upgrade';

    proxy_cache CACHE;
    proxy_cache_valid 200 7d;
    proxy_cache_valid 410 24h;
    proxy_cache_use_stale error timeout updating http_500 http_502 http_503 http_504;
    add_header X-Cached '$upstream_cache_status';
    add_header Strict-Transport-Security "max-age=31536000" always;

    tcp_nodelay on;
  }

  location /api/v1/streaming {
    proxy_set_header Host '$host';
    proxy_set_header X-Real-IP '$remote_addr';
    proxy_set_header X-Forwarded-For '$proxy_add_x_forwarded_for';
    proxy_set_header X-Forwarded-Proto '$scheme';
    proxy_set_header Proxy "";

    proxy_pass http://streaming;
    proxy_buffering off;
    proxy_redirect off;
    proxy_http_version 1.1;
    proxy_set_header Upgrade '$http_upgrade';
    proxy_set_header Connection '$connection_upgrade';

    tcp_nodelay on;
  }

  error_page 500 501 502 503 504 /500.html;
}
EOF

# Enable virtual host
sudo ln -s /etc/nginx/sites-available/mastodon /etc/nginx/sites-enabled

# Restart web server
sudo systemctl restart nginx

# Pull images
sudo docker-compose -f /opt/mastodon/docker-compose.yml pull

# Create mastodon service file
cat << EOF | sudo tee /etc/systemd/system/mastodon.service
[Unit]
Description=Mastodon service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes

WorkingDirectory=/opt/mastodon
ExecStart=/usr/bin/docker-compose -f /opt/mastodon/docker-compose.yml up -d
ExecStop=/usr/bin/docker-compose -f /opt/mastodon/docker-compose.yml down

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload

# Start postgresql database and pgbouncer
sudo docker-compose -f /opt/mastodon/docker-compose.yml up -d postgresql redis redis-volatile

# Here we might need to create a function that checks wheter the database is started already or not
# For that I think we could execute the ps command and do a grep to see if the healthy keyword appears three times.
# Until that we're just going to use sleep command.
sudo docker-compose -f /opt/mastodon/docker-compose.yml ps
sleep 10

# Setup database using shell container
sudo docker-compose -f /opt/mastodon/docker-compose.yml run --rm shell bundle exec rake db:setup

# This is used for database migrations
# sudo docker-compose -f /opt/mastodon/docker-compose.yml run --rm shell bundle exec rake db:migrate

# Start and enable service
sudo systemctl enable --now mastodon.service

# Check status
sudo docker-compose -f /opt/mastodon/docker-compose.yml ps

# Up until this point the Mastodon instance should be up and running. Next steps would imply creating the admin user.
