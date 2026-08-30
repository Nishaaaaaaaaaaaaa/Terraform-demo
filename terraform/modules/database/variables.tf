variable "name" { type = string }
variable "environment" { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}
variable "subnet_ids" { type = list(string) }
variable "security_group_id" { type = string }

variable "engine_version" {

  type = string

  default = "16.4"

}
variable "instance_class" {
  type    = string
  default = "db.t4g.micro"
}
variable "allocated_storage" {
  type    = number
  default = 20
}
variable "max_allocated_storage" {
  description = "Upper bound for storage autoscaling. Set equal to allocated_storage to disable."
  type        = number
  default     = 100
}

variable "db_name" {

  type = string

  default = "appdb"

}
variable "db_user" {
  type    = string
  default = "appuser"
}
variable "multi_az" {
  description = "Synchronous standby in a second AZ. Roughly doubles cost; required for any real availability target."
  type        = bool
  default     = false
}

variable "backup_retention_days" {

  type = number

  default = 7

}
variable "deletion_protection" {
  type    = bool
  default = true
}

variable "skip_final_snapshot" {
  description = "true only for throwaway environments."
  type        = bool
  default     = false
}

variable "performance_insights_enabled" {

  type = bool

  default = false

}
variable "monitoring_interval" {
  type    = number
  default = 0
}