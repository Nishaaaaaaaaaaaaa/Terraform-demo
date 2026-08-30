variable "name" { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}
variable "repositories" {
  description = "Repository short names, e.g. [\"server\", \"client\"]."
  type        = list(string)
}
variable "untagged_expiry_days" {
  type    = number
  default = 7
}
variable "keep_tagged_images" {
  type    = number
  default = 20
}
variable "force_delete" {
  type    = bool
  default = false
}