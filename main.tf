terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
}
provider "yandex" {
  token                    = var.token
  cloud_id                 = "b1gp5i0hvto20mccicopq"
  folder_id                = "b1gt1g7evsi40fkbs2bi"
  zone                     = var.zone.b
}
resource "yandex_vpc_network" "network" {
  name = "Network"
}
resource "yandex_vpc_subnet" "sub" {
    for_each = var.subnet
  zone           = each.value["zone"]
  network_id     = "${yandex_vpc_network.network.id}"
  v4_cidr_blocks = each.value["cidr_blocks"]
  route_table_id = yandex_vpc_route_table.rt.id
}
resource "yandex_vpc_subnet" "service" {
  zone           = var.zone.c
  network_id     = "${yandex_vpc_network.network.id}"
  v4_cidr_blocks = ["10.20.0.0/24"]
  route_table_id = yandex_vpc_route_table.rt.id
}
resource "yandex_vpc_gateway" "nat_gateway" {
  name = "test"
  shared_egress_gateway {}
}
resource "yandex_vpc_route_table" "rt" {
  name       = "test"
  network_id = "${yandex_vpc_network.network.id}"
  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.nat_gateway.id
  }
}
resource "yandex_vpc_security_group" "ssh" {
  name = "my-ssh-sg"
  description = "Security group for ssh access"
  network_id = "${yandex_vpc_network.network.id}"
  ingress {
    port = 22
    protocol = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    port = 22
    protocol = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "yandex_vpc_security_group" "web-sg" {
  name        = "Service security group"
  description = "Security group для Web-серверов"
  network_id  = "${yandex_vpc_network.network.id}"
  labels = {
    sg = "web"
  }
  ingress {
    protocol       = "TCP"
    description    = "Доступ по SSH через BastionHost"
    from_port      = 22
    to_port        = 22
    security_group_id = yandex_vpc_security_group.ssh.id
  }
  ingress {
    protocol       = "TCP"
    description    = "Входящий трафик Node Exporter"
    v4_cidr_blocks = yandex_vpc_subnet.service.*.v4_cidr_blocks[0]
    from_port      = 9100
    to_port        = 9100
  }
  ingress {
    protocol       = "TCP"
    description    = "Входящий трафик Nginx Exporter"
    v4_cidr_blocks = yandex_vpc_subnet.service.*.v4_cidr_blocks[0]
    from_port      = 4040
    to_port        = 4040
  }
  ingress {
    protocol       = "TCP"
    description    = "Входящий трафик web load balancer"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 80
    to_port        = 80
  }
  egress {
    protocol       = "ANY"
    description    = "Правило разрешает весь исходящий трафик. Узлы могут связаться с Yandex Container Registry, Object Storage, Docker Hub и т. д."
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}
resource "yandex_vpc_security_group" "prometheus-sg" {
  name        = "prometheus security group"
  description = "Security group для prometheus-сервера"
  network_id  = "${yandex_vpc_network.network.id}"
  labels = {
    sg = "prometheus"
  }
  ingress {
    protocol       = "TCP"
    description    = "Доступ по SSH через BastionHost"
    from_port      = 22
    to_port        = 22
    security_group_id = yandex_vpc_security_group.ssh.id
  }
  ingress {
    protocol       = "TCP"
    description    = "Входящий трафик Prometheus"
    v4_cidr_blocks = yandex_vpc_subnet.service.*.v4_cidr_blocks[0]
    from_port      = 9090
    to_port        = 9090
  }
  egress {
    protocol       = "ANY"
    description    = "Правило разрешает весь исходящий трафик. Узлы могут связаться с Yandex Container Registry, Object Storage, Docker Hub и т. д."
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}
resource "yandex_vpc_security_group" "elasticsearch-sg" {
  name        = "elasticsearch security group"
  description = "Security group для elasticsearch-сервера"
  network_id  = "${yandex_vpc_network.network.id}"
  labels = {
    sg = "elasticsearch"
  }
  ingress {
    protocol       = "TCP"
    description    = "Доступ по SSH через BastionHost"
    from_port      = 22
    to_port        = 22
    security_group_id = yandex_vpc_security_group.ssh.id
  }
  ingress {
    protocol       = "TCP"
    description    = "Входящий трафик Elasticsearch"
    v4_cidr_blocks = yandex_vpc_subnet.service.*.v4_cidr_blocks[0]
    from_port      = 9200
    to_port        = 9200
  }
    ingress {
    protocol       = "TCP"
    description    = "Входящий трафик c сервиса Filebeat на web-servers"
    security_group_id = yandex_vpc_security_group.web-sg.id
    from_port      = 9200
    to_port        = 9200
  }
  egress {
    protocol       = "ANY"
    description    = "Правило разрешает весь исходящий трафик. Узлы могут связаться с Yandex Container Registry, Object Storage, Docker Hub и т. д."
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}
resource "yandex_vpc_security_group" "grafana-sg" {
  name        = "grafana security group"
  description = "Security group для grafana-сервера"
  network_id  = "${yandex_vpc_network.network.id}"
  labels = {
    sg = "grafana"
  }
  ingress {
    protocol       = "TCP"
    description    = "Доступ по SSH через BastionHost"
    from_port      = 22
    to_port        = 22
    security_group_id = yandex_vpc_security_group.ssh.id
  }
  ingress {
    protocol       = "TCP"
    description    = "Входящий трафик Grafana"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 3000
    to_port        = 3000
  }
  egress {
    protocol       = "ANY"
    description    = "Правило разрешает весь исходящий трафик. Узлы могут связаться с Yandex Container Registry, Object Storage, Docker Hub и т. д."
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}
resource "yandex_vpc_security_group" "kibana-sg" {
  name        = "kibana security group"
  description = "Security group для kibana-сервера"
  network_id  = "${yandex_vpc_network.network.id}"
  labels = {
    sg = "kibana"
  }
  ingress {
    protocol       = "TCP"
    description    = "Доступ по SSH через BastionHost"
    from_port      = 22
    to_port        = 22
    security_group_id = yandex_vpc_security_group.ssh.id
  }
  ingress {
    protocol       = "TCP"
    description    = "Входящий трафик Kibana"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 5601
    to_port        = 5601
  }
  egress {
    protocol       = "ANY"
    description    = "Правило разрешает весь исходящий трафик. Узлы могут связаться с Yandex Container Registry, Object Storage, Docker Hub и т. д."
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}
resource "yandex_compute_instance" "web" {
    for_each = var.webservers
  name        = each.value["name"]
  zone        = each.value["zone"]
  platform_id = "standard-v2"
  resources {
    core_fraction = 5
    cores  = 2 
    memory = 1
  }
  boot_disk {
    initialize_params {
      image_id = var.image_id
    }
  }
  network_interface {
    subnet_id =  yandex_vpc_subnet.sub[each.value["sub"]].id
    # subnet_id = lookup(yandex_vpc_subnet.sub[each.key["*"]], "id", null)
    ip_address = each.value["ip_address"]
    security_group_ids = [yandex_vpc_security_group.web-sg.id]
  }
  metadata = {
    user-data = "${file("./meta/metadata.yml")}"
  }
  
}
resource "yandex_compute_instance" "bastion" {
  name        = "bastion"
  description = "bastion VM in zone ru-central1-c"
  zone        = var.zone.c
  platform_id = "standard-v2"
  resources {
    core_fraction = 5
    cores  = 2 
    memory = 2
  }
  boot_disk {
    initialize_params {
      image_id = var.image_id
    }
  }
  network_interface {
    subnet_id = yandex_vpc_subnet.service.id
    security_group_ids = [yandex_vpc_security_group.ssh.id]
    nat = true
  }
  metadata = {
    user-data = "${file("./meta/metadata.yml")}"
  }
}
resource "yandex_compute_instance" "prometheus" {
  name        = "prometheus-vm"
  description = "prometheus VM in zone ru-central1-c"
  zone        = var.zone.c
  platform_id = "standard-v2"
  resources {
    core_fraction = 5
    cores  = 2 
    memory = 2  
  }
  boot_disk {
    initialize_params {
      image_id = var.image_id
    }
  }
  network_interface {
    subnet_id = yandex_vpc_subnet.service.id
    nat = false
    ip_address = "10.20.0.10"
    security_group_ids = [yandex_vpc_security_group.prometheus-sg.id]
  }
    metadata = {
    user-data = "${file("./meta/metadata.yml")}"
  }
}
resource "yandex_compute_instance" "grafana" {
  name        = "grafana-vm"
  description = "grafana VM in zone ru-central1-c"
  zone        = var.zone.c
  platform_id = "standard-v2"
  resources {
    core_fraction = 5
    cores  = 2 
    memory = 1
  }
  boot_disk {
    initialize_params {
      image_id = var.image_id
    }
  }
  network_interface {
    subnet_id = yandex_vpc_subnet.service.id
    ip_address = "10.20.0.20"
    nat = true
    security_group_ids = [yandex_vpc_security_group.grafana-sg.id]
  }
  metadata = {
    user-data = "${file("./meta/metadata.yml")}"
  }
}
resource "yandex_compute_instance" "elastic" {
  name        = "elastic-vm"
  description = "elastic VM in zone ru-central1-c"
  zone        = var.zone.c
  platform_id = "standard-v2"
  resources {
    core_fraction = 5
    cores  = 4 
    memory = 4
  }
  boot_disk {
    initialize_params {
      image_id = var.image_id
    }
  }
  network_interface {
    subnet_id = yandex_vpc_subnet.service.id
    ip_address = "10.20.0.50"
    nat = false
    security_group_ids = [yandex_vpc_security_group.elasticsearch-sg.id]
  }
  metadata = {
    user-data = "${file("./meta/metadata.yml")}"
  }
}
resource "yandex_compute_instance" "kibana" {
  name        = "kibana-vm"
  description = "kibana VM in zone ru-central1-c"
  zone        = var.zone.c
  platform_id = "standard-v2"
  resources {
    core_fraction = 5
    cores  = 2 
    memory = 1
  }
  boot_disk {
    initialize_params {
      image_id = var.image_id
    }
  }
  network_interface {
    subnet_id = yandex_vpc_subnet.service.id
    ip_address = "10.20.0.40"
    nat = true
    security_group_ids = [yandex_vpc_security_group.kibana-sg.id]
  }
  metadata = {
     user-data = "${file("./meta/metadata.yml")}"
     
  }
}
resource "yandex_compute_snapshot_schedule" "daily_snapshot" {
  name           = "test-snapshot"
  schedule_policy {
    expression = "@daily"
  }
  snapshot_count = 1
  retention_period = "168h"
  disk_ids = concat([
    for instance_key, instance_value in yandex_compute_instance.web :
    instance_value.boot_disk[0].disk_id
  ],
  [
    yandex_compute_instance.bastion.boot_disk[0].disk_id, 
    yandex_compute_instance.prometheus.boot_disk[0].disk_id,
    yandex_compute_instance.grafana.boot_disk[0].disk_id,
    yandex_compute_instance.elastic.boot_disk[0].disk_id,
    yandex_compute_instance.kibana.boot_disk[0].disk_id,
  ])  
}
resource "yandex_alb_target_group" "web-servers" {
  name = "web-servers-target-group"
  dynamic "target" {
    for_each = var.webservers
    content {
      subnet_id  = yandex_vpc_subnet.sub[target.value.sub].id
      ip_address = target.value.ip_address
    }
  }
}
resource "yandex_alb_backend_group" "web-servers" {
  name                     = "web-servers-backend-group"
  session_affinity {
    connection {
      source_ip = true
    }
  }
  http_backend {
    name                   = "web-backend"
    weight                 = 1
    port                   = 80
    target_group_ids       = ["${yandex_alb_target_group.web-servers.id}"]
    load_balancing_config {
      panic_threshold      = 90
    }    
    healthcheck {
      timeout              = "1s"
      interval             = "1s"
      healthy_threshold    = 10
      unhealthy_threshold  = 15
      http_healthcheck {
        path               = "/"
      }
    }
  }
}
resource "yandex_alb_http_router" "web-router" {
  name   = "web-http-router"
}
resource "yandex_alb_virtual_host" "web-virtual-host" {
  name           = "web-virtual-host"
  http_router_id = "${yandex_alb_http_router.web-router.id}"
  route {
    name = "web-route"
    http_route {
      http_route_action {
        backend_group_id = "${yandex_alb_backend_group.web-servers.id}"
        timeout          = "3s"
      }
    }
  }
}
resource "yandex_alb_load_balancer" "web-balancer" {
  name        = "web-load-balancer"
  network_id  = yandex_vpc_network.network.id
  allocation_policy {
    location {
      zone_id   = var.zone.c
      subnet_id = yandex_vpc_subnet.service.id 
    }
  }
  listener {
    name = "web-listener"
    endpoint {
      address {
        external_ipv4_address {
        }
      }
      ports = [ 80 ]
    }    
    http {
      handler {
        http_router_id = yandex_alb_http_router.web-router.id
      }
    }
  }
}
resource "local_file" "ansible_inventory" {
  filename = "${path.module}/inventory.ini"
  content  = <<EOF
  [bastion]
  ${yandex_compute_instance.bastion.network_interface.0.nat_ip_address}
  [web]
  ${var.webservers.vm-1.ip_address}
  ${var.webservers.vm-2.ip_address}
  [prometheus]
  ${yandex_compute_instance.prometheus.network_interface.0.ip_address}
  [grafana]
  ${yandex_compute_instance.grafana.network_interface.0.ip_address}
  [elastic]
  ${yandex_compute_instance.elastic.network_interface.0.ip_address}
  [kibana]
  ${yandex_compute_instance.kibana.network_interface.0.ip_address}
  [bastion:vars]
  ansible_user=fameq
  ansible_ssh_private_key_file=./meta/key
  [web:vars]
  ansible_ssh_common_args="-o ProxyCommand=\"ssh -q fameq@${yandex_compute_instance.bastion.network_interface.0.nat_ip_address} -o IdentityFile=./meta/key -o Port=22 -W %h:%p\""
  [prometheus:vars]
  ansible_ssh_common_args="-o ProxyCommand=\"ssh -q fameq@${yandex_compute_instance.bastion.network_interface.0.nat_ip_address} -o IdentityFile=./meta/key -o Port=22 -W %h:%p\""
  [grafana:vars]
  ansible_ssh_common_args="-o ProxyCommand=\"ssh -q fameq@${yandex_compute_instance.bastion.network_interface.0.nat_ip_address} -o IdentityFile=./meta/key -o Port=22 -W %h:%p\""
  [elastic:vars]
  ansible_ssh_common_args="-o ProxyCommand=\"ssh -q fameq@${yandex_compute_instance.bastion.network_interface.0.nat_ip_address} -o IdentityFile=./meta/key -o Port=22 -W %h:%p\""
  [kibana:vars]
  ansible_ssh_common_args="-o ProxyCommand=\"ssh -q fameq@${yandex_compute_instance.bastion.network_interface.0.nat_ip_address} -o IdentityFile=./meta/key -o Port=22 -W %h:%p\""
  EOF
}
# resource "local_file" "ansible_inventory" {
#   filename = "${path.module}/inventory.ini"
#   content  = <<EOF
#   [bastion]
#   ${yandex_compute_instance.bastion.network_interface.0.nat_ip_address}
#   [web]
#   ${var.webservers.vm-1.ip_address}
#   ${var.webservers.vm-2.ip_address}
#   [bastion:vars]
#   ansible_user=fameq
#   ansible_ssh_private_key_file=./meta/key
#   [web:vars]
#   ansible_ssh_common_args="-o ProxyCommand=\"ssh -q fameq@${yandex_compute_instance.bastion.network_interface.0.nat_ip_address} -o IdentityFile=./meta/key -o Port=22 -W %h:%p\""
#   EOF
# }

