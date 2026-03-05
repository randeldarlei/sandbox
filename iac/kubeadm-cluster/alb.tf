resource "aws_lb" "k8s_alb" {
  name               = "k8s-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups = [
    aws_security_group.alb_sg.id
  ]

  subnets = [
    aws_subnet.public_cluster_subnet_1.id,
    aws_subnet.public_cluster_subnet_2.id
  ]

  tags = {
    Name = "k8s-alb"
  }
}

resource "aws_lb_target_group" "k8s_tg" {
  name     = "k8s-nodeport-tg"
  port     = 30007
  protocol = "HTTP"
  vpc_id      = aws_vpc.cluster_vpc.id
  target_type = "instance"

  health_check {
    path                = "/"
    port                = "30007"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 10
    matcher             = "200"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.k8s_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.k8s_tg.arn
  }
}

resource "aws_launch_template" "k8s_workers" {
  name_prefix   = "k8s-worker-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t3.medium"
  key_name = aws_key_pair.k8s_workers.key_name

  iam_instance_profile {
    name = aws_iam_instance_profile.k8s_profile.name
  }
  vpc_security_group_ids = [
    aws_security_group.workers_sg.id
  ]
  user_data = base64encode(file("worker-bootstrap.sh"))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "k8s-worker"
    }
  }
}

resource "aws_autoscaling_group" "k8s_workers" {
  desired_capacity = 2
  min_size         = 2
  max_size         = 5
  health_check_type         = "ELB"
  health_check_grace_period = 300
  vpc_zone_identifier = [
    aws_subnet.private_cluster_subnet_1.id,
    aws_subnet.private_cluster_subnet_2.id
  ]

  launch_template {
    id      = aws_launch_template.k8s_workers.id
    version = "$Latest"
  }
  target_group_arns = [
    aws_lb_target_group.k8s_tg.arn
  ]

  tag {
    key                 = "Name"
    value               = "k8s-worker"
    propagate_at_launch = true
  }
}