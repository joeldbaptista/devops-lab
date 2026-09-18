variable "region" {
  description = "AWS region that holds the bucket."
  type        = string
  default     = "eu-west-1"
}

variable "project" {
  description = "Name prefix and Project tag applied to every resource."
  type        = string
  default     = "devops-lab-s3"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,36}[a-z0-9]$", var.project))
    error_message = "project must be lowercase letters, digits and hyphens, because it becomes part of the bucket name."
  }
}

variable "bucket_name" {
  description = <<-EOT
    Full bucket name. Leave null to append a random suffix to the project name,
    which is what keeps the name globally unique. Pin it only when the name
    must be predictable, and then pick one nobody else has taken.
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.bucket_name == null || can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "bucket_name must be 3 to 63 characters of lowercase letters, digits, hyphens and dots."
  }
}

variable "force_destroy" {
  description = <<-EOT
    Allow `terraform destroy` to delete a bucket that still holds objects.
    True here because this is a sandbox, and a bucket that refuses to go away
    keeps costing money. Set it to false for anything you care about.
  EOT
  type        = bool
  default     = true
}

variable "versioning_enabled" {
  description = <<-EOT
    Keep every version of an object rather than overwriting it. Off by default,
    because a versioned bucket answers a plain delete with a delete marker, and
    then the object is still billed and still listed by the version APIs.
  EOT
  type        = bool
  default     = false
}

variable "expire_objects_after_days" {
  description = <<-EOT
    Days after which the lifecycle rule deletes an object. Zero disables the
    rule. It is a spend guard, so an object forgotten in the sandbox does not
    stay billed forever.
  EOT
  type        = number
  default     = 30

  validation {
    condition     = var.expire_objects_after_days >= 0
    error_message = "expire_objects_after_days must be zero or greater."
  }
}
