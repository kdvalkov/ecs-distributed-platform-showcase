################################################################################
# Route53 Hosted Zone (Data Source - Zone created manually)
################################################################################

data "aws_route53_zone" "main" {
  name         = "valkov.cloud"
  private_zone = false
}

################################################################################
# ACM Certificate
################################################################################

resource "aws_acm_certificate" "showcase" {
  domain_name       = "showcase.valkov.cloud"
  validation_method = "DNS"

  tags = merge(
    local.tags,
    {
      Name = "showcase.valkov.cloud"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

################################################################################
# Route53 Records for ACM Validation
################################################################################

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.showcase.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.main.zone_id
}

# Wait for certificate validation to complete
resource "aws_acm_certificate_validation" "showcase" {
  certificate_arn         = aws_acm_certificate.showcase.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

################################################################################
# Route53 Record for Application
################################################################################

resource "aws_route53_record" "showcase" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "showcase.valkov.cloud"
  type    = "A"

  alias {
    name                   = module.alb.dns_name
    zone_id                = module.alb.zone_id
    evaluate_target_health = true
  }
}
