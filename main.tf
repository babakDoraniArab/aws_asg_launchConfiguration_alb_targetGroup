provider "aws" {
  profile = "default"
  region  = "eu-west-1"
}

#////////////////////////////////
#   VPC and Subnets
#////////////////////////////////

resource "aws_default_vpc" "default" {}

resource "aws_default_subnet" "default_az1" {
  availability_zone = "eu-west-1a"

  tags = {
    "Terraform" : "true"
  }
}
resource "aws_default_subnet" "default_az2" {
  availability_zone = "eu-west-1b"

  tags = {
    "Terraform" : "true"
  }
}
#////////////////////////////////
#  Security Group
#////////////////////////////////

resource "aws_security_group" "prod_web2" {
  name        = "prod-web2"
  description = "Allow standard http and https ports inbount and everything outbound"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    "Terraform" : "true"
  }
}
resource "aws_security_group" "prod_web_lb2" {
  name        = "prod-web-lb2"
  description = "Allow standard http and https ports inbount and everything outbound"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    "Terraform" : "true"
  }
}
#////////////////////////////////
#   Auto Scaling Group
#////////////////////////////////
resource "aws_launch_configuration" "prod_web" {
  name            = "prod_web"
  image_id        = "ami-096f7a9ab885b50f4"
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.prod_web2.id]
  key_name        = "Demo"
  user_data       = <<-EOF

#!/bin/bash
yum update -y
yum install -y polkit
yum install -y httpd
systemctl start httpd
systemctl enable httpd
yum install -y git
cd /var/www/html
git clone https://github.com/babakDoraniArab/testHtmlTemplate.git
mv testHtmlTemplate/* ./
rm -R testHtmlTemplate

     EOF
}

resource "aws_autoscaling_group" "prod_web" {
  name                 = "prod-web"
  max_size             = 5
  min_size             = 2
  desired_capacity     = 2
  launch_configuration = aws_launch_configuration.prod_web.name
  vpc_zone_identifier  = [aws_default_subnet.default_az1.id, aws_default_subnet.default_az2.id]
}

#////////////////////////////////
#   LoadBalancer
#////////////////////////////////
resource "aws_lb" "prod_web" {
  name               = "prod-web"
  internal           = false
  load_balancer_type = "application"

  security_groups = [aws_security_group.prod_web_lb2.id]
  subnets         = [aws_default_subnet.default_az1.id, aws_default_subnet.default_az2.id]

  tags = {
    "Terraform" : "true"
  }

}

resource "aws_lb_target_group" "prod_web" {
  name     = "prod-web"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_default_vpc.default.id
  tags = {
    "Terraform" : "true"
  }
}

#////////////////////////////////
#   Auto Scaling Attachment
#////////////////////////////////
# Create a new ALB Target Group attachment
resource "aws_autoscaling_attachment" "asg_attachment_bar" {
  autoscaling_group_name = aws_autoscaling_group.prod_web.id
  alb_target_group_arn   = aws_lb_target_group.prod_web.arn
}


#////////////////////////////////
#   AWS LoadBalancing Listener
#////////////////////////////////
# Create a new ALB Target Group attachment

resource "aws_lb_listener" "prod_web" {
  load_balancer_arn = aws_lb.prod_web.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.prod_web.arn
  }
}