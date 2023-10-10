variable "subscription_id" {
  description = "Subscription ID of Azure account."
}

variable "client_id" {
  description = "Client ID of Terraform account to be used to deploy VM on Azure."
}

variable "client_secret" {
  description = "Client Secret of Terraform account to be used to deploy VM on Azure."
}

variable "tenant_id" {
  description = "Tenant ID of Terraform account to be used to deploy VM on Azure."
}

variable "location" {
  description = "Location where c8000v edge will be deployed."
}

variable "resource_group" {
  description = "Name of the resource group in which c8000v edge will be deployed."
  default     = "sdwan-edge-resource-group"
}

variable "address_space" {
  description = "Virtual Private Network's address space to be used for C8000v edge setup."
  default     = "10.60.0.0/24"
}

variable "sdwan_subnet_lan" {
  description = "This is required to Lan subnet of c8000v Edge."
  default     = "10.60.0.0/25"
}

variable "sdwan_subnet_wan" {
  description = "This is required to wan subnet of C8000v Edge."
  default     = "10.60.0.128/25"
}

variable "c8000v_vm" {
  description = "Hostname to be used for edge."
  default     = "Edge-AZU-SWC-VM01"
}

variable "edge_vm_size" {
  description = "Size of edge VM."
  default     = "Standard_DS2_v2"
}

variable "sku" {
  description = "Image sku."
  default     = "17_06_02-byol"
}

variable "image_version" {
  description = "image version."
  default     = "17.06.0220211209"
}

variable "name" {
  description = "Image Publisher."
  default     = "17_06_02-byol"
}
