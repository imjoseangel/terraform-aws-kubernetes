data "aws_partition" "main" {}
data "aws_caller_identity" "main" {}

################################################################################
# IAM Role
################################################################################

locals {
  create_iam_role   = var.create && var.create_iam_role
  policy_arn_prefix = "arn:${data.aws_partition.main.partition}:iam::aws:policy"
  account_id        = data.aws_caller_identity.main.account_id
  dns_suffix        = data.aws_partition.main.dns_suffix
}

data "aws_iam_policy_document" "assume_role_policy" {
  count = var.create && var.create_iam_role ? 1 : 0

  statement {
    sid     = "EKSClusterAssumeRole"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.${local.dns_suffix}"]
    }
  }
}

resource "aws_iam_role" "main" {
  count                 = local.create_iam_role ? 1 : 0
  name                  = var.iam_role_name
  description           = var.iam_role_description
  assume_role_policy    = data.aws_iam_policy_document.assume_role_policy[0].json
  permissions_boundary  = format("arn:aws:iam::%s:policy/%s", local.account_id, var.iam_role_permissions_boundary)
  force_detach_policies = true

  tags = merge(var.tags, var.iam_role_tags)
}

resource "aws_iam_role_policy_attachment" "main" {
  for_each = local.create_iam_role ? toset(compact(distinct(concat([
    "${local.policy_arn_prefix}/AmazonEKSClusterPolicy",
    "${local.policy_arn_prefix}/AmazonEKSVPCResourceController",
  ], var.iam_role_additional_policies)))) : toset([])

  policy_arn = each.value
  role       = aws_iam_role.main[0].name
}

module "node-group" {
  source                        = "./modules/node-group"
  iam_role_permissions_boundary = format("arn:aws:iam::%s:policy/%s", local.account_id, var.iam_role_permissions_boundary)
  iam_role_tags                 = var.iam_role_tags
}
