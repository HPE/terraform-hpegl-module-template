# Copyright 2022 Hewlett Packard Enterprise Development LP

terraform {
  required_providers {
    hpegl = {
      source  = "hpe/hpegl"
      version = ">= 0.3.4"
    }
  }
}

provider "hpegl" {
  service{
    id = var.new_nested_variable
  }
}

resource "new_nested_resource" "name" {
  name        = "name"
}

