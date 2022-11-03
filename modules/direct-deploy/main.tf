resource "aws_iam_policy" "lambda_deploy" {
  name        = "${var.environment.name}-lambda-deploy-operations"
  path        = "/"
  description = "For operations. It will used Lambda development, test, ci/cd."
  policy      = templatefile("${path.module}/templates/iam_policy_lambda_operation.json", { env = var.environment.name })
}
