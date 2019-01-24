/**
 * The ELB module creates an ELB, security group
 * a route53 record and a service healthcheck.
 * It is used by the service module.
 */

variable "name" {
  description = "ELB name, e.g cdn"
}

variable "subnet_ids" {
  description = "Comma separated list of subnet IDs"
}

variable "environment" {
  description = "Environment tag, e.g prod"
}

variable "port" {
  description = "Instance port"
}

variable "security_groups" {
  description = "Comma separated list of security group IDs"
}

variable "healthcheck" {
  description = "Healthcheck path"
}

variable "log_bucket" {
  description = "S3 bucket name to write ELB logs into"
}

variable "external_dns_name" {
  description = "The subdomain under which the ELB is exposed externally, defaults to the task name"
}

variable "internal_dns_name" {
  description = "The subdomain under which the ELB is exposed internally, defaults to the task name"
}

variable "external_zone_id" {
  description = "The zone ID to create the record in"
}

variable "internal_zone_id" {
  description = "The zone ID to create the record in"
}

variable "ssl_certificate_id" {
  description = "SSL Certificate ID to use"
}

/**
 * Resources.
 */

resource "aws_elb" "main_with_ssl" {
  count = "${var.ssl_certificate_id != "" ? 1 : 0}"

  name = "${var.name}"

  internal                  = false
  cross_zone_load_balancing = true
  subnets                   = ["${split(",", var.subnet_ids)}"]
  security_groups           = ["${split(",",var.security_groups)}"]

  idle_timeout                = 30
  connection_draining         = true
  connection_draining_timeout = 15

  listener {
    lb_port           = 80
    lb_protocol       = "http"
    instance_port     = "${var.port}"
    instance_protocol = "http"
  }

  listener {
    lb_port            = 443
    lb_protocol        = "https"
    instance_port      = "${var.port}"
    instance_protocol  = "http"
    ssl_certificate_id = "${var.ssl_certificate_id}"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    target              = "HTTP:${var.port}${var.healthcheck}"
    interval            = 30
  }

  access_logs {
    bucket = "${var.log_bucket}"
  }

  tags {
    Name        = "${var.name}-balancer"
    Service     = "${var.name}"
    Environment = "${var.environment}"
  }
}

resource "aws_elb" "main_without_ssl" {
  count = "${var.ssl_certificate_id == "" ? 1 : 0}"

  name = "${var.name}"

  internal                  = false
  cross_zone_load_balancing = true
  subnets                   = ["${split(",", var.subnet_ids)}"]
  security_groups           = ["${split(",",var.security_groups)}"]

  idle_timeout                = 30
  connection_draining         = true
  connection_draining_timeout = 15

  listener {
    lb_port           = 80
    lb_protocol       = "http"
    instance_port     = "${var.port}"
    instance_protocol = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    target              = "HTTP:${var.port}${var.healthcheck}"
    interval            = 30
  }

  access_logs {
    bucket = "${var.log_bucket}"
  }

  tags {
    Name        = "${var.name}-balancer"
    Service     = "${var.name}"
    Environment = "${var.environment}"
  }
}

locals {
  elb_id = "${element(concat(aws_elb.main_with_ssl.*.id, aws_elb.main_without_ssl.*.id), 0)}"
  elb_name = "${element(concat(aws_elb.main_with_ssl.*.name, aws_elb.main_without_ssl.*.name), 0)}"
  elb_zone_id = "${element(concat(aws_elb.main_with_ssl.*.zone_id, aws_elb.main_without_ssl.*.zone_id), 0)}"
  elb_dns_name = "${element(concat(aws_elb.main_with_ssl.*.dns_name, aws_elb.main_without_ssl.*.dns_name), 0)}"
}

resource "aws_route53_record" "external" {
  count   = "${var.external_zone_id != "" ? 1 : 0}"

  zone_id = "${var.external_zone_id}"
  name    = "${var.external_dns_name}"
  type    = "A"

  alias {
    zone_id                = "${local.elb_zone_id}"
    name                   = "${local.elb_dns_name}"
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "internal" {
  zone_id = "${var.internal_zone_id}"
  name    = "${var.internal_dns_name}"
  type    = "A"

  alias {
    zone_id                = "${local.elb_zone_id}"
    name                   = "${local.elb_dns_name}"
    evaluate_target_health = false
  }
}

/**
 * Outputs.
 */

// The ELB name.
output "name" {
  value = "${local.elb_name}"
}

// The ELB ID.
output "id" {
  value = "${local.elb_id}"
}

// The ELB dns_name.
output "dns" {
  value = "${local.elb_dns_name}"
}

// FQDN built using the zone domain and name (external)
output "external_fqdn" {
  value = "${join(", ", aws_route53_record.external.*.fqdn)}"
}

// FQDN built using the zone domain and name (internal)
output "internal_fqdn" {
  value = "${aws_route53_record.internal.fqdn}"
}

// The zone id of the ELB
output "zone_id" {
  value = "${local.elb_zone_id}"
}
