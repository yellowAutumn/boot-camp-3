variable "dns_zone_name" {
  description = "The name of the DNS managed zone"
  type        = string
}

provider "google" {
  project = var.project_id
  region  = var.regions[0]
}

# Create two VPCs in two different regions
resource "google_compute_network" "vpc" {
  count                   = length(var.regions)
  name                    = var.vpc_names[count.index]
  auto_create_subnetworks = false
}

# Create two storage buckets in two different regions
resource "google_storage_bucket" "buckets" {
  count         = length(var.regions)
  name          = var.bucket_names[count.index]
  location      = var.regions[count.index]
  force_destroy = true

  versioning {
    enabled = true
  }

  website {
    main_page_suffix = "index.html"
    not_found_page   = "index.html"
  }
}

# Create two Firestore databases in multi-region mode (nam5)
resource "google_firestore_database" "default" {
  count       = 2
  name        = "bootcamp-3-database-${count.index + 1}"
  project     = var.project_id
  location_id = var.firestore_location
  type        = "FIRESTORE_NATIVE"
}

# Create a managed zone in Cloud DNS
resource "google_dns_managed_zone" "main" {
  name     = var.dns_zone_name
  dns_name = "testbootcampprojects.website."
  project  = var.project_id
}

# Add A record for the load balancer's global IP
resource "google_dns_record_set" "app" {
  name         = "app.testbootcampprojects.website."
  type         = "A"
  ttl          = 60
  managed_zone = google_dns_managed_zone.main.name
  rrdatas      = [google_compute_global_address.default.address]
}

# Add A record for www to point to the load balancer's global IP
resource "google_dns_record_set" "www" {
  name         = "www.testbootcampprojects.website."
  type         = "A"
  ttl          = 60
  managed_zone = google_dns_managed_zone.main.name
  rrdatas      = [google_compute_global_address.default.address]
}

# Upload region1.html and region2.html as index.html to their respective region buckets
resource "google_storage_bucket_object" "region1_html" {
  name   = "index.html"
  bucket = google_storage_bucket.buckets[0].name
  source = "${path.module}/region1.html"
  content_type = "text/html"
}

resource "google_storage_bucket_object" "region2_html" {
  name   = "index.html"
  bucket = google_storage_bucket.buckets[1].name
  source = "${path.module}/region2.html"
  content_type = "text/html"
}

resource "google_compute_backend_bucket" "region1" {
  name        = "backend-bucket-region1"
  bucket_name = google_storage_bucket.buckets[0].name
  enable_cdn  = true
}

resource "google_compute_backend_bucket" "region2" {
  name        = "backend-bucket-region2"
  bucket_name = google_storage_bucket.buckets[1].name
  enable_cdn  = true
}

resource "google_compute_url_map" "default" {
  name            = "url-map-static"
  default_service = google_compute_backend_bucket.region1.id

  host_rule {
    hosts        = ["testbootcampprojects.website"]
    path_matcher = "allpaths"
  }

  path_matcher {
    name            = "allpaths"
    default_service = google_compute_backend_bucket.region1.id

    path_rule {
      paths   = ["/*"]
      service = google_compute_backend_bucket.region1.id
    }
  }

  test {
    host = "testbootcampprojects.website"
    path = "/"
    service = google_compute_backend_bucket.region1.id
  }
}

resource "google_compute_target_http_proxy" "default" {
  name    = "http-proxy-static"
  url_map = google_compute_url_map.default.id
}

resource "google_compute_global_address" "default" {
  name = "static-ip-static-site"
}

resource "google_compute_global_forwarding_rule" "default" {
  name                  = "forwarding-rule-static-site"
  ip_address            = google_compute_global_address.default.address
  port_range            = "80"
  target                = google_compute_target_http_proxy.default.id
  load_balancing_scheme = "EXTERNAL"
}

resource "google_compute_managed_ssl_certificate" "default" {
  name = "static-site-ssl"
  managed {
    domains = ["testbootcampprojects.website"]
  }
}

resource "google_compute_target_https_proxy" "default" {
  name             = "https-proxy-static"
  url_map          = google_compute_url_map.default.id
  ssl_certificates = [google_compute_managed_ssl_certificate.default.id]
}

resource "google_compute_global_forwarding_rule" "https" {
  name                  = "forwarding-rule-static-site-https"
  ip_address            = google_compute_global_address.default.address
  port_range            = "443"
  target                = google_compute_target_https_proxy.default.id
  load_balancing_scheme = "EXTERNAL"
}

# SECOND LOAD BALANCER FOR REGION 2
resource "google_compute_global_address" "region2" {
  name = "static-ip-static-site-region2"
}

resource "google_compute_backend_bucket" "region2_lb" {
  name        = "backend-bucket-region2-lb"
  bucket_name = google_storage_bucket.buckets[1].name
  enable_cdn  = true
}

resource "google_compute_url_map" "region2" {
  name            = "url-map-static-region2"
  default_service = google_compute_backend_bucket.region2_lb.id

  host_rule {
    hosts        = ["testbootcampprojects.website"]
    path_matcher = "allpaths"
  }

  path_matcher {
    name            = "allpaths"
    default_service = google_compute_backend_bucket.region2_lb.id

    path_rule {
      paths   = ["/*"]
      service = google_compute_backend_bucket.region2_lb.id
    }
  }

  test {
    host = "testbootcampprojects.website"
    path = "/"
    service = google_compute_backend_bucket.region2_lb.id
  }
}

resource "google_compute_target_http_proxy" "region2" {
  name    = "http-proxy-static-region2"
  url_map = google_compute_url_map.region2.id
}

resource "google_compute_managed_ssl_certificate" "region2" {
  name = "static-site-ssl-region2"
  managed {
    domains = ["testbootcampprojects.website"]
  }
}

resource "google_compute_target_https_proxy" "region2" {
  name             = "https-proxy-static-region2"
  url_map          = google_compute_url_map.region2.id
  ssl_certificates = [google_compute_managed_ssl_certificate.region2.id]
}

resource "google_compute_global_forwarding_rule" "region2_http" {
  name                  = "forwarding-rule-static-site-region2-http"
  ip_address            = google_compute_global_address.region2.address
  port_range            = "80"
  target                = google_compute_target_http_proxy.region2.id
  load_balancing_scheme = "EXTERNAL"
}

resource "google_compute_global_forwarding_rule" "region2_https" {
  name                  = "forwarding-rule-static-site-region2-https"
  ip_address            = google_compute_global_address.region2.address
  port_range            = "443"
  target                = google_compute_target_https_proxy.region2.id
  load_balancing_scheme = "EXTERNAL"
}

resource "google_storage_bucket_iam_binding" "public_read_region1" {
  bucket = google_storage_bucket.buckets[0].name
  role   = "roles/storage.objectViewer"
  members = [
    "allUsers",
  ]
}

resource "google_storage_bucket_iam_binding" "public_read_region2" {
  bucket = google_storage_bucket.buckets[1].name
  role   = "roles/storage.objectViewer"
  members = [
    "allUsers",
  ]
}

resource "google_storage_transfer_job" "replicate_to_region2" {
  description = "Replicate objects from region1 bucket to region2 bucket"
  project     = var.project_id

  transfer_spec {
    gcs_data_source {
      bucket_name = google_storage_bucket.buckets[0].name
    }
    gcs_data_sink {
      bucket_name = google_storage_bucket.buckets[1].name
    }
    transfer_options {
      overwrite_objects_already_existing_in_sink = true
    }
  }

  schedule {
    schedule_start_date {
      year  = 2025
      month = 6
      day   = 21
    }
    start_time_of_day {
      hours   = 0
      minutes = 0
      seconds = 0
      nanos   = 0
    }
  }

  status = "ENABLED"
}

resource "google_storage_bucket_iam_member" "transfer_service_region1" {
  bucket = google_storage_bucket.buckets[0].name
  role   = "roles/storage.admin"
  member = "serviceAccount:project-702586501583@storage-transfer-service.iam.gserviceaccount.com"
}

resource "google_storage_bucket_iam_member" "transfer_service_region2" {
  bucket = google_storage_bucket.buckets[1].name
  role   = "roles/storage.admin"
  member = "serviceAccount:project-702586501583@storage-transfer-service.iam.gserviceaccount.com"
}

resource "google_storage_bucket_iam_member" "transfer_service_region1_get" {
  bucket = google_storage_bucket.buckets[0].name
  role   = "roles/storage.legacyBucketReader"
  member = "serviceAccount:project-702586501583@storage-transfer-service.iam.gserviceaccount.com"
}

resource "google_storage_bucket_iam_member" "transfer_service_region2_get" {
  bucket = google_storage_bucket.buckets[1].name
  role   = "roles/storage.legacyBucketReader"
  member = "serviceAccount:project-702586501583@storage-transfer-service.iam.gserviceaccount.com"
}

resource "google_storage_bucket_iam_member" "transfer_service_region1_legacy" {
  bucket = google_storage_bucket.buckets[0].name
  role   = "roles/storage.legacyBucketReader"
  member = "serviceAccount:project-702586501583@storage-transfer-service.iam.gserviceaccount.com"
}

resource "google_storage_bucket_iam_member" "transfer_service_region2_legacy" {
  bucket = google_storage_bucket.buckets[1].name
  role   = "roles/storage.legacyBucketReader"
  member = "serviceAccount:project-702586501583@storage-transfer-service.iam.gserviceaccount.com"
}

# Health checks and routing policies for intelligent failover would typically be managed by GCP's Traffic Director or external monitoring tools.
# You can reference the health check and use an external automation to update DNS records based on health status.
