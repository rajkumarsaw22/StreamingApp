# Backend values can't reference variables, so they're hardcoded here to match
# the defaults in variables.tf (tf_state_bucket / tf_lock_table). Update both
# places together if you rename the bootstrap bucket/table.
terraform {
  backend "s3" {
    bucket         = "rajsaw-streaming-tfstate"
    key            = "streamingapp/terraform.tfstate"
    region         = "us-west-1"
    dynamodb_table = "rajsaw-streaming-tf-locks"
    encrypt        = true
  }
}
