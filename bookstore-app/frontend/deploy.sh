#!/usr/bin/env bash
# Builds the frontend and syncs it to the S3 static website bucket created by Terraform.
#
# Usage:
#   ./deploy.sh <static-site-bucket-name>
#
# Get the bucket name with:
#   terraform -chdir=../terraform-bookstore output -raw static_site_bucket_website_endpoint
# (strip the ".s3-website-<region>.amazonaws.com" suffix to get the bucket name, or use
#  `aws s3 ls` to find "<project>-<env>-static-site-<suffix>")

set -euo pipefail

BUCKET="${1:?Usage: ./deploy.sh <bucket-name>}"

npm install
npm run build
aws s3 sync ./dist "s3://${BUCKET}" --delete

echo "Deployed to s3://${BUCKET}"
