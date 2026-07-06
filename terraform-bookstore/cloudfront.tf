############################
# CloudFront: single distribution in front of
#   - S3 static site (default behavior, /*)          -> origin access control
#   - ALB product/order services (/products*, /orders*) -> custom origin
############################

resource "aws_cloudfront_origin_access_control" "static_site" {
  name                              = "${local.name}-static-site-oac"
  description                       = "OAC for ${local.name} static site bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

locals {
  # ALB only has an HTTPS listener when a cert was supplied for it (see alb.tf /
  # variables.tf var.acm_certificate_arn). Match CloudFront's origin protocol to that.
  alb_origin_protocol_policy = var.acm_certificate_arn != "" ? "https-only" : "http-only"

  cloudfront_has_aliases = length(var.cloudfront_domain_names) > 0 && var.cloudfront_acm_certificate_arn != ""
}

resource "aws_cloudfront_distribution" "main" {
  enabled             = true
  comment             = "${local.name} distribution"
  default_root_object = "index.html"
  price_class         = var.cloudfront_price_class
  aliases             = local.cloudfront_has_aliases ? var.cloudfront_domain_names : []

  origin {
    domain_name              = aws_s3_bucket.static_site.bucket_regional_domain_name
    origin_id                = "s3-static-site"
    origin_access_control_id = aws_cloudfront_origin_access_control.static_site.id
  }

  origin {
    domain_name = aws_lb.main.dns_name
    origin_id   = "alb-api"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = local.alb_origin_protocol_policy
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # Static frontend (default)
  default_cache_behavior {
    target_origin_id       = "s3-static-site"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    # Managed policy: CachingOptimized
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"
  }

  # Product service API
  ordered_cache_behavior {
    path_pattern           = "/products*"
    target_origin_id       = "alb-api"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    # Managed policy: CachingDisabled
    cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
    # Managed policy: AllViewerExceptHostHeader
    origin_request_policy_id = "b689b0a8-53d0-40ab-baf2-68738e2966ac"
  }

  # Order service API
  ordered_cache_behavior {
    path_pattern           = "/orders*"
    target_origin_id       = "alb-api"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    cache_policy_id          = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
    origin_request_policy_id = "b689b0a8-53d0-40ab-baf2-68738e2966ac"
  }

  custom_error_response {
    error_code            = 403
    response_code         = 404
    response_page_path    = "/error.html"
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 404
    response_code         = 404
    response_page_path    = "/error.html"
    error_caching_min_ttl = 10
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = local.cloudfront_has_aliases ? null : true
    acm_certificate_arn            = local.cloudfront_has_aliases ? var.cloudfront_acm_certificate_arn : null
    ssl_support_method             = local.cloudfront_has_aliases ? "sni-only" : null
    minimum_protocol_version       = local.cloudfront_has_aliases ? "TLSv1.2_2021" : "TLSv1"
  }

  tags = { Name = "${local.name}-cloudfront" }
}

############################
# Lock the ALB down to only accept traffic that came through CloudFront
############################

data "aws_ec2_managed_prefix_list" "cloudfront" {
  count = var.restrict_alb_to_cloudfront ? 1 : 0
  name  = "com.amazonaws.global.cloudfront.origin-facing"
}
