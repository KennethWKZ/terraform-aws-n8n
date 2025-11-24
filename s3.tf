# S3 bucket for n8n external storage (binary data)
resource "aws_s3_bucket" "n8n_binary_data" {
  bucket = "${var.prefix}-binary-data"

  tags = var.tags
}

# Enable versioning for data protection
resource "aws_s3_bucket_versioning" "n8n_binary_data" {
  bucket = aws_s3_bucket.n8n_binary_data.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "n8n_binary_data" {
  bucket = aws_s3_bucket.n8n_binary_data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "n8n_binary_data" {
  bucket = aws_s3_bucket.n8n_binary_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle policy for old versions
resource "aws_s3_bucket_lifecycle_configuration" "n8n_binary_data" {
  bucket = aws_s3_bucket.n8n_binary_data.id

  rule {
    id     = "delete-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }

  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}
