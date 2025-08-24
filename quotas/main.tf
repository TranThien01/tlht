# Configure the Google Cloud Provider
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}

# Configure the Google Cloud Provider
provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}



variable "region" {
  description = "The GCP region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "The GCP zone"
  type        = string
  default     = "us-central1-a"
}



variable "machine_type" {
  description = "Machine type for instances"
  type        = string
  default     = "e2-micro"
}

variable "instance_name_prefix" {
  description = "Prefix for instance names"
  type        = string
  default     = "e2-micro-instance"
}

# Data source to get the latest Ubuntu image
data "google_compute_image" "ubuntu" {
  family  = "ubuntu-2004-lts"
  project = "ubuntu-os-cloud"
}

# Create 24 e2-micro instances
resource "google_compute_instance" "e2_micro_instances" {
  count        = var.instance_count
  name         = "${var.instance_name_prefix}-${count.index + 1}"
  machine_type = var.machine_type
  zone         = var.zone

  # Allow stopping for update
  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = data.google_compute_image.ubuntu.self_link
      size  = 10 # 10GB boot disk (free tier eligible)
      type  = "pd-standard"
    }
  }

  # Network interface
  network_interface {
    network = "default"
    
    # Assign external IP (remove this block if you don't need external IPs)
    access_config {
      # Ephemeral public IP
    }
  }

  # Optional: Add metadata for SSH keys
  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}" # Update with your SSH key path
  }

  # Optional: Add startup script
  metadata_startup_script = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y nginx
    systemctl start nginx
    systemctl enable nginx
    echo "Instance ${count.index + 1} is ready!" > /var/www/html/index.html
  EOF

  # Optional: Add network tags for firewall rules
  tags = ["e2-micro", "web-server"]

  # Service account with minimal permissions
  service_account {
    scopes = ["cloud-platform"]
  }
}

# Optional: Create a firewall rule to allow HTTP traffic
resource "google_compute_firewall" "allow_http" {
  name    = "allow-http-e2-micro"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["web-server"]
}

# Outputs
output "instance_names" {
  description = "Names of the created instances"
  value       = google_compute_instance.e2_micro_instances[*].name
}

output "instance_external_ips" {
  description = "External IP addresses of the instances"
  value       = google_compute_instance.e2_micro_instances[*].network_interface.0.access_config.0.nat_ip
}

output "instance_internal_ips" {
  description = "Internal IP addresses of the instances"
  value       = google_compute_instance.e2_micro_instances[*].network_interface.0.network_ip
}

output "instance_self_links" {
  description = "Self-links of the created instances"
  value       = google_compute_instance.e2_micro_instances[*].self_link
}