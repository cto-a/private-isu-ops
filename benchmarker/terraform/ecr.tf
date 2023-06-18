# __generated__ by Terraform
# Please review these resources and move them into your main configuration files.

# __generated__ by Terraform from "private-isu-benchmarker-repository"
# resource "aws_ecr_repository" "benchmarker_repository" {
#   force_delete         = null
#   image_tag_mutability = "MUTABLE"
#   name                 = "private-isu-benchmarker-repository"
#   tags                 = {}
#   tags_all             = {}
#   encryption_configuration {
#     encryption_type = "AES256"
#     kms_key         = null
#   }
#   image_scanning_configuration {
#     scan_on_push = false
#   }
# }

# # これは手動で追加
# output "repository_url" {
#   value = aws_ecr_repository.benchmarker_repository.repository_url
# }
