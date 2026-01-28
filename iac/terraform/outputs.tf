output "Control_Plane_Public_Ip_Value" {
    description = "Instance Public Ip Value"
    value = aws_instance.control_plane.public_ip
}

output "Worker_1_Public_Ip_Value" {
    description = "Instance Public Ip Value"
    value = aws_instance.worker_1.public_ip
}

output "Worker_2_Public_Ip_Value" {
    description = "Instance Public Ip Value"
    value = aws_instance.worker_2.public_ip
}