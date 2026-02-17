# 0. Definición de Variables
variable "docker_user" {}
variable "docker_password" {}
variable "ssh_key_name" {}
variable "bucket_name" {}

provider "aws" {
  region = "us-east-1" 
}

# 1. Backend para el Status
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

# 3. Security Group
resource "aws_security_group" "sg_final" {
  name        = "sgv2_${var.bucket_name}"
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

# 4. Load Balancer (ALB) y Target Group - CONFIGURACIÓN gRPC NATIVA
resource "aws_lb" "alb_examen" {
  name               = "albv2-${substr(var.bucket_name, 0, 20)}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sg_final.id]
  subnets            = data.aws_subnets.default.ids
}

resource "aws_lb_target_group" "tg_examen" {
  name             = "tg-grpcv2-${substr(var.bucket_name, 0, 20)}"
  port             = 50051
  protocol         = "HTTP"
  protocol_version = "GRPC" # CAMBIO CLAVE: Cambiado de HTTP1 a GRPC
  vpc_id           = data.aws_vpc.default.id
  
  health_check {
    enabled             = true
    port                = "50051"
    protocol            = "HTTP"
    path                = "/" # En gRPC esto es ignorado pero requerido por AWS
    matcher             = "12" # CAMBIO CLAVE: Código 12 significa 'Unimplemented' pero indica que el servicio responde
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "listener_grpc" {
  load_balancer_arn = aws_lb.alb_examen.arn
  port              = "50051"
  protocol          = "HTTP" # El listener recibe HTTP/2 (gRPC) en este puerto

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg_examen.arn
  }
}

# 5. Launch Template
resource "aws_launch_template" "template_examen" {
  name_prefix   = "templatev2-${var.bucket_name}"
  image_id      = "ami-0c7217cdde317cfec" 
  instance_type = "t2.micro"
  key_name      = var.ssh_key_name

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "Instancia-gRPC-${var.bucket_name}" # El nombre que verás en la consola
      Proyecto = "Examen-Supletorio"
    }
  }

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

              echo "${var.docker_password}" | sudo docker login -u "${var.docker_user}" --password-stdin

              mkdir -p /home/ubuntu/app/servidor
              cd /home/ubuntu/app

              cat <<EOT > servidor/.env
              PORT=50051
              REDIS_HOST=cache-db
              REDIS_PORT=6379
              BUCKET_NAME=${var.bucket_name}
              EOT

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

# 6. Auto Scaling Group
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

  depends_on = [
    aws_lb.alb_examen,
    aws_lb_target_group.tg_examen,
    aws_lb_listener.listener_grpc
  ]
}

# 7. S3 Bucket
resource "aws_s3_bucket" "bucket_examen" {
  bucket        = var.bucket_name
  force_destroy = true
}

resource "aws_s3_object" "folder_logs" {
  bucket = aws_s3_bucket.bucket_examen.id
  key    = "logs-estudiantes/"
}

# 8. Outputs
output "url_servidor_grpc" {
  value = aws_lb.alb_examen.dns_name
}