locals {
  deploy_name = "${var.environment.name}-github-actions-deploy"
}


# ログ用bucket
resource "aws_s3_bucket" "log_bucket" {
  bucket = var.log_bucket_name
}

resource "aws_s3_bucket_lifecycle_configuration" "log_bucket" {
  bucket = aws_s3_bucket.log_bucket.id

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

resource "aws_s3_bucket_versioning" "log_bucket" {
  bucket = aws_s3_bucket.log_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "log_bucket" {
  bucket = aws_s3_bucket.log_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "log_bucket" {
  bucket = aws_s3_bucket.log_bucket.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}



resource "aws_iam_policy" "github_actions_deploy" {
  name        = local.deploy_name
  path        = "/"
  description = "For deploy"
  policy      = templatefile("${path.module}/templates/iam_policy_github_actions_deploy.json", { env = var.environment.name })
}

resource "aws_iam_role" "github_actions_deploy" {
  name                 = local.deploy_name
  path                 = "/"
  description          = "For deploy"
  assume_role_policy   = templatefile("${path.module}/templates/iam_role_github_actions_deploy_assume_role_policy.json", { repository_keys = var.github.repository_keys, aws_account_id = var.environment.aws_account_id })
  managed_policy_arns  = [aws_iam_policy.github_actions_deploy.arn]
  max_session_duration = "3600"
}
