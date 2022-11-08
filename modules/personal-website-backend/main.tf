locals {
  personal_website_deploy_name = "${var.environment.name}-personal-website-deploy"
  send_mail_function_name      = "${var.environment.name}-send-mail"
}


# API GatewayにはStageという考え方があり、環境はそちらで表現することが想定されている。
# だがアカウントが分かれても動作してほしいため、。一緒に管理することが前提となるのは困る。そのためAPI Gatewayを別々に作成して管理している。
resource "aws_api_gateway_rest_api" "personal_website_api" {
  name        = "${var.environment.name}-personal-website-api"
  description = "for personal website api."

  minimum_compression_size = 1024 * 5

  endpoint_configuration {
    types = ["REGIONAL"]
  }
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
  assume_role_policy   = file("${path.module}/templates/iam_role_send_mail_assume_role_policy.json")
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
  publish                        = false
  role                           = aws_iam_role.send_mail.arn
  runtime                        = "python3.9"
  timeout                        = "10"
  # ※ 実行環境によっては相対パスが動作しないことがあるらしい。
  filename = "${path.module}/files/lambda_python_empty_function.zip"
  ephemeral_storage {
    size = "512"
  }
  tracing_config {
    mode = "PassThrough"
  }
  environment {
    variables = {
      REGION            = var.environment.region
      CORS_ALLOW_ORIGIN = var.personal_website_backend.common.allow_origin
    }
  }

  # コード変更は無視する
  lifecycle {
    ignore_changes = [
      filename,
      layers
    ]
  }
}

resource "aws_lambda_alias" "send_mail" {
  name             = "${local.send_mail_function_name}-alias"
  description      = "${var.environment.name} send mail alias"
  function_name    = aws_lambda_function.send_mail.function_name
  function_version = "$LATEST"
}

# TerraformでAPI Gatewayの設定を行うことも不可能ではない。だが見ての通り大変複雑で、しかもAPI設計がインフラ依存になってしまい、
# 開発体制としてもあまり優れていると言い難い。小規模なプロジェクトならこれでもなんとかなるが、本格的に
# Serverless化する大規模なプロジェクトでは別の手法を取ったほうがいいのではないか。
resource "aws_api_gateway_resource" "send_mail" {
  rest_api_id = aws_api_gateway_rest_api.personal_website_api.id
  parent_id   = aws_api_gateway_rest_api.personal_website_api.root_resource_id
  path_part   = "send-mail"
}

# [CORS]
# - OPTIONS メソッドを作成する
# - 200 メソッドレスポンスを空のレスポンスモデルとともに OPTIONS メソッドに追加する
# - Mock 統合を OPTIONS メソッドに追加する
# - 200 統合レスポンスを OPTIONS メソッドに追加する
# - Access-Control-Allow-Headers, Access-Control-Allow-Methods, Access-Control-Allow-Origin メソッドレスポンスヘッダーを OPTIONS メソッドに追加する
# - Access-Control-Allow-Headers, Access-Control-Allow-Methods, Access-Control-Allow-Origin 統合レスポンスヘッダーマッピングを OPTIONS メソッド に追加する
# - Access-Control-Allow-Origin メソッドレスポンスヘッダーを POST メソッドに追加する 
# - Access-Control-Allow-Origin 統合レスポンスヘッダーマッピングを POST メソッドに追加する 


resource "aws_api_gateway_method" "send_mail_cors_options" {
  rest_api_id   = aws_api_gateway_rest_api.personal_website_api.id
  resource_id   = aws_api_gateway_resource.send_mail.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "send_mail_cors_empty_response" {
  rest_api_id = aws_api_gateway_rest_api.personal_website_api.id
  resource_id = aws_api_gateway_resource.send_mail.id
  http_method = aws_api_gateway_method.send_mail_cors_options.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "send_mail_cors_empty_response" {
  rest_api_id = aws_api_gateway_rest_api.personal_website_api.id
  resource_id = aws_api_gateway_resource.send_mail.id
  http_method = aws_api_gateway_method.send_mail_cors_options.http_method
  status_code = aws_api_gateway_method_response.send_mail_cors_empty_response.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type'",
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST'",
    "method.response.header.Access-Control-Allow-Origin"  = "'${var.personal_website_backend.common.allow_origin}'"
  }
}



# Mock統合
resource "aws_api_gateway_integration" "send_mail_cors_options_mock" {
  rest_api_id = aws_api_gateway_rest_api.personal_website_api.id
  resource_id = aws_api_gateway_resource.send_mail.id
  http_method = aws_api_gateway_method.send_mail_cors_options.http_method
  type        = "MOCK"

  request_templates = { "application/json" = "{ \"statusCode\" : 200 }" }
}

resource "aws_api_gateway_method" "send_mail" {
  authorization = "NONE"
  http_method   = "POST"
  rest_api_id   = aws_api_gateway_rest_api.personal_website_api.id
  resource_id   = aws_api_gateway_resource.send_mail.id
}

resource "aws_api_gateway_integration" "send_mail" {
  http_method             = aws_api_gateway_method.send_mail.http_method
  resource_id             = aws_api_gateway_resource.send_mail.id
  rest_api_id             = aws_api_gateway_rest_api.personal_website_api.id
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_alias.send_mail.invoke_arn
  content_handling        = "CONVERT_TO_TEXT"
  # 関数のエイリアスを指定する必要がなければ関数直で指定。
  #  uri                     = aws_lambda_function.send_mail.invoke_arn
}

resource "aws_api_gateway_stage" "send_mail" {
  deployment_id = aws_api_gateway_deployment.send_mail.id
  rest_api_id   = aws_api_gateway_rest_api.personal_website_api.id
  stage_name    = var.personal_website_backend.common.stage_name

  # デプロイIDは無視する
  lifecycle {
    ignore_changes = [
      deployment_id
    ]
  }
}

resource "aws_api_gateway_method_settings" "send_mail" {
  rest_api_id = aws_api_gateway_rest_api.personal_website_api.id
  stage_name  = aws_api_gateway_stage.send_mail.stage_name
  method_path = "*/*"

  settings {
    logging_level = "INFO"
  }
}

resource "aws_api_gateway_base_path_mapping" "send_mail" {
  api_id      = aws_api_gateway_rest_api.personal_website_api.id
  domain_name = var.personal_website_backend.common.api_domain
  stage_name  = aws_api_gateway_stage.send_mail.stage_name
}

resource "aws_lambda_permission" "send_mail" {
  statement_id  = "${var.environment.name}-allow-send-mail-invoke"
  function_name = aws_lambda_function.send_mail.function_name
  action        = "lambda:InvokeFunction"
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.personal_website_api.execution_arn}/*/*/*"
}


resource "aws_lambda_permission" "send_mail_alias" {
  statement_id  = "${var.environment.name}-allow-send-mail-alias-invoke"
  function_name = aws_lambda_function.send_mail.function_name
  action        = "lambda:InvokeFunction"
  qualifier     = "${var.environment.name}-send-mail-alias"
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.personal_website_api.execution_arn}/*/*/*"
}


resource "aws_api_gateway_deployment" "send_mail" {
  depends_on = [aws_api_gateway_method.send_mail]

  rest_api_id = aws_api_gateway_rest_api.personal_website_api.id
  stage_name  = var.personal_website_backend.common.stage_name
  # どんな変更だろうと変更がなかろうと必ずデプロイ
  description = "Deployed at ${timestamp()}"
}
