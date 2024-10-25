terraform {
  required_version = ">= 1.7.0, < 2.0"
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}
data "aws_secretsmanager_secret" "by_name" {
  name = var.newrelic_secret_name
}

locals {
  aws_account_id = data.aws_caller_identity.current.account_id
  aws_partition  = data.aws_partition.current.partition
  aws_region     = var.region
  archive_name   = var.lambda_archive
  archive_folder = dirname(local.archive_name)
  tags = merge(
    var.tags,
    { "lambda:createdBy" = "Terraform" }
  )
}

resource "aws_sns_topic" "sns_topic" {
  name           = var.sns_topic_name
}

data "aws_iam_policy_document" "lambda_assume_policy" {
  statement {
    actions = [
      "sts:AssumeRole"
    ]
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# IAM Role for Lambda function
resource "aws_iam_role" "lambda_execution_role" {
  name = "lambda_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Attach a policy to allow Lambda to write to CloudWatch and interact with SNS
resource "aws_iam_role_policy" "lambda_policy" {
  role = aws_iam_role.lambda_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "sns:Publish"
        ],
        Resource = aws_sns_topic.sns_topic.arn
      },
       {
        Effect = "Allow",
        Action = [
          "secretsmanager:GetSecretValue"
        ],
        Resource = data.aws_secretsmanager_secret.by_name.arn
      },
      
    ]
  })
}
 
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.service_name}"
  retention_in_days = var.lambda_log_retention_in_days 
  tags = local.tags
}

resource "null_resource" "build_lambda" {
  count = var.build_lambda ? 1 : 0
  // Depends on log group, just in case this is created in a brand new AWS Subaccount, and it doesn't have subscriptions yet.
  depends_on = [aws_cloudwatch_log_group.lambda_logs]

  provisioner "local-exec" {
    // OS Agnostic folder creation.
    command = (local.archive_folder != "."
      ? "mkdir ${local.archive_folder} || mkdir -p ${local.archive_folder}"
      : "echo Folder Exists"
    )
    on_failure = continue
  }

  provisioner "local-exec" {
    command     = "docker build -t ${var.lambda_image_name} --network host ."
    working_dir = path.module
  }

  provisioner "local-exec" {
    command     = "docker run --rm --entrypoint cat ${var.lambda_image_name} /lambda_function.zip > ${abspath(local.archive_name)}"
    working_dir = path.module
  }

  provisioner "local-exec" {
    command    = "docker image rm ${var.lambda_image_name}"
    on_failure = continue
  }
}

resource "aws_lambda_function" "ingestion_function" {
  depends_on = [
    aws_iam_role.lambda_execution_role,
    aws_cloudwatch_log_group.lambda_logs,
    null_resource.build_lambda,
  ]

  function_name = var.service_name
  description   = "Sends Events coming to the SNS topic to NewRelic"
  role          = aws_iam_role.lambda_execution_role.arn
  runtime       = var.runtime
  filename      = local.archive_name
  handler       = "lambda_function.lambda_handler"
  memory_size   = var.memory_size
  timeout       = var.timeout

  environment {
    variables = {
      NEWRELIC_ACCOUNT_ID               = var.newrelic_account_id
      NEWRELIC_SECRET_NAME              = var.newrelic_secret_name  
      NEWRELIC_EVENT_BRIDGE_ENABLED     = var.nr_event_bridge_enabled  
    }
  } 
  tags = local.tags
}

resource "aws_lambda_permission" "allow_sns_invoke" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ingestion_function.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.sns_topic.arn
}


# SNS Subscription to Lambda
resource "aws_sns_topic_subscription" "sns_subscription" {
  topic_arn = aws_sns_topic.sns_topic.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.ingestion_function.arn
}



output "sns_arn" {
  value       = aws_sns_topic.sns_topic.arn
  description = "NewRelic Event SNS ARN"
}

output "function_arn" {
  value       = aws_lambda_function.ingestion_function.arn
  description = "NewRelic Event Bridge lambda function ARN"
}

output "lambda_archive" {
  depends_on = [null_resource.build_lambda]
  value      = local.archive_name
}