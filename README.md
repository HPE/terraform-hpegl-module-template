# HPEGL module template

This is a template repository to serve as a starting point for anyone that wishes to create a module for the HPEGL terraform provider

## Using this template
Once you have created a repository with this template, you should first uncomment the contents of `.github/workflows/autorelease.yml` to enable automatic creation of releases when a commit is pushed to master.

Then begin by modifying the `main.tf` files in the root directory as well as any directories within the `modules` directory.