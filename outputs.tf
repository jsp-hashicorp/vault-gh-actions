# Outputs file
output "demo_app_url" {
  value = "http://${aws_eip.snapshot.public_dns}"
}

output "demo_app_ip" {
  value = "http://${aws_eip.snapshot.public_ip}"
}
 