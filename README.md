# Overview  

Please see blog site (https://devbuildit.com/etc/) #TODO for detailed explaination of this repo contents.

This repo (and associated blog) will help you to setup an environment for a machine-learning tutorial. The Terraform code is located under the folder named 'code'


# Installation  


## Requirements: ##
- AWS Account
- Terraform CLI installed with access to your target AWS account (via temporary Indentity centre credentials or AWS IAM access keys)

## Deployment (Terraform)
- Clone repo into a source folder
- naviagate into the 'code' folder
- Update file variable.tf with your default region (otherwise this will deploy to ap-southeast-2 by default) and required vpc networking CIDRs
- Consider changing application name in file variables.tf (default will work fine)
- Run command 'Terraform init' in source folder
- Run command 'Terraform plan' in source folder
- Run command 'Terraform apply' in source folder and approve apply


## Removal
- Remove contents of S3 bucket
- Run command 'Terraform destroy'