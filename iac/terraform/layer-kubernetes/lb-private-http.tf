resource "google_compute_global_address" "lb-private-ip" {
  name = "lb-private-ip-${terraform.workspace}"
}

resource "google_compute_global_forwarding_rule" "lp-private-lb-http" {
  name       = "lp-private-lb-http-${terraform.workspace}"
  target     = "${google_compute_target_http_proxy.lp-private-k8s-pool.self_link}"
  ip_address = "${google_compute_global_address.lb-private-ip.self_link}"
  port_range = "80"
}

resource "google_compute_target_http_proxy" "lp-private-k8s-pool" {
  name    = "lp-private-k8s-pool-${terraform.workspace}"
  url_map = "${google_compute_url_map.lb-private-urlmap.self_link}"
}

resource "google_compute_http_health_check" "lp-private-k8s-hc" {
  name               = "lp-private-k8s-hc-${terraform.workspace}"
  request_path       = "/ping"
  check_interval_sec = 10
  timeout_sec        = 1
  port               = 32080
}

resource "google_compute_url_map" "lb-private-urlmap" {
  name        = "lb-private-urlmap-${terraform.workspace}"
  description = "a description"

  default_service = "${google_compute_backend_service.lp-private-home.self_link}"

  host_rule {
    hosts        = ["admin.${terraform.workspace}.gcp-wescale.slavayssiere.fr"]
    path_matcher = "admin"
  }

  host_rule {
    hosts        = ["public-ic.${terraform.workspace}.gcp-wescale.slavayssiere.fr"]
    path_matcher = "public-ic"
  }

  host_rule {
    hosts        = ["private-ic.${terraform.workspace}.gcp-wescale.slavayssiere.fr"]
    path_matcher = "private-ic"
  }

  host_rule {
    hosts        = ["consul.${terraform.workspace}.gcp-wescale.slavayssiere.fr"]
    path_matcher = "consul"
  }

  path_matcher {
    name            = "admin"
    default_service = "${google_compute_backend_service.lp-private-home.self_link}"

    path_rule {
      paths   = ["/static/*"]
      service = "${google_compute_backend_bucket.lp-private-static.self_link}"
    }
  }

  path_matcher {
    name            = "private-ic"
    default_service = "${google_compute_backend_service.lp-private-home.self_link}"
  }

  path_matcher {
    name            = "public-ic"
    default_service = "${google_compute_backend_service.lp-private-home.self_link}"
  }

  path_matcher {
    name            = "consul"
    default_service = "${google_compute_backend_service.lp-private-home.self_link}"
  }
}

resource "google_compute_backend_service" "lp-private-home" {
  provider        = "google-beta"
  name            = "lp-private-home-${terraform.workspace}"
  description     = "Our company website"
  port_name       = "http-private"
  protocol        = "HTTP"
  timeout_sec     = 10
  enable_cdn      = false
  security_policy = "${data.terraform_remote_state.layer-base.security-policy}"

  backend {
    group          = "${replace(element(google_container_node_pool.np-default.instance_group_urls, 1), "Manager", "")}"
    balancing_mode = "UTILIZATION"
  }

  backend {
    group          = "${replace(element(google_container_node_pool.np-default.instance_group_urls, 2), "Manager", "")}"
    balancing_mode = "UTILIZATION"
  }

  backend {
    group          = "${replace(element(google_container_node_pool.np-default.instance_group_urls, 3), "Manager", "")}"
    balancing_mode = "UTILIZATION"
  }

  health_checks = ["${google_compute_http_health_check.lp-private-k8s-hc.self_link}"]
}

resource "google_compute_backend_bucket" "lp-private-static" {
  name        = "lp-private-static-${terraform.workspace}"
  description = "Contains beautiful images"
  bucket_name = "${google_storage_bucket.lp-private-static-bucket.name}"
  enable_cdn  = false
}
