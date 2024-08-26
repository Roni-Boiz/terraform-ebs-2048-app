data "aws_iam_policy_document" "assume_service_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["elasticbeanstalk.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]

    condition {
        test     = "StringEquals"
        variable = "sts:ExternalId"

        values = [
        "elasticbeanstalk"
        ]
    }
  }
}

resource "aws_iam_role" "service_role" {
  name               = "aws-elasticbeanstalk-service-role1"
  assume_role_policy = data.aws_iam_policy_document.assume_service_role.json
}

resource "aws_iam_role_policy_attachment" "AWSElasticBeanstalkEnhancedHealth-attach" {
  role       = aws_iam_role.service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSElasticBeanstalkEnhancedHealth"
}

resource "aws_iam_role_policy_attachment" "AWSElasticBeanstalkManagedUpdatesCustomerRolePolicy-attach" {
  role       = aws_iam_role.service_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkManagedUpdatesCustomerRolePolicy"
}

data "aws_iam_policy_document" "assume_ec2_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "ec2-role" {
  name               = "aws-elasticbeanstalk-ec2-role1"
  assume_role_policy = data.aws_iam_policy_document.assume_ec2_role.json
}

resource "aws_iam_role_policy_attachment" "AWSElasticBeanstalkWebTier-attach" {
  role       = aws_iam_role.ec2-role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkWebTier"
}

resource "aws_iam_role_policy_attachment" "AWSElasticBeanstalkWorkerTier-attach" {
  role       = aws_iam_role.ec2-role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkWorkerTier"
}

resource "aws_iam_role_policy_attachment" "AWSElasticBeanstalkMulticontainerDocker-attach" {
  role       = aws_iam_role.ec2-role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkMulticontainerDocker"
}

resource "aws_iam_instance_profile" "instance_profile" {
  name = "aws-elasticbeanstalk-ec2-instance-profile"
  role = aws_iam_role.ec2-role.name
}

resource "aws_iam_role_policy_attachment" "ec2_role_policy_attachment" {
  role       = aws_iam_role.ec2-role.name
  policy_arn  = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

resource "aws_s3_bucket" "app-bucket" {
  bucket = "beanstalk-2048-app-bucket"
  force_destroy = true

  tags = {
    Name        = "app-bucket"
    Environment = "Dev"
  }
}

resource "aws_s3_bucket_ownership_controls" "example" {
  bucket = aws_s3_bucket.app-bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "example" {
  bucket = aws_s3_bucket.app-bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_acl" "example" {
  depends_on = [
    aws_s3_bucket_ownership_controls.example,
    aws_s3_bucket_public_access_block.example
  ]
  bucket = aws_s3_bucket.app-bucket.id
  acl    = "private"
}

# resource "aws_s3_object" "app-object" {
#   bucket = aws_s3_bucket.app-bucket.id
#   key    = "app.zip"
#   source = "app.zip"
#   acl          = "private"
#   content_type = "application/zip"
# }

resource "aws_s3_object" "app-object" {
  bucket = aws_s3_bucket.app-bucket.id
  key    = "Dockerrun.aws.json"
  source = "Dockerrun.aws.json"
  acl          = "private"
}

resource "aws_elastic_beanstalk_application" "app-2048" {
  name        = "2048"
  description = "2048 game application deployed using Docker"
  
  tags = {
    Game = "2048"
  }
}

resource "aws_elastic_beanstalk_application_version" "app-2048-version" {
  name        = "2048_version:1"
  application = aws_elastic_beanstalk_application.app-2048.name
  description = "application version created by terraform"
  bucket      = aws_s3_bucket.app-bucket.id
  key         = aws_s3_object.app-object.id
}

resource "aws_elastic_beanstalk_environment" "app-2048-env" {
  name                = "2048-env"
  application         = aws_elastic_beanstalk_application.app-2048.name
  solution_stack_name = "64bit Amazon Linux 2023 v4.3.6 running Docker"
  version_label       = aws_elastic_beanstalk_application_version.app-2048-version.name
  tier                = "WebServer" 

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "InstanceType"
    value     = "t2.micro"
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "EnvironmentType"
    value     = "SingleInstance"
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment:process"
    name      = "PORT"
    value     = "80"
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = aws_iam_instance_profile.instance_profile.name
  }
}