# Active Storage Cloud Configuration Guide

This application is configured to use cloud storage providers (AWS S3 and Google Cloud Storage) for file uploads in production. Follow this guide to set up your cloud storage.

## 🔧 Current Configuration

- **Development**: Local disk storage (`storage/`)
- **Test**: Local disk storage (`tmp/storage`)  
- **Production**: AWS S3 (configurable to Google Cloud Storage)

## 📋 Prerequisites

- AWS account with S3 access OR Google Cloud Platform account
- Rails application with Active Storage configured

## 🚀 AWS S3 Setup

### 1. Create S3 Bucket
```bash
# Using AWS CLI
aws s3 mb s3://marketer-gen-production
aws s3 mb s3://marketer-gen-staging
```

### 2. Configure CORS for Direct Uploads
Create a CORS configuration for your S3 bucket:

```json
[
  {
    "AllowedHeaders": ["*"],
    "AllowedMethods": ["GET", "PUT", "POST", "DELETE"],
    "AllowedOrigins": ["*"],
    "MaxAgeSeconds": 3600
  }
]
```

### 3. Set Rails Credentials
```bash
bin/rails credentials:edit
```

Add your AWS credentials:
```yaml
aws:
  access_key_id: YOUR_ACCESS_KEY_ID
  secret_access_key: YOUR_SECRET_ACCESS_KEY
  region: us-east-1
  bucket: marketer-gen-production
```

### 4. Test Connection
```bash
bin/rails storage:test_cloud
```

## ☁️ Google Cloud Storage Setup

### 1. Create GCS Bucket
```bash
# Using gcloud CLI
gsutil mb gs://marketer-gen-production
gsutil mb gs://marketer-gen-staging
```

### 2. Create Service Account
1. Go to GCP Console → IAM & Admin → Service Accounts
2. Create a new service account with Storage Admin role
3. Download the JSON key file

### 3. Set Rails Credentials
```bash
bin/rails credentials:edit
```

Add your GCS credentials:
```yaml
gcs:
  project: your-project-id
  credentials: |
    {
      "type": "service_account",
      "project_id": "your-project-id",
      "private_key_id": "...",
      "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n",
      "client_email": "service-account@your-project.iam.gserviceaccount.com",
      "client_id": "...",
      "auth_uri": "https://accounts.google.com/o/oauth2/auth",
      "token_uri": "https://oauth2.googleapis.com/token"
    }
  bucket: marketer-gen-production
```

### 4. Test Connection
```bash
bin/rails storage:test_cloud
```

## 🏗️ Environment Configuration

### Development
Uses local disk storage by default. No additional configuration needed.

### Production
Update `config/environments/production.rb`:
```ruby
# For AWS S3
config.active_storage.service = :amazon

# For Google Cloud Storage
config.active_storage.service = :google

# For redundant storage (mirrors to both AWS and GCS)
config.active_storage.service = :production_mirror
```

## 🔒 Security Configuration

### File Size Limits
Maximum file size is configured in the application (100MB default). Adjust in model validations as needed.

### Content Type Restrictions
Content types are validated at the application level for security.

### CORS Configuration
CORS is configured in `storage.yml` for direct uploads.

## 📊 Testing Your Setup

### Basic Configuration Test
```bash
bin/rails storage:config
```

### Local Storage Test
```bash
bin/rails storage:test
```

### Cloud Storage Test (requires credentials)
```bash
bin/rails storage:test_cloud
```

## 🚀 Deployment Checklist

- [ ] S3 bucket created with proper permissions
- [ ] CORS configuration applied to S3 bucket
- [ ] AWS credentials added to Rails encrypted credentials
- [ ] Production environment configured to use `:amazon` service
- [ ] Cloud storage connection tested successfully
- [ ] SSL/HTTPS enabled for secure uploads

## 🔧 Switching Storage Providers

To switch between storage providers, update the service in your environment file:

```ruby
# config/environments/production.rb
config.active_storage.service = :amazon  # or :google or :production_mirror
```

Then deploy your application with the new configuration.

## 📝 Additional Resources

- [Rails Active Storage Guide](https://guides.rubyonrails.org/active_storage_overview.html)
- [AWS S3 CORS Configuration](https://docs.aws.amazon.com/AmazonS3/latest/userguide/cors.html)
- [Google Cloud Storage Ruby Client](https://cloud.google.com/storage/docs/reference/libraries#client-libraries-install-ruby)