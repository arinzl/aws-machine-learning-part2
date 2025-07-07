output "vpc-id" {
  value = aws_vpc.main.id
}

output "filtered_azs" {
  value       = local.filtered_azs
  description = "The list of filtered availability zones excluding 'akl-1a'."
}

output "private_subnets" {
  value = aws_subnet.private[*].id
}
