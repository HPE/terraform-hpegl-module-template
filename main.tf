# Copyright 20222 Hewlett Packard Enterprise Development LP

terraform {
  required_providers {
    hpegl = {
      source  = "hpe/hpegl"
      version = ">= 0.3.3"
    }
  }
}

provider "hpegl" {
}

resource "hpegl_metal_ssh_key" "name" {
  name        = "sample key"
  public_key  = "example_metal_ssh_key"
}
