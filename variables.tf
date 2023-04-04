variable "webservers" {
  type = map
  default = {
    vm-1 = { 
      ip_address = "10.5.0.10" 
      zone       = "ru-central1-a" 
      name       = "vm-1" 
      sub        = "web-1"
       },
    vm-2 = { 
      ip_address = "10.6.0.10" 
      zone       = "ru-central1-b" 
      name       = "vm-2" 
      sub        = "web-2" 
      }
  }
}
variable "subnet" {
  default = {
    web-1 = { 
      cidr_blocks = ["10.5.0.0/24"] 
      zone        = "ru-central1-a" 
      },
    web-2 = { 
      cidr_blocks = ["10.6.0.0/24"] 
      zone        = "ru-central1-b" 
      }
    }
}
variable "image_id" {
    default = "fd864gbboths76r8gm5f"
}
variable "zone" {
  default = {
    a = "ru-central1-a"
    b = "ru-central1-b"
    c = "ru-central1-c"   
  }
}
variable "token" {
  type  = string
}

