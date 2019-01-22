variable "name" {
  description = "RDS instance name"
}

variable "engine" {
  description = "Elasticache engine: memcached, redis"
  default     = "redis"
}

variable "engine_version" {
  description = "Cache version"
  default     = "5.0.0"
}

variable "port" {
  description = "Port for cache to listen on"
  default     = 6379
}

variable "num_cache_nodes" {
  description = "The initial number of cache nodes (for Redis 1)"
  default     = 1
}

variable "maintenance_window" {
  description = "Time window for maintenance."
  default     = "Mon:01:00-Mon:02:00"
}

variable "apply_immediately" {
  description = "If false, apply changes during maintenance window"
  default     = false
}

variable "instance_class" {
  description = "Underlying instance type"
  default     = "cache.t2.micro"
}

variable "vpc_id" {
  description = "The VPC ID to use"
}

variable "ingress_allow_security_groups" {
  description = "A list of security group IDs to allow traffic from"
  type        = "list"
  default     = []
}

variable "ingress_allow_cidr_blocks" {
  description = "A list of CIDR blocks to allow traffic from"
  type        = "list"
  default     = []
}

variable "subnet_ids" {
  description = "A list of subnet IDs"
  type        = "list"
}

resource "aws_security_group" "main" {
  name        = "${var.name}-elasticache"
  description = "Allows traffic to Elasticache from other security groups"
  vpc_id      = "${var.vpc_id}"

  ingress {
    from_port       = "${var.port}"
    to_port         = "${var.port}"
    protocol        = "TCP"
    security_groups = ["${var.ingress_allow_security_groups}"]
  }

  ingress {
    from_port   = "${var.port}"
    to_port     = "${var.port}"
    protocol    = "TCP"
    cidr_blocks = ["${var.ingress_allow_cidr_blocks}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "Elasticache (${var.name})"
  }
}

resource "aws_elasticache_subnet_group" "main" {
  name        = "${var.name}"
  description = "Elasticache subnet group"
  subnet_ids  = ["${var.subnet_ids}"]
}

resource "aws_elasticache_cluster" "main" {
  cluster_id = "${var.name}"

  # Cache
  engine         = "${var.engine}"
  engine_version = "${var.engine_version}"

  # Backups / maintenance
  maintenance_window = "${var.maintenance_window}"
  apply_immediately  = "${var.apply_immediately}"

  # Hardware
  node_type         = "${var.instance_class}"
  num_cache_nodes   = "${var.num_cache_nodes}"

  # Network / security
  subnet_group_name   = "${aws_elasticache_subnet_group.main.name}"
  security_group_ids = ["${aws_security_group.main.id}"]
}

output "cache_nodes" {
  value = ["${aws_elasticache_cluster.main.cache_nodes}"]
}
