output "application_url" {
  value = aws_elastic_beanstalk_environment.app-2048-env.endpoint_url
}

output "application_domain_name" {
  value = aws_elastic_beanstalk_environment.app-2048-env.cname
}