# IAM Role for Karpenter Controller
resource "aws_iam_role" "karpenter_controller_role" {
  name = "${var.project}-cluster-karpenter-controller-role"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = {
          Federated = module.eks.oidc_provider_arn
        }
        Action    = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${module.eks.oidc_provider}:sub" = "system:serviceaccount:karpenter:karpenter"
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "karpenter_controller_policy" {
  name        = "${var.project}-karpenter-controller-policy"
  description = "Policy for Karpenter controller to manage node provisioning"

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "pricing:GetProducts",
          "ec2:RunInstances",
          "ec2:DescribeSubnets",
          "ec2:DescribeSpotPriceHistory",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeImages",
          "ec2:DescribeAvailabilityZones",
          "ec2:CreateTags",
          "ec2:CreateLaunchTemplate",
          "ec2:CreateFleet",
          "ec2:TerminateInstances",
          "ec2:DeleteLaunchTemplate",
          "ec2:GetInstanceProfile",
          "iam:TagInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:GetInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:CreateInstanceProfile",
          "iam:AddRoleToInstanceProfile",
          "iam:PassRole",
          "eks:DescribeCluster",
          "sqs:ReceiveMessage",
          "sqs:GetQueueUrl",
          "sqs:GetQueueAttributes",
          "sqs:DeleteMessage",
          "ssm:GetParameter",
          

        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "karpenter_controller_policy" {
  role       = aws_iam_role.karpenter_controller_role.name
  policy_arn = aws_iam_policy.karpenter_controller_policy.arn
}

# IAM Role for Karpenter Node
resource "aws_iam_role" "karpenter_node_role" {
  name = "${var.project}-cluster-karpenter-node-role"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "karpenter_node_ecr_readonly" {
  role       = aws_iam_role.karpenter_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "karpenter_node_cni_policy" {
  role       = aws_iam_role.karpenter_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "karpenter_node_worker_policy" {
  role       = aws_iam_role.karpenter_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "karpenter_node_ssm_policy" {
  role       = aws_iam_role.karpenter_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "karpenter_node_instance_profile" {
  name = "${var.project}-cluster-karpenter-node-instance-profile"
  role = aws_iam_role.karpenter_node_role.name
}

resource "aws_sqs_queue" "karpenter_queue" {
  message_retention_seconds = 300  # 5 minutes cho interruption messages
  visibility_timeout_seconds = 30
  sqs_managed_sse_enabled = true
  name                      = "${var.project}-${var.environment}"
}

resource "aws_sqs_queue_policy" "queue_policy" {
  queue_url = aws_sqs_queue.karpenter_queue.id
  
  policy = jsonencode({
    Version = "2008-10-17",
    Id      = "EC2InterruptionPolicy",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = [
            "sqs.amazonaws.com",
            "events.amazonaws.com"
          ]
        },
        Action   = "sqs:SendMessage",
        Resource = aws_sqs_queue.karpenter_queue.arn
      },
      {
        Sid    = "DenyHTTP",
        Effect = "Deny",
        Principal = "*",
        Action = "sqs:*",
        Resource = aws_sqs_queue.karpenter_queue.arn,
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# EventBridge Rule cho Spot Interruption
resource "aws_cloudwatch_event_rule" "spot_interruption_rule" {
  name          = "${var.project}-${var.environment}-spot-interruption"
  description   = "Rule for EC2 spot interruption notices"
  event_pattern = jsonencode({
    source      = ["aws.ec2"],
    detail-type = ["EC2 Spot Instance Interruption Warning"]
  })
}

# EventBridge Rule cho Instance Rebalance
resource "aws_cloudwatch_event_rule" "rebalance_rule" {
  name          = "${var.project}-${var.environment}-rebalance"
  description   = "Rule for EC2 instance rebalance recommendations"
  event_pattern = jsonencode({
    source      = ["aws.ec2"],
    detail-type = ["EC2 Instance Rebalance Recommendation"]
  })
}

# EventBridge Rule cho Instance State Change
resource "aws_cloudwatch_event_rule" "state_change_rule" {
  name          = "${var.project}-${var.environment}-state-change"
  description   = "Rule for EC2 instance state changes"
  event_pattern = jsonencode({
    source      = ["aws.ec2"],
    detail-type = ["EC2 Instance State-change Notification"]
  })
}

# EventBridge Target cho Spot Interruption
resource "aws_cloudwatch_event_target" "spot_interruption_target" {
  rule      = aws_cloudwatch_event_rule.spot_interruption_rule.name
  target_id = "KarpenterSQS"
  arn       = aws_sqs_queue.karpenter_queue.arn
}

# EventBridge Target cho Rebalance
resource "aws_cloudwatch_event_target" "rebalance_target" {
  rule      = aws_cloudwatch_event_rule.rebalance_rule.name
  target_id = "KarpenterRebalanceSQS"
  arn       = aws_sqs_queue.karpenter_queue.arn
}

# EventBridge Target cho State Change
resource "aws_cloudwatch_event_target" "state_change_target" {
  rule      = aws_cloudwatch_event_rule.state_change_rule.name
  target_id = "KarpenterStateChangeSQS"
  arn       = aws_sqs_queue.karpenter_queue.arn
}

# IAM Policy cho EventBridge để gửi message đến SQS
resource "aws_iam_role_policy" "eventbridge_sqs_policy" {
  name = "${var.project}-${var.environment}-eventbridge-sqs"
  role = aws_iam_role.eventbridge_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = "sqs:SendMessage",
        Resource = aws_sqs_queue.karpenter_queue.arn
      }
    ]
  })
}

# IAM Role cho EventBridge
resource "aws_iam_role" "eventbridge_role" {
  name = "${var.project}-${var.environment}-eventbridge-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "events.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}
