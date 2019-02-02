################################################
#
#            IAM CONFIGURATION
#
################################################

# Create role for stop and start aws resouces
resource "aws_iam_role" "scheduler_lambda" {
  name        = "scheduler_lambda_stop_start"
  description = "Allows Lambda functions to stop and start ec2 and rds resources"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

# Create policy for manage autoscaling
resource "aws_iam_policy" "schedule_autoscaling" {
  name        = "autoscaling-custom-policy-start-stop"
  description = "allow shutdown and startup autoscaling instances"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Action": [
            "autoscaling:DescribeAutoScalingGroups",
            "autoscaling:DescribeTags",
            "autoscaling:UpdateAutoScalingGroup"
        ],
        "Resource": "*",
        "Effect": "Allow"
    }
  ]
}
EOF
}

# Create custom policy for manage ec2
resource "aws_iam_policy" "schedule_ec2" {
  name        = "ec2-custom-policy-start-stop"
  description = "allow shutdown and startup ec2 instances"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Action": [
            "ec2:DescribeInstances",
            "ec2:DescribeInstanceStatus",
            "ec2:StopInstances",
            "ec2:StartInstances",
            "ec2:DescribeTags"
        ],
        "Resource": "*",
        "Effect": "Allow"
    }
  ]
}
EOF
}

# Create custom policy for manage rds
resource "aws_iam_policy" "schedule_rds" {
  name        = "rds-custom-policy-start-stop"
  description = "allow shutdown and startup rds instances"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "rds:ListTagsForResource",
        "rds:DescribeDBClusters",
        "rds:StartDBCluster",
        "rds:StopDBCluster",
        "rds:DescribeDBInstances",
        "rds:StartDBInstance",
        "rds:StopDBInstance"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

# Attach custom policy autoscaling to role
resource "aws_iam_role_policy_attachment" "autoscaling" {
  role       = "${aws_iam_role.scheduler_lambda.name}"
  policy_arn = "${aws_iam_policy.schedule_autoscaling.arn}"
}

# Attach custom policy ec2 to role
resource "aws_iam_role_policy_attachment" "ec2" {
  role       = "${aws_iam_role.scheduler_lambda.name}"
  policy_arn = "${aws_iam_policy.schedule_ec2.arn}"
}

# Attach custom policy rds to role
resource "aws_iam_role_policy_attachment" "rds" {
  role       = "${aws_iam_role.scheduler_lambda.name}"
  policy_arn = "${aws_iam_policy.schedule_rds.arn}"
}


################################################
#
#            LAMBDA FUNCTION
#
################################################


# Convert *.py to .zip because AWS Lambda need .zip
data "archive_file" "convert_py_to_zip" {
  type        = "zip"
  source_file = "${path.module}/package/aws-stop-start-resources.py"
  output_path = "${path.module}/package/aws-stop-start-resources.zip"
}

# Create Lambda function for stop or start aws resources
resource "aws_lambda_function" "stop_start" {
  filename         = "${data.archive_file.convert_py_to_zip.output_path}"
  function_name    = "aws-stop-start-resources"
  role             = "${aws_iam_role.scheduler_lambda.arn}"
  handler          = "aws-stop-start-resources.lambda_handler"
  source_code_hash = "${data.archive_file.convert_py_to_zip.output_base64sha256}"
  runtime          = "python3.7"
  timeout          = "600"
  environment {
    variables = {
      SCHEDULE_ACTION      = "${var.schedule_action}"
      TAG_KEY              = "${var.resources_tag["key"]}"
      TAG_VALUE            = "${var.resources_tag["value"]}"
      EC2_SCHEDULE         = "${var.ec2_schedule}"
      RDS_SCHEDULE         = "${var.rds_schedule}"
      AUTOSCALING_SCHEDULE = "${var.autoscaling_schedule}"
    }
  }
}
