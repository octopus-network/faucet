# gke
variable "project" {
  description = "Project"
  type        = string
}

variable "region" {
  description = "Region"
  type        = string
}

variable "cluster" {
  description = "Cluster"
  type        = string
}

variable "namespace" {
  description = "Namespace"
  type        = string
  default     = "default" # devnet / testnet / mainnet
}

variable "dns_zone" {
  description = "DNS zone"
  type        = string
}

# pod
variable "appchain_faucet" {
  description = "Appchain Faucet Configuration"
  type = object({
    image    = string
    replicas = number

    resources = object({
      cpu_requests    = string
      cpu_limits      = string
      memory_requests = string
      memory_limits   = string
    })
  })
}

# env variables
variable "APPCHAIN_CONF" {
  description = "APPCHAIN_CONF"
  type = object({
    port = string
    db = object({
      path = string
    })
    project = object({
      name = string
    })
    blockchains = list(object({
      type = string
      ids = object({
        chainId = number
        cosmosChainId = string
      })
      name = string
      endpoint = object({
        rpc_endpoint = string
        evm_endpoint = string
      })
      sender = object({
        mnemonic = string
        option = object({
          hdPath = string
          prefix = string
        })
      })
      tx = object({
        amount = object({
          denom = string
          amount = string
        })
        fee = object({
          amount = list(object({
            denom = string
            amount = string
          }))
          gas = string
        })
      })
      limit = object({
        address = number
        ip = number
      })
    }))
  })
}