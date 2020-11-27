data "azurerm_subnet" "snet-frontend" {
  depends_on           = [var.subnets]
  name                 = var.application_gateway.snet_frontend_name
  virtual_network_name = var.vnet.name
  resource_group_name  = var.resource_group
}

resource "azurerm_public_ip" "example" {
  depends_on          = [var.subnets]
  name                = var.application_gateway.public_ip_name
  resource_group_name = var.resource_group
  location            = var.location
  allocation_method   = "Dynamic"
}

# since these variables are re-used - a locals block makes this more maintainable
locals {
  backend_address_pool_name      = "${var.vnet.name}-beap"
  frontend_port_name             = "${var.vnet.name}-feport"
  frontend_ip_configuration_name = "${var.vnet.name}-feip"
  http_setting_name              = "${var.vnet.name}-be-htst"
  listener_name                  = "${var.vnet.name}-httplstn"
  request_routing_rule_name      = "${var.vnet.name}-rqrt"
  redirect_configuration_name    = "${var.vnet.name}-rdrcfg"
}

resource "azurerm_application_gateway" "network" {


  # App Gateway Config

  depends_on          = [var.subnets]
  name                = var.application_gateway.name
  resource_group_name = var.resource_group
  location            = var.location
  tags                = var.tags

  sku {
    name     = var.application_gateway.sku.name
    tier     = var.application_gateway.sku.tier
    capacity = var.application_gateway.sku.capacity
  }

  #Web Application Firewall Config

  waf_configuration {

    enabled                  = var.application_gateway.waf_configuration.enabled
    firewall_mode            = var.application_gateway.waf_configuration.firewall_mode
    rule_set_type            = var.application_gateway.waf_configuration.rule_set_type
    rule_set_version         = var.application_gateway.waf_configuration.rule_set_version
    disabled_rule_group      = var.application_gateway.waf_configuration.disabled_rule_group
    file_upload_limit_mb     = var.application_gateway.waf_configuration.file_upload_limit_mb
    request_body_check       = var.application_gateway.waf_configuration.request_body_check
    max_request_body_size_kb = var.application_gateway.waf_configuration.max_request_body_size_kb
    exclusion                = var.application_gateway.waf_configuration.exclusion
    #}


    # FrontEnd

    ssl_certificate {
      name     = "certificate"
      data     = var.certificate
      password = var.certificate-password
    }

    gateway_ip_configuration {
      name      = var.application_gateway.gateway_ip_configuration_name
      subnet_id = data.azurerm_subnet.snet-frontend.id
    }

    frontend_port {
      name = local.frontend_port_name
      port = 443
    }

    frontend_ip_configuration {
      name                 = local.frontend_ip_configuration_name
      public_ip_address_id = azurerm_public_ip.example.id
    }

    http_listener {
      name                           = local.listener_name
      frontend_ip_configuration_name = local.frontend_ip_configuration_name
      frontend_port_name             = local.frontend_port_name
      protocol                       = "Https"
      ssl_certificate_name           = "certificate"
    }

    # Backend  

    backend_http_settings {
      name                  = local.http_setting_name
      cookie_based_affinity = "Disabled"
      path                  = "/"
      port                  = 80
      protocol              = "Http"
      request_timeout       = 1
    }

    backend_address_pool {
      name  = local.backend_address_pool_name
      fqdns = [var.application_gateway.fqdns]
    }

    # Rules

    request_routing_rule {
      name                       = local.request_routing_rule_name
      rule_type                  = "Basic"
      http_listener_name         = local.listener_name
      backend_address_pool_name  = local.backend_address_pool_name
      backend_http_settings_name = local.http_setting_name
    }
  }
}