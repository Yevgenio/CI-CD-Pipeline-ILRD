module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0" # 21.15.1

  name               = var.cluster_name
  kubernetes_version = var.cluster_version

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  # Access - so you can kubectl from your machine
  endpoint_public_access                   = true
  enable_cluster_creator_admin_permissions = true

  # Essential cluster addons (required in v21, not self-managed anymore)
  addons = {
    vpc-cni = {
      before_compute = true
    }
    kube-proxy = {
      before_compute = true
    }
    coredns = {}
  }

  eks_managed_node_groups = {
    default = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = var.node_instance_types

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      metadata_options = {
        http_tokens                 = "required"
        http_put_response_hop_limit = 2
      }
    }
  }

  tags = var.tags
}
