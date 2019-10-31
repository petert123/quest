
resource "aws_instance" "quest_ec2" {
  ami           = "${data.aws_ami.quest_ami.id}"
  instance_type = "t2.nano"
  key_name = "terraformuser-key-pair"
   user_data = <<-EOF
     #!/bin/bash
     sudo yum install docker -y
     sudo service docker start
     sudo yum install git -y
     git clone https://github.com/petert123/quest.git
     cd quest
     sudo docker build -t quest:latest .
     sudo docker run -d -p8080:3000 quest:latest    
EOF
  tags = {
    Name = "Quest"
  }
}

data "aws_ami" "quest_ami" {
    most_recent = true

    filter {
        name   = "name"
        values = ["*amzn-ami-hvm-2018*"]
    }
    filter {
        name   = "virtualization-type"
        values = ["hvm"]
   }
    owners = ["amazon"]
}

resource "aws_elb" "quest_elb" {
  name               = "quest-elb"
  availability_zones = ["us-east-1a","us-east-1b","us-east-1c"]

  listener {
    instance_port     = 8080
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  listener {
    instance_port      = 8080
    instance_protocol  = "http"
    lb_port            = 443
    lb_protocol        = "https"
    ssl_certificate_id = "${aws_iam_server_certificate.quest_cert.arn}"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:8080/"
    interval            = 30
  }

  instances                   = ["${aws_instance.quest_ec2.id}"]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400
  tags = {
    Name = "Quest-elb"
  }
}

resource "aws_iam_server_certificate" "quest_cert" {
  name_prefix      = "quest-cert"
  certificate_body = "${file("quest.crt")}"
  private_key      = "${file("quest.key")}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "quest_access" {
  name = "Quest Access"
  tags = {
    GeneratedBy = "Terraform"
  }
}

resource "aws_security_group_rule" "allow_ssh" {
  type              = "ingress"
  security_group_id = "${aws_security_group.quest_access.id}"
  from_port         = "22"
  to_port           = "22"
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "allow_http" {
  type              = "ingress"
  security_group_id = "${aws_security_group.quest_access.id}"
  from_port         = "8080"
  to_port           = "8080"
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

