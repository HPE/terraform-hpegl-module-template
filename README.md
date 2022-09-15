# HPEGL module template

This is a template repository to serve as a starting point for anyone that wishes to create a module for the HPEGL terraform provider

## Terraform module requirements

Terraform modules are required to follow a set structure when they are to be published, the module structure is described in more detail [here](https://www.terraform.io/language/modules/develop/structure)

Terraform modules that are to be published must also conform to the same naming conventions, in our case all module names must begin with `terraform-hpegl-<NAME>`. More on module naming and publishing [here](https://www.terraform.io/registry/modules/publish)

## Using this template
Once you have created a repository with this template, you should first uncomment the contents of `.github/workflows/autorelease.yml` to enable automatic creation of releases when a commit is pushed to master.

Then begin by modifying the `main.tf` files in the root directory as well as any directories within the `modules` directory.