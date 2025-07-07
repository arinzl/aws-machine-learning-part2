resource "aws_security_group" "notebook_sg" {
  name        = "sagemaker-notebook-sg"
  description = "Allow inbound access from within VPC only"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow inbound from within the VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.cidr_block_module]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }


  tags = {
    Name = "${var.app_name}-notebook-sg"
  }
}
