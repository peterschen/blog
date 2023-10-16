locals {
  project = var.project
  network = var.network
  enable_rdp = var.enable_rdp
  enable_ssh = var.enable_ssh
  enable_http = var.enable_http
  enable_http_alt = var.enable_http_alt
  enable_https = var.enable_https
  enable_https_alt = var.enable_https_alt
  enable_dotnet_http = var.enable_dotnet_http
  enable_dotnet_https = var.enable_dotnet_https
}

resource "google_compute_firewall" "allow-rdp-iap" {
  count = local.enable_rdp ? 1 : 0

  project = local.project
  name = "allow-rdp-iap"
  network = local.network
  priority = 5000

  allow {
    protocol = "tcp"
    ports    = ["3389"]
  }

  direction = "INGRESS"

  source_ranges = ["35.235.240.0/20"]

  target_tags = ["rdp"]
}

resource "google_compute_firewall" "allow-ssh-iap" {
  count = local.enable_ssh ? 1 : 0
  
  project = local.project
  name = "allow-ssh-iap"
  network = local.network
  priority = 5000

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  direction = "INGRESS"

  source_ranges = ["35.235.240.0/20"]

  target_tags = ["ssh"]
}

resource "google_compute_firewall" "allow-http-iap" {
  count = local.enable_http ? 1 : 0
  
  project = local.project
  name = "allow-http-iap"
  network = local.network
  priority = 5000

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  direction = "INGRESS"

  source_ranges = ["35.235.240.0/20"]

  target_tags = ["http-iap"]
}

resource "google_compute_firewall" "allow-http-alt-iap" {
  count = local.enable_http_alt ? 1 : 0
  
  project = local.project
  name = "allow-http-alt-iap"
  network = local.network
  priority = 5000

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }

  direction = "INGRESS"

  source_ranges = ["35.235.240.0/20"]

  target_tags = ["http-alt-iap"]
}

resource "google_compute_firewall" "allow-https-iap" {
  count = local.enable_https ? 1 : 0
  
  project = local.project
  name = "allow-https-iap"
  network = local.network
  priority = 5000

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  direction = "INGRESS"

  source_ranges = ["35.235.240.0/20"]

  target_tags = ["https-iap"]
}

resource "google_compute_firewall" "allow-https-alt-iap" {
  count = local.enable_https_alt ? 1 : 0
  
  project = local.project
  name = "allow-https-alt-iap"
  network = local.network
  priority = 5000

  allow {
    protocol = "tcp"
    ports    = ["8443"]
  }

  direction = "INGRESS"

  source_ranges = ["35.235.240.0/20"]

  target_tags = ["https-alt-iap"]
}

resource "google_compute_firewall" "allow-dotnet-http-iap" {
  count = local.enable_dotnet_http ? 1 : 0
  
  project = local.project
  name = "allow-dotnet-http-iap"
  network = local.network
  priority = 5000

  allow {
    protocol = "tcp"
    ports    = ["5000"]
  }

  direction = "INGRESS"

  source_ranges = ["35.235.240.0/20"]

  target_tags = ["dotnet-http-iap"]
}

resource "google_compute_firewall" "allow-dotnet-https-iap" {
  count = local.enable_dotnet_https ? 1 : 0
  
  project = local.project
  name = "allow-dotnet-https-iap"
  network = local.network
  priority = 5000

  allow {
    protocol = "tcp"
    ports    = ["5001"]
  }

  direction = "INGRESS"

  source_ranges = ["35.235.240.0/20"]

  target_tags = ["dotnet-https-iap"]
}
