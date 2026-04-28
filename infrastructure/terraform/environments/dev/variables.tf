variable "require_secrets" {
  type    = bool
  default = false
}

variable "do_token" {
  type      = string
  sensitive = true
  default   = ""
}

variable "github_token" {
  type      = string
  sensitive = true
  default   = ""
}

variable "github_owner" {
  type    = string
  default = ""
}

variable "github_repo" {
  type    = string
  default = ""
}

variable "region" {
  type    = string
  default = "sgp1"
}

variable "doks_version" {
  type    = string
  default = ""
}

variable "doks_node_size" {
  type    = string
  default = "s-2vcpu-4gb"
}

variable "doks_node_count" {
  type    = number
  default = 2
}

variable "ghcr_deploy_username" {
  type      = string
  sensitive = true
  default   = ""
}

variable "ghcr_deploy_token" {
  type      = string
  sensitive = true
  default   = ""
}

variable "postgres_user" {
  type    = string
  default = "fireuser"
}

variable "postgres_password" {
  type      = string
  sensitive = true
  default   = "local-password"
}

variable "postgres_db" {
  type    = string
  default = "fire_monitoring"
}

variable "postgres_host" {
  type    = string
  default = "db"
}

variable "postgres_port" {
  type    = number
  default = 5432
}

variable "pgsslmode" {
  type    = string
  default = "disable"
}

variable "database_url" {
  type      = string
  sensitive = true
  default   = "postgresql://fireuser:local-password@db:5432/fire_monitoring"
}

variable "influxdb_init_mode" {
  type    = string
  default = "setup"
}

variable "influxdb_username" {
  type    = string
  default = "admin"
}

variable "influxdb_password" {
  type      = string
  sensitive = true
  default   = "adminpassword123"
}

variable "influxdb_url" {
  type    = string
  default = "http://influx:8086"
}

variable "influxdb_token" {
  type      = string
  sensitive = true
  default   = "local-influx-token"
}

variable "influxdb_org" {
  type    = string
  default = "fire-monitoring"
}

variable "influxdb_bucket" {
  type    = string
  default = "sensor-data"
}

variable "influxdb_cli_config_name" {
  type    = string
  default = "firedev"
}

variable "influx_measurement" {
  type    = string
  default = "fire_data"
}

variable "mqtt_broker_host" {
  type    = string
  default = "mqtt"
}

variable "mqtt_broker_port" {
  type    = number
  default = 1883
}

variable "etl_sync_interval" {
  type    = number
  default = 30
}

variable "agg_window_minutes" {
  type    = number
  default = 5
}

variable "threshold_smoke_orange" {
  type    = number
  default = 100
}

variable "threshold_smoke_red" {
  type    = number
  default = 250
}

variable "threshold_temp_orange" {
  type    = number
  default = 38.0
}

variable "threshold_temp_red" {
  type    = number
  default = 45.0
}

