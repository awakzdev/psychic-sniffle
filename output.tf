output "domain" { value = "https://${aws_acm_certificate.ssl.domain_name}" }
output "endpoint" { value = aws_db_instance.db.endpoint }
output "alb" { value = aws_lb.alb.dns_name }
output "ec2" { value = { for k, v in aws_instance.ec2 : k => v.public_ip } }