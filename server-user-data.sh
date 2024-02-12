#!/bin/bash

sudo yum install nginx -y

TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`

IP=`curl -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/meta-data/public-ipv4`

echo "<h1> Hello World! $IP </h1>" | sudo tee /usr/share/nginx/html/index.html

sudo systemctl start nginx.service