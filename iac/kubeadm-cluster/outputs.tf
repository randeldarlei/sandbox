output "Control_Plane_Public_Ip" {
  description = "Instance Public Ip Value"  
  value = aws_instance.control_plane.public_ip
}


output "Alb_dns_name" {
    description = "Application Load Balancer DNS Name"
    value = aws_lb.k8s_alb.dns_name
}

output "private_key_pem" {
  value     = tls_private_key.k8s_workers.private_key_pem
  sensitive = true
}

