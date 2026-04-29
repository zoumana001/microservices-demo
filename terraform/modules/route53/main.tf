variable "domain_name" { type = string }

resource "aws_route53_zone" "this" {
  name = var.domain_name

  lifecycle {
    prevent_destroy = true   # stops terraform destroy from nuking your DNS
  }

  tags = { Name = var.domain_name }
}

output "zone_id"      { value = aws_route53_zone.this.zone_id }
output "nameservers"  { value = aws_route53_zone.this.name_servers }
