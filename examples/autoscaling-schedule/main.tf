# Terraform autoscaling group with lambda scheduler

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "main" {
  vpc_id     = "${aws_vpc.main.id}"
  cidr_block = "10.0.1.0/24"
}

resource "aws_launch_configuration" "as_conf" {
  name          = "web_config"
  image_id      = "${data.aws_ami.ubuntu.id}"
  instance_type = "t2.micro"
}

resource "aws_autoscaling_group" "bar" {
  name                      = "foobar3-terraform-test"
  max_size                  = 5
  min_size                  = 2
  health_check_grace_period = 300
  health_check_type         = "EC2"
  desired_capacity          = 4
  force_delete              = true
  launch_configuration      = "${aws_launch_configuration.as_conf.name}"
  vpc_zone_identifier       = ["${aws_subnet.main.id}"]

  tag {
    key                 = "tostop"
    value               = "true"
    propagate_at_launch = true
  }
}

module "autoscaling-stop-friday" {
  source                         = "diodonfrost/lambda-scheduler-stop-start/aws"
  name                           = "stop-autoscaling"
  cloudwatch_schedule_expression = "cron(0 23 ? * FRI *)"
  schedule_action                = "stop"
  ec2_schedule                   = "false"
  rds_schedule                   = "false"
  autoscaling_schedule           = "true"
  resources_tag                  = {
    key   = "tostop"
    value = "true"
  }
}

module "ec2-start-monday" {
  source                         = "diodonfrost/lambda-scheduler-stop-start/aws"
  name                           = "start-autoscaling"
  cloudwatch_schedule_expression = "cron(0 07 ? * MON *)"
  schedule_action                = "start"
  ec2_schedule                   = "false"
  rds_schedule                   = "false"
  autoscaling_schedule           = "true"
  resources_tag                  = {
    key   = "tostop"
    value = "true"
  }
}
