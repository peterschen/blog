locals {
  project_name = var.project_name
  network_name = var.network_name
  rules = var.rules
}

data "google_compute_network" "network" {
  project = local.project_name
  name = local.network_name
}

resource "google_compute_firewall" "rule" {
  count = length(local.rules)
  project = var.project_name
  name = local.rules[count.index].name

  network = data.google_compute_network.network.name
  priority = local.rules[count.index].priority
  disabled = local.rules[count.index].disabled

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
