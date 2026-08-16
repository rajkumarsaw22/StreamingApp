data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_security_group" "jenkins" {
  name        = "${var.project}-jenkins-sg"
  description = "Jenkins host: SSH for Ansible, 8080 for the Jenkins UI"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.jenkins_allowed_ssh_cidr]
  }

  ingress {
    description = "Jenkins UI"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.jenkins_allowed_web_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Project   = var.project
    ManagedBy = "terraform"
  }
}

resource "aws_instance" "jenkins" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.jenkins_instance_type
  subnet_id              = module.vpc.public_subnets[0]
  key_name               = var.jenkins_key_name
  vpc_security_group_ids = [aws_security_group.jenkins.id]
  iam_instance_profile   = aws_iam_instance_profile.jenkins.name

  # Ansible (terraform/../ansible/playbook.yml) does the actual software install
  # (Docker, kubectl, Helm, AWS CLI, Jenkins + plugins) — this instance boots bare.

  root_block_device {
    volume_size = 30 # cost optimization: enough for Docker image cache, no more
    volume_type = "gp3"
  }

  tags = {
    Name      = "${var.project}-jenkins"
    Project   = var.project
    ManagedBy = "terraform"
  }
}
