variable "service_name" {
  type        = string
  description = "The name of the lambda function and related resources"
  default     = "newrelic-event-bridge"
} 
variable "sns_topic_name" {
  type        = string
  description = "The name of the lambda function and related resources"
  default     = "newrelic-event-notification-topic"
}

variable "region"{
  type        = string
  description = "The region for the lambda function and related resources"
  default     = "us-west-2"
}

variable "nr_event_bridge_enabled" {
  type        = bool
  description = "Determines if events bridge need to be enabled or disabled"
  default     = true
}

variable "newrelic_secret_name" {
  type        = string
  description = "Name of the secret that stores NewRelic Key(this is is needed in all regions lambda runs)"
  default     = ""
}
variable "newrelic_account_id" {
  type        = string
  description = "Account ID which event forwards to"
  default     = ""
}


## Lambda Specific

variable "runtime" {
 type        = string
  description = "Account ID which event forwards to"
  default     = "python3.12"
}
variable "lambda_archive" {
  type        = string
  description = "The path to the lambda archive, the lambda will be build here if the build_lambda variable is true."
  default     = "temp/newrelic-event-bridge.zip"
}

variable "build_lambda" {
  type        = bool
  description = "Build the Lambda with Docker?"
  default     = true
}

variable "lambda_image_name" {
  type        = string
  description = "Created temporary docker image name. Might need to specify if using the module more than once."
  default     = "newrelic-event-bridge"
}

variable "memory_size" {
  type        = number
  description = "Memory size for the New Relic Log Ingestion Lambda function"
  default     = 128
}

variable "timeout" {
  type        = number
  description = "Timeout for the New Relic Log Ingestion Lambda function"
  default     = 10
}
 
 

variable "lambda_log_retention_in_days" {
  type        = number
  description = "Number of days to keep logs from the lambda for"
  default     = 7
}

variable "tags" {
  type        = map(string)
  description = "Tags to add to the resources created"
  default     = {}
}