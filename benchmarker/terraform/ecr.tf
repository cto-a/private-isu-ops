resource "aws_ecr_repository" "benchmarker_ecr" {
  name         = "private-isu-benchmarker-repository"
  force_delete = true
}
