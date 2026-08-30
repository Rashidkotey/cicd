output "instance_id" {
  description = "The ID of the EC2 instance"
  value       = aws_instance.this.id
}

output "Public_ip" {
  description = "The Public IP of the EC2 instance"
  value       = aws_instance.this.public_ip
}

output "ec2_url" {
  description = "The url of the ec2 instance"
  value       = "http://${aws_instance.this.public_ip}"
}
