# ---------------------------------------------------
#    Additional Env Variables
# ---------------------------------------------------
locals {
  added_env = [
    {
      name  = "QUEUE_URL"
      value = aws_sqs_queue.main.url
    },
    {
      name  = "QUEUE_URL_REVERSED"
      value = aws_sqs_queue.reversed.url
    },
    {
      name  = "S3_TERRAFORM_ARTEFACTS"
      value = var.s3_tf_artefacts
    },
  ]
}

# ---------------------------------------------------
#    Service Discovery Namespace
# ---------------------------------------------------
resource "aws_service_discovery_private_dns_namespace" "main" {
  name        = "${local.name_prefix}-${var.clp_zenv}-ns"
  description = "${local.name_prefix}-${var.clp_zenv} Private Namespace"
  vpc         = var.vpc_id
}

# ---------------------------------------------------
#    Services
# ---------------------------------------------------
locals {
  default_common_settings = {
    public               = false
    type                 = "non-frontend"
    name_prefix          = local.name_prefix
    standard_tags        = var.standard_tags
    cluster_name         = module.ecs_fargate.cluster_name
    zenv                 = var.clp_zenv
    vpc_id               = var.vpc_id
    security_groups      = var.security_groups
    subnets              = var.private_subnets
    ecr_account_id       = var.account_id
    ecr_region           = var.ecr_region
    logs_destination_arn = module.logdna.lambda_function_arn
    domain_name          = var.domain_name
    task_role_arn        = aws_iam_role.main.arn
    secrets              = var.secrets
    environment          = concat(var.envvars, local.added_env)
  }

  services = {
    for service_name, service_config in var.services : service_name => merge(
      local.default_common_settings,
      {
        service_name           = service_name,
        service_image          = "${aws_ecr_repository.main.repository_url}:${service_name}",
        container_cpu          = service_config.cpu,
        container_memory       = service_config.memory,
        aws_lb_arn             = service_config.public ? aws_lb.loadbalancers[service_name].arn : null
        aws_lb_certificate_arn = service_config.public ? data.aws_acm_certificate.main.arn : null
        environment            = contains(keys(service_config), "environment") ? concat(local.default_common_settings.environment, service_config.environment) : local.default_common_settings.environment
      },
      service_config,
    )
  }
}

module "services" {
  for_each               = local.services
  source                 = "github.com/kuttleio/aws_ecs_fargate_app?ref=1.1.1"
  public                 = each.value.public
  service_name           = each.value.service_name
  service_image          = each.value.service_image
  name_prefix            = each.value.name_prefix
  standard_tags          = each.value.standard_tags
  cluster_name           = each.value.cluster_name
  zenv                   = each.value.zenv
  container_cpu          = each.value.container_cpu
  container_memory       = each.value.container_memory
  vpc_id                 = each.value.vpc_id
  security_groups        = each.value.security_groups
  subnets                = each.value.private_subnets
  ecr_account_id         = each.value.account_id
  ecr_region             = each.value.ecr_region
  aws_lb_arn             = try(each.value.aws_lb_arn, "")
  aws_lb_certificate_arn = try(each.value.aws_lb_certificate_arn, "")
  service_discovery_id   = try(each.value.service_discovery_id, "")
  logs_destination_arn   = each.value.logs_destination_arn
  domain_name            = each.value.domain_name
  task_role_arn          = each.value.task_role_arn
  secrets                = each.value.secrets
  environment            = each.value.environment
}

