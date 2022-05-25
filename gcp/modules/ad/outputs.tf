output "address" {
  value = [
    for address in google_compute_address.dc:
    address.address
  ]
}