data "aws_vpc" "default" {
  default = true
}

resource "aws_security_group" "this" {
  name        = "dockerhub-server-sg"
  description = "Allow SSH and HTTP Traffic"

  vpc_id = data.aws_vpc.default.id

  #SSH
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #HTTP
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #Custom
  ingress {
    description = "Custom"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "dockerhub-server-sg"
  }


}


resource "aws_instance" "this" {
  instance_type = var.instance_type
  ami           = var.ami_id

  key_name = "demo-key"

  vpc_security_group_ids = [aws_security_group.this.id]

  user_data = file("${path.module}/dockersetup.sh")

  tags = {
    Name = "DockerHub-Server"
  }
}