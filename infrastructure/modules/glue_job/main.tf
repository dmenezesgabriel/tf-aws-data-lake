terraform {
  required_version = "~> 1.0"

  required_providers {

    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}


data "aws_iam_policy_document" "role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["glue.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "policy" {
  statement {
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:ListBucket"
    ]
  }
}

resource "aws_iam_policy" "main" {
  name   = "iam_policy-${var.glue_job_name}"
  policy = data.aws_iam_policy_document.policy.json

}

resource "aws_iam_role" "main" {
  name               = "iam_role-${var.glue_job_name}"
  assume_role_policy = data.aws_iam_policy_document.role.json
}

resource "aws_iam_role_policy_attachment" "main" {
  role       = aws_iam_role.main.name
  policy_arn = aws_iam_policy.main.arn
}

resource "aws_s3_object" "test_deploy_script_s3" {
  bucket = var.glue_job_bucket
  key    = "glue/scripts/${var.glue_job_name}.py"
  source = var.glue_job_source_file_path
  etag   = filemd5(var.glue_job_source_file_path)
}

resource "aws_glue_job" "test_deploy_script" {
  glue_version      = var.glue_job_version
  max_retries       = var.glue_job_max_retries
  name              = var.glue_job_name
  role_arn          = aws_iam_role.main.arn
  number_of_workers = var.glue_job_number_of_workers
  worker_type       = var.glue_job_worker_type
  timeout           = var.glue_job_worker_timeout
  execution_class   = var.glue_job_worker_execution_class

  command {
    script_location = "s3://${var.glue_job_bucket}/glue/scripts/${var.glue_job_name}.py"
  }

  default_arguments = {
    "--class"                   = "GlueApp"
    "--enable-job-insights"     = "true"
    "--enable-auto-scaling"     = "false"
    "--enable-glue-datacatalog" = "true"
    "--job-language"            = "python"
    "--job-bookmark-option"     = "job-bookmark-disable"
  }
}
