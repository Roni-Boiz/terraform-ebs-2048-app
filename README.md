# AWS EBS 2048 Application

![app](image)

## Introduction

This repository demonstrates how to deploy a web application on AWS Elastic Beanstalk. AWS Elastic Beanstalk simplifies the deployment process by automatically managing the underlying infrastructure, allowing you to focus on writing code.


## Prerequisites

1. **AWS Account:** Sign up at [aws.amazon.com](https://aws.amazon.com/).
2. **AWS CLI:** Install the AWS CLI for managing AWS services via the command line. [AWS CLI Installation Guide](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html).
3. **Docker / DockerHub Account:** For deploying a containerized application, ensure Docker is installed. and redisted for DockerHub.
4. **Terraform:** To create infrastructure to deploy and manage the application install terrform. [Terrform installation guide](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli).

Docker (Optional): 

## Steps to deploy Application in EKS

1. Create AWS [IAM User](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_users_create.html#id_users_create_console)

2. Set necessory permision to IAM user to create and destroy aws resources (Eg: **AdministratorAccess** or **EC2 full access, S3 FullAccess and EBS Full acces**)<br>
    > use Permissions --> Add permissions --> Attach policies directly

3. Configure AWS [IAM User in AWS CLI](https://docs.aws.amazon.com/cli/latest/reference/configure/)<br>
    ```bash
    $ aws configure
    AWS Access Key ID [None]: <accesskey>
    AWS Secret Access Key [None]: <secretkey>
    Default region name [None]: <default-region> eg: us-east-1
    Default output format [None]: json
    ```

> [!TIP]
> Check user is configured correctly<br>`$ aws iam list-users`

4. Initialize the project <br>
    ```
    $ terraform init
    ```

5. Create resources `main.tf`<br>

```jsx
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
```

6. Deploy the application

    ### Option 01: Using Local Files

    **Step 01**: Compress your application source files into `app.zip` and place it in the root folder. Make sure it include the `Dockerfile` which include necessoray commands to deploy your application.

    **Step 02**: In the current `main.tf` uncomment resource block from line no (116-122) and comment out the resource block from line no (124-129).
    
    ```bash
    resource "aws_s3_object" "app-object" {
       bucket       = aws_s3_bucket.app-bucket.id
       key          = "app.zip"
       source       = "app.zip"
       acl          = "private"
       content_type = "application/zip"
    }

    # resource "aws_s3_object" "app-object" {
    #    bucket       = aws_s3_bucket.app-bucket.id
    #    key          = "Dockerrun.aws.json"
    #    source       = "Dockerrun.aws.json"
    #    acl          = "private"
    # }
    ```

    **Step 03**: apply the changes.

    ```bash
    $ terraform validate
    $ terraform plan
    $ terraform apply -auto-approve
    ```

    ### Option 2: Using Docker image in ECR, DockerHub registry

    **Step 01**: Build and push the image to ECR or DockerHub registory.
    
    ```bash
    $ docker build -t <dockerhub-username>/<application>:<tag> .
    $ docker push <dockerhub-username>/<application>:<tag>
    - or -
    $ docker push <ecr_repo_uri>:<tag>
    ```

    > [!TIP]
    > All the required code snippets to push the image to ECR is provided by the AWS ECR `push commands` buton in ECR repository. Please modify the image name according to your image name.



    **Step 02**: In the current `main.tf` comment out resource block from line nn (116-122) and uncomment the resource block from line no (124-129).
    
    ```bash
    # resource "aws_s3_object" "app-object" {
    #    bucket       = aws_s3_bucket.app-bucket.id
    #    key          = "app.zip"
    #    source       = "app.zip"
    #    acl          = "private"
    #    content_type = "application/zip"
    # }

    resource "aws_s3_object" "app-object" {
        bucket       = aws_s3_bucket.app-bucket.id
        key          = "Dockerrun.aws.json"
        source       = "Dockerrun.aws.json"
        acl          = "private"
    }
    ```

    **Step 3**: apply the changes
    ```bash
    $ terraform validate
    $ terraform plan
    $ terraform apply -auto-approve
    ```

> [!WARNING]
> Make sure to edit the name of the Image --> Name on line 4 with your ECR / DockerHub image Uri in `Dockerrun.aws.json`

7. Record terraform output

    Note down ***application_domain_name*** :- EC2 Public DNS   and ***application url*** :- EC2 public IP

    ![output](image)

8. Open the browser and enter the application_domain_name in address bar (Eg: [http://\<application-env\>.us-east-1.elasticbeanstalk.com](http://\<application-env\>.us-east-1.elasticbeanstalk.com))

    ![app](image)

9. Destroy the project resources<br>
    `$ terraform destroy -auto-approve`

    **Verify everything is cleaned up and destroyed**