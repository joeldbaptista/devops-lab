output "bucket_name" {
  description = "Name of the bucket. The scripts in src/ read this output."
  value       = aws_s3_bucket.lab.id
}

output "bucket_arn" {
  description = "ARN of the bucket, which is what an IAM policy names."
  value       = aws_s3_bucket.lab.arn
}

output "bucket_region" {
  description = "Region that holds the bucket."
  value       = aws_s3_bucket.lab.region
}

output "bucket_domain_name" {
  description = "Regional domain name of the bucket."
  value       = aws_s3_bucket.lab.bucket_regional_domain_name
}

output "s3_uri" {
  description = "The s3:// URI the AWS CLI accepts as a path."
  value       = "s3://${aws_s3_bucket.lab.id}"
}

output "versioning_status" {
  description = "Whether the bucket keeps old versions of an object."
  value       = aws_s3_bucket_versioning.lab.versioning_configuration[0].status
}
