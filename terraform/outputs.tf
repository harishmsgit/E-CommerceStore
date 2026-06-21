output "instance_public_ip" {
  value = local.target_public_ip
}

output "frontend_url" {
  value = "http://${local.target_public_ip}"
}

output "service_urls" {
  value = {
    user    = "http://${local.target_public_ip}:3001"
    product = "http://${local.target_public_ip}:3002"
    cart    = "http://${local.target_public_ip}:3003"
    order   = "http://${local.target_public_ip}:3004"
  }
}
