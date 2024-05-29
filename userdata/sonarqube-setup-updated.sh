#!/bin/bash

# Backup and modify sysctl.conf
cp /etc/sysctl.conf /root/sysctl.conf_backup
cat <<EOT > /etc/sysctl.conf
vm.max_map_count=262144
fs.file-max=65536
EOT

# Set ulimit in appropriate configuration files
cp /etc/security/limits.conf /root/sec_limit.conf_backup
cat <<EOT > /etc/security/limits.conf
sonarqube   -   nofile   65536
sonarqube   -   nproc    4096
EOT

# Update and install OpenJDK
sudo apt-get update -y
sudo apt install net-tools -y
sudo apt-get install openjdk-11-jdk -y
sudo update-alternatives --config java

java -version

# Install PostgreSQL
sudo apt update
wget -q https://www.postgresql.org/media/keys/ACCC4CF8.asc -O - | sudo apt-key add -

sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ `lsb_release -cs`-pgdg main" >> /etc/apt/sources.list.d/pgdg.list'
sudo apt-get update
sudo apt-get install postgresql postgresql-contrib -y
sudo systemctl enable postgresql.service
sudo systemctl start postgresql.service
sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD 'admin123';"
sudo -u postgres createuser sonar
sudo -u postgres psql -c "ALTER USER sonar WITH ENCRYPTED PASSWORD 'admin123';"
sudo -u postgres psql -c "CREATE DATABASE sonarqube OWNER sonar;"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE sonarqube TO sonar;"
sudo systemctl restart postgresql
netstat -tulpena | grep postgres

# Install SonarQube
sudo mkdir -p /sonarqube/
cd /sonarqube/
sudo curl -O https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-8.3.0.34182.zip
sudo apt-get install zip -y
sudo unzip -o sonarqube-8.3.0.34182.zip -d /opt/
sudo mv /opt/sonarqube-8.3.0.34182/ /opt/sonarqube
sudo groupadd sonar
sudo useradd -c "SonarQube - User" -d /opt/sonarqube/ -g sonar sonar
sudo chown sonar:sonar /opt/sonarqube/ -R

# Configure SonarQube
cp /opt/sonarqube/conf/sonar.properties /root/sonar.properties_backup
cat <<EOT > /opt/sonarqube/conf/sonar.properties
sonar.jdbc.username=sonar
sonar.jdbc.password=admin123
sonar.jdbc.url=jdbc:postgresql://localhost/sonarqube
sonar.web.host=0.0.0.0
sonar.web.port=9000
sonar.web.javaAdditionalOpts=-server
sonar.search.javaOpts=-Xmx512m -Xms512m -XX:+HeapDumpOnOutOfMemoryError
sonar.log.level=INFO
sonar.path.logs=logs
EOT

# Create systemd service for SonarQube
cat <<EOT > /etc/systemd/system/sonarqube.service
[Unit]
Description=SonarQube service
After=syslog.target network.target

[Service]
Type=forking

ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop

User=sonar
Group=sonar
Restart=always

LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOT

# Enable and start SonarQube service
systemctl daemon-reload
systemctl enable sonarqube.service
systemctl start sonarqube.service

# Install and configure Nginx
sudo apt-get install nginx -y
rm -rf /etc/nginx/sites-enabled/default
rm -rf /etc/nginx/sites-available/default
cat <<EOT > /etc/nginx/sites-available/sonarqube
server {
    listen      80;
    server_name sonar.thedevcloud.xyz;

    access_log  /var/log/nginx/sonar.access.log;
    error_log   /var/log/nginx/sonar.error.log;

    proxy_buffers 16 64k;
    proxy_buffer_size 128k;

    location / {
        proxy_pass  http://127.0.0.1:9000;
        proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504;
        proxy_redirect off;

        proxy_set_header    Host            \$host;
        proxy_set_header    X-Real-IP       \$remote_addr;
        proxy_set_header    X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header    X-Forwarded-Proto http;
    }
}
EOT
ln -s /etc/nginx/sites-available/sonarqube /etc/nginx/sites-enabled/sonarqube
systemctl enable nginx.service
systemctl start nginx.service

# Allow necessary ports in UFW
sudo ufw allow 80/tcp
sudo ufw allow 9000/tcp
sudo ufw allow 9001/tcp

# Apply sysctl changes
sudo sysctl -p

# Restart services to apply changes
sudo systemctl restart postgresql.service
sudo systemctl restart sonarqube.service
sudo systemctl restart nginx.service

# Ensure UFW rules are applied
sudo ufw reload

echo "Setup complete. Please verify all services are running as expected."
