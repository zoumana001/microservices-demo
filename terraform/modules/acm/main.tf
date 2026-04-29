variable "domain_name"     { type = string }
variable "route53_zone_id" { type = string }

# ─────────────────────────────────────────────
# Wildcard certificate for zoumanas.com
# Covers: zoumanas.com and *.zoumanas.com
# i.e. app.zoumanas.com, argocd.zoumanas.com,
#      grafana.zoumanas.com, kibana.zoumanas.com
# ─────────────────────────────────────────────
resource "aws_acm_certificate" "this" {
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

  lifecycle {
    # Create the new cert before destroying the old one
    # so there's zero downtime during cert rotation
    create_before_destroy = true
  }
}

# ─────────────────────────────────────────────
# DNS validation records in Route53
# Terraform creates the CNAME records ACM needs
# to verify domain ownership automatically
# ─────────────────────────────────────────────
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.this.domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  allow_overwrite = true
  zone_id         = var.route53_zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
}

# ─────────────────────────────────────────────
# Wait for ACM to confirm validation
# (blocks until the cert is in ISSUED state)
# ─────────────────────────────────────────────
resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

output "certificate_arn" { value = aws_acm_certificate_validation.this.certificate_arn }
