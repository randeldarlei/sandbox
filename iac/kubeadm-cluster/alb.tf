resource "aws_lb" "k8s_alb" {
  name               = "k8s-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
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
  vpc_id   = aws_vpc.cluster_vpc.id

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

resource "aws_lb_target_group_attachment" "worker1" {
  target_group_arn = aws_lb_target_group.k8s_tg.arn
  target_id        = aws_instance.worker_1.id
  port             = 30007
}

resource "aws_lb_target_group_attachment" "worker2" {
  target_group_arn = aws_lb_target_group.k8s_tg.arn
  target_id        = aws_instance.worker_2.id
  port             = 30007
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
