variable "resource_group_name" {
  type        = string
  description = "Resource group to deploy the action group and alert rules into."
}

variable "notification_email" {
  type        = string
  description = "Email address to notify on alert."
}

variable "data_factory_id" {
  type        = string
  description = "Resource ID of the Data Factory to alert on."
}

variable "sql_database_id" {
  type        = string
  description = "Resource ID of the SQL database to alert on."
}

variable "tags" {
  type    = map(string)
  default = {}
}
