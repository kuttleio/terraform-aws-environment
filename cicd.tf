data "github_repository" "repositories" {
  for_each  = local.services
  full_name = each.value.deploy.gitrepo
}

data "github_branch" "master" {
  for_each   = local.services
  repository = data.github_repository.repositories[each.key].name
  branch     = "master"
}

resource "github_branch" "new" {
  for_each      = local.services
  repository    = data.github_repository.repositories[each.key].name
  branch        = each.value.deploy_branch
  source_branch = "master"
}

resource "github_repository_file" "respository_files" {
  for_each            = local.services
  repository          = data.github_repository.repositories[each.key].name
  branch              = each.value.deploy_branch
  file                = ".github/workflows/${local.name_prefix}-${var.clp_zenv}.yaml"
  commit_message      = "Add CICD: delivery from ${each.value.deploy_branch} to ${var.clp_zenv}"
  commit_author       = "kuttle-bot"
  commit_email        = "kbot@ktl.ai"
  overwrite_on_create = true
  depends_on          = [github_branch.new]

  content = templatefile("${path.module}/cicd.tpl.yaml", {
    service_name   = each.value.name
    zenv           = title(var.clp_zenv)
    region         = var.clp_region
    deploy_branch  = each.value.deploy_branch
    cluster_name   = module.ecs_fargate.cluster_name
    dockefile_path = each.value.deploy_dockefilepath
  })
}
