provider "aws" {
    region = "ca-central-1"
}

// create the resources for ec2
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
      Name = "K-T-H-W"
  }
}

locals {
  resource_name = "kubernetes"
}

resource "aws_subnet" "my_subnet" {
    vpc_id = aws_vpc.my_vpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "ca-central-1a"

    tags = {
      Name = local.resource_name
    }
}

resource "aws_internet_gateway" "my_igw" {
    vpc_id = aws_vpc.my_vpc.id

    tags = {
        Name = local.resource_name
    }
}

resource "aws_route_table" "my_rtb" {
    vpc_id = aws_vpc.my_vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.my_igw.id
    }
    
    tags = {
        Name = local.resource_name
    }
}

resource "aws_route_table_association" "my_rtb_assoc" {
    subnet_id = aws_subnet.my_subnet.id
    route_table_id = aws_route_table.my_rtb.id
}


resource "aws_security_group" "my_sg" {
    name = local.resource_name
    description = "K8s SG"
    vpc_id = aws_vpc.my_vpc.id

    tags = {
        Name = local.resource_name
    }
}

resource "aws_security_group_rule" "my_sgr1" {
    type = "ingress"
    security_group_id = aws_security_group.my_sg.id
    protocol = "all"
    from_port = 0
    to_port = 65535
    cidr_blocks = ["10.0.0.0/16"]
}

resource "aws_security_group_rule" "my_sgr2" {
    type = "ingress"
    security_group_id = aws_security_group.my_sg.id
    protocol = "all"
    from_port = 0
    to_port = 65535
    cidr_blocks = ["10.200.0.0/16"]
}

resource "aws_security_group_rule" "my_sgr3" {
    type = "ingress"
    from_port = 22
    to_port = 22
    security_group_id = aws_security_group.my_sg.id
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "my_sgr4" {
    type = "ingress"
    from_port = 6443
    to_port = 6443
    security_group_id = aws_security_group.my_sg.id
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "my_sgr5" {
    type = "ingress"
    from_port = 443
    to_port = 443
    security_group_id = aws_security_group.my_sg.id
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "my_sgr6" {
    type = "ingress"
    from_port = -1
    to_port = -1
    security_group_id = aws_security_group.my_sg.id
    protocol = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "my_sgr7" {
    type = "egress"
    from_port = 0
    to_port = 0
    security_group_id = aws_security_group.my_sg.id
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
}

resource "aws_lb" "my_nlb" {
    name = local.resource_name
    internal = false
    load_balancer_type = "network"
    subnets = [aws_subnet.my_subnet.id]

    tags = {
        Name = local.resource_name
    } 
}

resource "aws_lb_target_group" "my_tg" {
    name = local.resource_name
    protocol = "TCP"
    port = 6443
    vpc_id = aws_vpc.my_vpc.id
    target_type = "ip"
}

resource "aws_lb_target_group_attachment" "my_tg_attach" {
    count = 3
    target_group_arn = aws_lb_target_group.my_tg.arn
    target_id = "10.0.1.1${count.index}"
}

resource "aws_lb_listener" "my_nlb_listener" {
    load_balancer_arn = aws_lb.my_nlb.arn
    protocol = "TCP"
    port = 443

    default_action {
        type = "forward"
        target_group_arn = aws_lb_target_group.my_tg.arn
    }
}

data "aws_ami" "ubuntu" {
    most_recent = true
    filter {
        name = "name"
        values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
    }

    filter {
        name = "root-device-type"
        values = ["ebs"]
    }

    filter {
        name = "architecture"
        values = ["x86_64"]
    }

    owners = ["099720109477"]
}


resource "tls_private_key" "my_pk" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "my_key" {
    key_name   = local.resource_name
    public_key = tls_private_key.my_pk.public_key_openssh

    provisioner "local-exec" {
        command = "echo '${tls_private_key.my_pk.private_key_pem}' > ./kth-key.pem"
    }  
}

resource "aws_instance" "controller_instances" {
    count = 3
    associate_public_ip_address = true
    ami = data.aws_ami.ubuntu.id
    key_name = aws_key_pair.my_key.key_name
    vpc_security_group_ids = [ aws_security_group.my_sg.id ]
    instance_type = "t3a.micro"
    private_ip = "10.0.1.1${count.index}"
    user_data = "name=controller-${count.index}"
    subnet_id = aws_subnet.my_subnet.id
    source_dest_check = false

    ebs_block_device {
        volume_size = 50
        device_name = "/dev/sda1"
        volume_type = "gp3"

        tags = {
            Name = local.resource_name
        }        
    }

    tags = {
        Name = "controller-${count.index}"
    }
}

resource "aws_instance" "worker_instances" {
    count = 3
    associate_public_ip_address = true
    ami = data.aws_ami.ubuntu.id
    key_name = aws_key_pair.my_key.key_name
    vpc_security_group_ids = [ aws_security_group.my_sg.id ]
    instance_type = "t3a.micro"
    private_ip = "10.0.1.2${count.index}"
    user_data = "name=worker-${count.index}|pod-cidr=10.200.${count.index}.0/24"
    subnet_id = aws_subnet.my_subnet.id
    source_dest_check = false

    ebs_block_device {
        volume_size = 50
        device_name = "/dev/sda1"
        volume_type = "gp3"

        tags = {
            Name = local.resource_name
        }        
    }

    tags = {
        Name = "worker-${count.index}"
    }
}

resource "null_resource" "export_env_vars" {
    provisioner "local-exec" {
        command = <<EOF
            echo VPC_ID=$VPC_ID 
            echo SUBNET_ID=$SUBNET_ID 
            echo INTERNET_GATEWAY_ID=$INTERNET_GATEWAY_ID 
            echo ROUTE_TABLE_ID=$ROUTE_TABLE_ID 
            echo SECURITY_GROUP_ID=$SECURITY_GROUP_ID 
            echo LOAD_BALANCER_ARN=$LOAD_BALANCER_ARN
            echo TARGET_GROUP_ARN=$TARGET_GROUP_ARN
            echo KUBERNETES_PUBLIC_ADDRESS=$KUBERNETES_PUBLIC_ADDRESS
            echo IMAGE_ID=$IMAGE_ID
            EOF

        environment = {
            VPC_ID = "${aws_vpc.my_vpc.id}"
            SUBNET_ID = "${aws_subnet.my_subnet.id}"
            INTERNET_GATEWAY_ID = "${aws_internet_gateway.my_igw.id}"
            ROUTE_TABLE_ID = "${aws_route_table.my_rtb.id}"
            SECURITY_GROUP_ID = "${aws_security_group.my_sg.id}"
            LOAD_BALANCER_ARN = "${aws_lb.my_nlb.arn}"
            TARGET_GROUP_ARN = "${aws_lb_target_group.my_tg.id}"
            KUBERNETES_PUBLIC_ADDRESS = "${aws_lb.my_nlb.dns_name}"
            IMAGE_ID = "${data.aws_ami.ubuntu.id}"
        }
    }

    triggers = {
        always_run = "${timestamp()}"
    }
}