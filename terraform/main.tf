# 0. Definición de Variables
variable "docker_user" {}
variable "docker_password" {}
variable "ssh_key_name" {}
variable "bucket_name" {}

provider "aws" {
  region = "us-east-1" 
}

# 1. Backend para el Status (Asegúrate que el bucket exista antes)
terraform {
  backend "s3" {
    bucket  = "examen-suple-grpc-2026" 
    key     = "estado/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}

# 2. Red y VPC
data "aws_vpc" "default" { default = true }
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# 3. Security Group (Añadido puerto 8001 para Redis Insight)
resource "aws_security_group" "sg_final" {
  name        = "sg_${var.bucket_name}"
  description = "Permitir gRPC, SSH y RedisInsight"

  ingress {
    from_port   = 50051
    to_port     = 50051
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Para que puedas entrar a la interfaz de Redis Insight
  ingress {
    from_port   = 8001
    to_port     = 8001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ... (Bloques 4 de ALB y Listener se mantienen igual que tu código) ...

# 5. Launch Template (Ajustado para el nuevo Docker Compose)
resource "aws_launch_template" "template_examen" {
  name_prefix   = "template-${var.bucket_name}"
  image_id      = "ami-0e2c8ccd9e036d13a" 
  instance_type = "t2.micro"
  key_name      = var.ssh_key_name

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.sg_final.id]
  }

  user_data = base64encode(<<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install -y docker.io docker-compose
              sudo systemctl start docker
              sudo systemctl enable docker

              # Login en Docker
              echo "${var.docker_password}" | sudo docker login -u "${var.docker_user}" --password-stdin

              mkdir -p /home/ubuntu/app/servidor
              cd /home/ubuntu/app

              # Crear el .env del servidor (REDIS_HOST ahora es el nombre del servicio en el compose)
              cat <<EOT > servidor/.env
              PORT=50051
              REDIS_HOST=cache-db
              REDIS_PORT=6379
              BUCKET_NAME=${var.bucket_name}
              EOT

              # Crear el docker-compose.yml EXACTAMENTE como el tuyo pero con el server
              cat <<EOT > docker-compose.yml
              version: '3.8'
              services:
                cache-db:
                  image: redis:latest
                  container_name: redis-examen
                  ports:
                    - "6379:6379"
                  restart: always

                grpc-server:
                  image: ${var.docker_user}/servidor-grpc:latest
                  container_name: servidor-grpc-examen
                  ports:
                    - "50051:50051"
                  env_file: servidor/.env
                  depends_on:
                    - cache-db
                  restart: always

                redis-insight:
                  image: redislabs/redisinsight:latest
                  container_name: redis-insight-examen
                  ports:
                    - "8001:8001"
                  depends_on:
                    - cache-db
              EOT

              sudo docker-compose up -d
              EOF
  )
}

# 6. Auto Scaling Group (ASG)
resource "aws_autoscaling_group" "asg_examen" {
  desired_capacity    = 1
  max_size            = 2
  min_size            = 1
  target_group_arns   = [aws_lb_target_group.tg_examen.arn]
  vpc_zone_identifier = data.aws_subnets.default.ids

  launch_template {
    id      = aws_launch_template.template_examen.id
    version = "$Latest"
  }
}

# 7. S3 Bucket
resource "aws_s3_bucket" "bucket_examen" {
  bucket        = var.bucket_name # Usa la variable definida en .tfvars
  force_destroy = true
}

resource "aws_s3_object" "folder_logs" {
  bucket = aws_s3_bucket.bucket_examen.id
  key    = "logs-estudiantes/"
}

# 8. Outputs
output "url_servidor_grpc" {
  value       = aws_lb.alb_examen.dns_name
  description = "DNS del Load Balancer"
}