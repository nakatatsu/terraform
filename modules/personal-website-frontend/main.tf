# 公開用Bucket
# Origin access controlを使うため、公開用Bucketではあるが、WEBサイトホスティング設定は不要
resource "aws_s3_bucket" "public_bucket" {
  bucket = var.public_bucket_name
}

resource "aws_s3_bucket_lifecycle_configuration" "log_bucket" {
  bucket = aws_s3_bucket.public_bucket.id

  rule {
    id     = "AbortIncompleteMultipartUploadRule"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
    noncurrent_version_expiration {
      noncurrent_days = 1
    }
    expiration {
      days = 30
    }
  }
}

resource "aws_s3_bucket_versioning" "public_bucket" {
  bucket = aws_s3_bucket.public_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}


# Origin access control
resource "aws_cloudfront_origin_access_control" "www" {
  name                              = "${var.environment.name}-www-origin-access-control"
  description                       = "It use to access s3 from cloudfront."
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}


# cloudfront
resource "aws_cloudfront_distribution" "front_cdn" {
  aliases = [var.personal_website_frontend.common.front_domain]
  comment = "for ${var.environment.name} www"

  custom_error_response {
    error_caching_min_ttl = "30"
    error_code            = "404"
    response_code         = "200"
    response_page_path    = "/404.html"
  }

  default_cache_behavior {
    allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods  = ["GET", "HEAD"]
    compress        = "true"
    default_ttl     = "60"

    forwarded_values {
      cookies {
        forward = "none"
      }

      query_string = "true"
    }

    max_ttl                = "86400"
    min_ttl                = "60"
    smooth_streaming       = "false"
    target_origin_id       = aws_s3_bucket.public_bucket.id
    viewer_protocol_policy = "allow-all"
  }

  default_root_object = "index.html"
  enabled             = "true"
  http_version        = "http2and3"
  is_ipv6_enabled     = "true"


  logging_config {
    bucket          = var.log_bucket.bucket_domain_name
    include_cookies = "false"
    prefix          = "frontend/cdn/"
  }

  origin {
    connection_attempts      = "3"
    connection_timeout       = "10"
    domain_name              = aws_s3_bucket.public_bucket.bucket_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.www.id
    origin_id                = aws_s3_bucket.public_bucket.bucket
  }

  price_class = "PriceClass_200"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # 手作業必須にしたほうが堅いが、ここでは使わない。
  retain_on_delete = "false"

  viewer_certificate {
    acm_certificate_arn            = var.acm.us_east_1
    cloudfront_default_certificate = "false"
    minimum_protocol_version       = "TLSv1.2_2021"
    ssl_support_method             = "sni-only"
  }
}


resource "aws_route53_record" "www" {
  name    = var.personal_website_frontend.common.front_domain
  type    = "A"
  zone_id = var.route53.zone_id

  alias {
    evaluate_target_health = false
    name                   = aws_cloudfront_distribution.front_cdn.domain_name
    zone_id                = aws_cloudfront_distribution.front_cdn.hosted_zone_id
  }
}


resource "aws_route53_record" "www_ipv6" {
  name    = var.personal_website_frontend.common.front_domain
  type    = "AAAA"
  zone_id = var.route53.zone_id

  alias {
    evaluate_target_health = false
    name                   = aws_cloudfront_distribution.front_cdn.domain_name
    zone_id                = aws_cloudfront_distribution.front_cdn.hosted_zone_id
  }
}
