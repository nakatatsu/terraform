locals {
  send_mail_function_name = "${var.env}-lambda-send-mail"
}

resource "aws_cloudwatch_log_group" "send_mail" {
  name              = "/aws/lambda/${local.send_mail_function_name}"
  retention_in_days = 90
}

resource "aws_iam_policy" "send_mail" {
  name        = local.send_mail_function_name
  path        = "/"
  description = "For IAM Role, ${local.send_mail_function_name}"
  policy      = file("${path.module}/templates/iam_policy_send_mail.json")
}

resource "aws_iam_role" "send_mail" {
  name                 = local.send_mail_function_name
  path                 = "/"
  description          = "For lambda function, send_mail."
  assume_role_policy   = file("${path.module}/templates/aws_iam_role_send_mail_assume_role_policy.json")
  managed_policy_arns  = [aws_iam_policy.send_mail.arn, "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"]
  max_session_duration = "3600"
}


resource "aws_lambda_function" "send_mail" {
  architectures                  = ["x86_64"]
  function_name                  = local.send_mail_function_name
  handler                        = "main.lambda_handler"
  memory_size                    = "128"
  package_type                   = "Zip"
  reserved_concurrent_executions = "-1"
  role                           = aws_iam_role.send_mail.arn
  runtime                        = "python3.9"
  timeout                        = "10"
  s3_bucket                      = var.administrative_bucket
  s3_key                         = var.send_mail_s3_key
  ephemeral_storage {
    size = "512"
  }
  tracing_config {
    mode = "PassThrough"
  }
  environment {
    variables = {
      REGION             = var.region
      SERVICE_ADMIN_MAIL = var.administrator_mail_address
      SERVICE_NAME       = var.service_name
      SERVICE_URL        = var.service_url
      REPLY_TITLE        = var.mail_reply_title
    }
  }
}



