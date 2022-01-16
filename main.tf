provider "aws" {
  profile = "default"
  region = "eu-west-1"
}

resource "aws_s3_bucket" "first_bucket"{
    bucket = "first-bucket-20200116"
    acl = "private"
 }