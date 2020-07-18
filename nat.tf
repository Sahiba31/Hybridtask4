provider "aws" {
  region   = "ap-south-1"
  profile  = "sahiba"
}

resource "aws_vpc" "sahibavpc" {
  cidr_block = "192.168.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = "true"

  tags = {
	Name = "sahibavpc"
}
}

resource "aws_subnet" "publicsub" {
  vpc_id     = "${aws_vpc.sahibavpc.id}"
  cidr_block = "192.168.0.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = "true"
  depends_on = [
    aws_vpc.sahibavpc,
  ]

  tags = {
    Name = "publicsub"
  }
}

resource "aws_subnet" "privatesub" {
  vpc_id     = "${aws_vpc.sahibavpc.id}"
  cidr_block = "192.168.1.0/24"
  availability_zone = "ap-south-1b"
  map_public_ip_on_launch = "false"
  depends_on = [
    aws_vpc.sahibavpc,
  ]

  tags = {
    Name = "privatesub"
  }
}

resource "aws_internet_gateway" "sahibagw" {
  vpc_id = "${aws_vpc.sahibavpc.id}"
  depends_on = [
    aws_vpc.sahibavpc,
  ]

  tags = {
    Name = "sahibagw"
  }
}

resource "aws_route_table" "sahibart" {
  vpc_id = "${aws_vpc.sahibavpc.id}"
 
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.sahibagw.id}"
  }
  depends_on = [
    aws_vpc.sahibavpc,
  ]

  tags = {
    Name = "sahibart"
  }
}

resource "aws_route_table_association" "associate" {
  subnet_id      = "${aws_subnet.publicsub.id}"
  route_table_id = "${aws_route_table.sahibart.id}"
  depends_on = [
    aws_subnet.publicsub,
  ]
}

resource "aws_eip" "eip" {
  vpc      = true
  depends_on = [aws_internet_gateway.sahibagw]
}

resource "aws_nat_gateway" "sahibanat" {
  allocation_id = "${aws_eip.eip.id}"
  subnet_id     = "${aws_subnet.publicsub.id}"
  depends_on = [aws_eip.eip]
  tags = {
    Name = "sahibanat"
  }
}

resource "aws_route_table" "rtt" {
  vpc_id = "${aws_vpc.sahibavpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_nat_gateway.sahibanat.id}"
  }
  depends_on = [aws_vpc.sahibavpc , aws_nat_gateway.sahibanat,]
  tags = {
    Name = "rtt"
  }
}

resource "aws_route_table_association" "nat-associate" {
  subnet_id      = "${aws_subnet.privatesub.id}"
  route_table_id = "${aws_route_table.rtt.id}"
  depends_on = [
    aws_subnet.privatesub,
  ]
}

resource "aws_security_group" "mywpsg" {
  name        = "mywpsg"
  description = "Allow TLS inbound traffic"
  vpc_id      = "${aws_vpc.sahibavpc.id}"

 ingress {
    description = "http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

 ingress {
    description = "ssh"
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

  depends_on = [
    aws_vpc.sahibavpc,
  ]

  tags = {
    Name = "mywpsg"
  }
}
resource "aws_instance" "wpos" {
  ami           = "ami-004a955bfb611bf13"
  instance_type = "t2.micro"
  key_name      = "keycloud"
  subnet_id =  aws_subnet.publicsub.id
  vpc_security_group_ids = [ "${aws_security_group.mywpsg.id}" ]
  tags = {
    Name = "wordpress"
  }

}

resource "aws_security_group" "mysqlsg1" {
  name        = "basic"
  description = "Allow TLS inbound traffic"
  vpc_id      = "${aws_vpc.sahibavpc.id}"

  ingress {
    description = "mysql"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [aws_security_group.mywpsg.id]
  }
  
  depends_on = [
    aws_vpc.sahibavpc,
  ]

  tags = {
    Name = "mysqlsg1"
  }
}

resource "aws_instance" "mysqlos" {
  ami           = "ami-08706cb5f68222d09"
  instance_type = "t2.micro"
  key_name      = "keycloud"
  subnet_id =  aws_subnet.privatesub.id
  vpc_security_group_ids = [ "${aws_security_group.mysqlsg1.id}" , "${aws_security_group.mysqlbas.id}",]
  tags = {
    Name = "mysqlos1"
  }
  depends_on = [aws_security_group.mysqlsg1, aws_security_group.mysqlbas]
}

resource "aws_security_group" "mysqlbas" {
  name        = "basitonOS"
  description = "Allow TLS inbound traffic"
  vpc_id      = "${aws_vpc.sahibavpc.id}"

  ingress {
    description = "ssh"
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
  depends_on = [
    aws_vpc.sahibavpc,
  ]

  tags = {
    Name = "mysqlbas"
  }
}

resource "aws_instance" "basiton" {
  ami           = "ami-004a955bfb611bf13"
  instance_type = "t2.micro"
  key_name      = "keycloud"
  subnet_id =  aws_subnet.publicsub.id
  vpc_security_group_ids = [ "${aws_security_group.mysqlbas.id}" ]
  associate_public_ip_address = true
  tags = {
    Name = "BasitonOS"
  }

}


output "IP_of_wp" {
  value = aws_instance.wpos.public_ip
}

