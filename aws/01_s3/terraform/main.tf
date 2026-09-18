# Bucket names live in one global namespace shared by every AWS account, so a
# plain project name would collide with a stranger's bucket. The suffix makes
# the name unique without making it unpredictable inside this state.
resource "random_id" "suffix" {
  count       = var.bucket_name == null ? 1 : 0
  byte_length = 4
}

locals {
  bucket_name = coalesce(
    var.bucket_name,
    try("${var.project}-${random_id.suffix[0].hex}", null),
  )
}

resource "aws_s3_bucket" "lab" {
  bucket        = local.bucket_name
  force_destroy = var.force_destroy

  tags = {
    Name = local.bucket_name
  }
}

# Refuse public access four ways: no public ACL may be set, no existing public
# ACL is honoured, no public bucket policy may be set, and no existing public
# policy is honoured. A sandbox bucket has no reason to be readable by anyone
# else, and a bucket left open is the classic S3 accident.
resource "aws_s3_bucket_public_access_block" "lab" {
  bucket = aws_s3_bucket.lab.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# BucketOwnerEnforced switches ACLs off entirely, so access is decided by IAM
# and by the bucket policy alone. This is the default for buckets created in
# the console today, and it removes a whole class of permission surprises.
resource "aws_s3_bucket_ownership_controls" "lab" {
  bucket = aws_s3_bucket.lab.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# SSE-S3 encryption with keys AWS manages. It costs nothing, and it applies to
# every object without the uploader asking for it. SSE-KMS is the alternative,
# and it is not used here because a customer managed key is billed monthly.
resource "aws_s3_bucket_server_side_encryption_configuration" "lab" {
  bucket = aws_s3_bucket.lab.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_versioning" "lab" {
  bucket = aws_s3_bucket.lab.id

  versioning_configuration {
    # A bucket that has never been versioned accepts Disabled. One that has
    # been versioned once may only be Suspended afterwards, so flipping this
    # variable off again produces Suspended, not Disabled.
    status = var.versioning_enabled ? "Enabled" : "Disabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "lab" {
  bucket = aws_s3_bucket.lab.id

  # A multipart upload that never completes leaves its parts in the bucket,
  # where they are billed and where no list-objects call reveals them. So this
  # rule is worth having even on a bucket that holds nothing else.
  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  dynamic "rule" {
    for_each = var.expire_objects_after_days > 0 ? [1] : []

    content {
      id     = "expire-objects"
      status = "Enabled"

      # An empty filter selects every object in the bucket. The block is
      # required even when it selects everything.
      filter {}

      expiration {
        days = var.expire_objects_after_days
      }

      # Without this, expiring a versioned object only hides it behind a
      # delete marker, and the storage stays billed.
      dynamic "noncurrent_version_expiration" {
        for_each = var.versioning_enabled ? [1] : []

        content {
          noncurrent_days = var.expire_objects_after_days
        }
      }
    }
  }

  # The lifecycle configuration and the versioning configuration touch the same
  # bucket, and S3 rejects the pair when they arrive together.
  depends_on = [aws_s3_bucket_versioning.lab]
}
