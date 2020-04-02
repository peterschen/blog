# SOFS on GCP #

```
terraform taint module.ad-on-gcp.google_compute_instance.jumpy
terraform taint module.ad-on-gcp.google_compute_instance.dc\[0\]
terraform taint module.ad-on-gcp.google_compute_instance.dc\[1\]
terraform taint google_compute_instance.sofs\[0\]
terraform taint google_compute_instance.sofs\[1\]
terraform taint google_compute_instance.sofs\[2\]
```