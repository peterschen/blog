locals {
  project_name = var.project_name
  network_name = var.network_name
  network_id = var.network_id
  rules = var.rules
}

resource "google_tags_tag_key" "firewal_iap_ssh" {
  parent = "projects/${local.project_name}"
  short_name = "firewallAllowIapSsh"
  purpose = "GCE_FIREWALL"
  purpose_data = {
    network = "${local.project_name}/${local.network_name}"
  }
}

resource "google_tags_tag_key" "firewal_iap_rdp" {
  parent = "projects/${local.project_name}"
  short_name = "firewallAllowIapRdp"
  purpose = "GCE_FIREWALL"
  purpose_data = {
    network = "${local.project_name}/${local.network_name}"
  }
}

resource "google_tags_tag_value" "ssh_true" {
  parent = "tagKeys/${google_tags_tag_key.firewal_iap_ssh.name}"
  short_name = "true"
}

resource "google_tags_tag_value" "rdp_true" {
  parent = "tagKeys/${google_tags_tag_key.firewal_iap_rdp.name}"
  short_name = "true"
}

resource "google_compute_network_firewall_policy" "iap_ingress" {
  project = local.project_name
  name = "iap-ingress"
  description = "Policy controlling IAP ingress"
}

resource "google_compute_network_firewall_policy_association" "iap_ingress" {
  project = local.project_name
  name = "iap-ingress"
  attachment_target = local.network_id
  firewall_policy =  google_compute_network_firewall_policy.iap_ingress.name
}

resource "google_network_security_address_group" "iap" {
  name = "iap"
  parent = "projects/${local.project_name}"
  description = "Address group for IAP ranges"
  location = "global"
  items = ["35.235.240.0/20"]
  type = "IPV4"
  capacity = 100
}

resource "google_compute_network_firewall_policy_rule" "allow_ssh_iap_ingress" {
  project = local.project_name
  rule_name = "allow-ssh-iap-ingress"
  action = "allow"
  disabled = false
  priority = 50000
  direction = "INGRESS"
  enable_logging = true

  firewall_policy = google_compute_network_firewall_policy.iap_ingress.name
  
  target_secure_tags {
    name = google_tags_tag_value.ssh_true.id
  }

  match {
    layer4_configs {
      ip_protocol = "tcp"
      ports = ["22"]
    }

    src_address_groups = [
      google_network_security_address_group.iap.id
    ]
  }
}

resource "google_compute_network_firewall_policy_rule" "allow_rdp_iap_ingress" {
  project = local.project_name
  rule_name = "allow-rdp-iap-ingress"
  action = "allow"
  disabled = false
  priority = 50100
  direction = "INGRESS"
  enable_logging = true

  firewall_policy = google_compute_network_firewall_policy.iap_ingress.name
  
  target_secure_tags {
    name = google_tags_tag_value.rdp_true.id
  }

  match {
    layer4_configs {
      ip_protocol = "tcp"
      ports = ["3389"]
    }

    src_address_groups = [
      google_network_security_address_group.iap.id
    ]
  }
}


resource "google_compute_firewall" "rule" {
  count = length(local.rules)
  project = var.project_name
  name = local.rules[count.index].name

  network = local.network_name
  priority = local.rules[count.index].priority
  disabled = local.rules[count.index].disabled
  direction = local.rules[count.index].direction

  dynamic allow {
    for_each = toset(local.rules[count.index].allow)
    iterator = rule

    content {
      protocol = rule.value.protocol
      ports = rule.value.ports
    }
  }

  dynamic "deny" {
    for_each = toset(local.rules[count.index].deny)
    iterator = rule

    content {
      protocol = rule.value.protocol
      ports = rule.value.ports
    }
  }

  source_tags = local.rules[count.index].source_tags
  target_tags = local.rules[count.index].target_tags
  source_ranges = local.rules[count.index].source_ranges
  destination_ranges = local.rules[count.index].destination_ranges

  dynamic "log_config" {
    for_each = local.rules[count.index].logging ? toset([1]) : toset([])

    content {
      metadata = "INCLUDE_ALL_METADATA"
    }
  }
}
