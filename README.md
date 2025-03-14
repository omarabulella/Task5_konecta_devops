# Task5_konecta_devops
*Destroy Arch1* using only the Terraform command (terraform destroy) *without deleting the EC2 instance*. You are not allowed to edit any Terraform files.
answer >> terraform state rm aws_instance.private
*Arch1: Prevent NAT Gateway deletion* – Research and implement a method to *prevent the NAT Gateway from being deleted* even when running terraform destroy.
answer >> To prevent a NAT Gateway from being deleted,i used the lifecycle block with prevent_destroy.
