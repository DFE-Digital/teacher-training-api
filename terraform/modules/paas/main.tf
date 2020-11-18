resource cloudfoundry_app web_app {
  name                       = local.web_app_name
  space                      = data.cloudfoundry_space.space.id
  health_check_type          = "http"
  health_check_http_endpoint = "/ping"
  instances                  = var.web_app_instances
  memory                     = var.web_app_memory
  docker_image               = var.docker_image
  strategy                   = "blue-green-v2"
  timeout                    = 180
  environment                = var.app_environment_variables

  service_binding {
    service_instance = cloudfoundry_service_instance.postgres.id
  }
  service_binding {
    service_instance = cloudfoundry_service_instance.redis.id
  }
  routes {
    route = cloudfoundry_route.web_app_cloudapps_digital_route.id
  }
}

resource cloudfoundry_app worker_app {
  name                 = local.worker_app_name
  space                = data.cloudfoundry_space.space.id
  health_check_type    = "process"
  instances            = var.worker_app_instances
  memory               = var.worker_app_memory
  docker_image         = var.docker_image
  command              = local.worker_app_start_command
  timeout              = 180
  health_check_timeout = 180
  environment          = var.app_environment_variables

  service_binding {
    service_instance = cloudfoundry_service_instance.postgres.id
  }
  service_binding {
    service_instance = cloudfoundry_service_instance.redis.id
  }
}

resource cloudfoundry_route web_app_cloudapps_digital_route {
  domain   = data.cloudfoundry_domain.local.id
  space    = data.cloudfoundry_space.space.id
  hostname = local.web_app_name
}

resource cloudfoundry_service_instance postgres {
  name         = local.postgres_service_name
  space        = data.cloudfoundry_space.space.id
  service_plan = data.cloudfoundry_service.postgres.service_plans[var.postgres_service_plan]
  json_params  = jsonencode(local.postgres_params)
}

resource cloudfoundry_service_instance redis {
  name         = local.redis_service_name
  space        = data.cloudfoundry_space.space.id
  service_plan = data.cloudfoundry_service.redis.service_plans[var.redis_service_plan]
}