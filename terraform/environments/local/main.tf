terraform {
  required_version = ">= 1.0.0"
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

provider "helm" {
  kubernetes {
    # Points to local kubeconfig context for K3d
    config_path    = "~/.kube/config"
    config_context = "k3d-self-hosted-cluster"
  }
}

variable "release_name" {
  description = "Name of the Helm release"
  type        = string
  default     = "self-hosted-app"
}

variable "namespace" {
  description = "Namespace to deploy the application into"
  type        = string
  default     = "self-hosted-platform"
}

# Deploy the local Helm chart
resource "helm_release" "app" {
  name             = var.release_name
  chart            = "../../../charts/self-hosted-app"
  namespace        = var.namespace
  create_namespace = true

  # Override values for local development
  values = [
    file("../../../charts/self-hosted-app/values.yaml")
  ]

  set {
    name  = "image.tag"
    value = "latest"
  }

  set {
    name  = "image.pullPolicy"
    value = "IfNotPresent"
  }
}

output "release_status" {
  description = "Status of the Helm release"
  value       = helm_release.app.status
}
