output "ecs_cluster_name" {
  value = aws_ecs_cluster.strapi_cluster.name
}

output "ecs_service_name" {
  value = aws_ecs_service.strapi_service.name
}

output "rds_endpoint" {
  value = aws_db_instance.strapi_db.address
}
