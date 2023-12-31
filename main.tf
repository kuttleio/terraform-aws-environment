locals {
  region_name_bits  = split("-", var.clp_region)
  short_region_name = "${local.region_name_bits[0]}${substr(local.region_name_bits[1], 0, 1)}${substr(local.region_name_bits[2], 0, 1)}"
  name_prefix       = "${local.short_region_name}-${var.clp_account}"
}
