output "vpc_id" {
    value = aws_vpc.my_vpc.id
}

output "subnet_id" {
    value = aws_subnet.my_subnet.id
}

output "gateway_id" {
  value = aws_internet_gateway.my_igw.id
}

output "rtb_id" {
    value = aws_route_table.my_rtb.id
}

output "sg_id" {
    value = aws_security_group.my_sg.id
}

output "nlb_arn" {
    value = aws_lb.my_nlb.arn
}

output "tg_arn" {
    value = aws_lb_target_group.my_tg.id
}

output "k8s_public_ip" {
    value = aws_lb.my_nlb.dns_name
}

output "worker_instance_ids" {
    value = aws_instance.worker_instances[*].id
}

output "controller_instance_ids" {
    value = aws_instance.controller_instances[*].id
}