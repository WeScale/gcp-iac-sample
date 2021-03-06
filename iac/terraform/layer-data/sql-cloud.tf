resource "google_sql_database_instance" "lp-instance-sql" {
  name             = "lp-instance-sql-${terraform.workspace}-${var.unique_id}"
  region           = "${var.region}"
  database_version = "${var.database_version}"

  settings {
    tier      = "${var.database_instance_type}"
    disk_size = "${var.database_disk_size}"

    ip_configuration {
      ipv4_enabled    = "false"
      private_network = "${data.terraform_remote_state.layer-base.lp-network-self-link}"
    }

    backup_configuration {
      enabled            = "true"
      binary_log_enabled = "true"
      start_time         = "01:00"
    }

    maintenance_window {
      // on saturday
      day = "6"

      // at 2 on the morning
      hour = "2"

      // only stable version
      update_track = "stable"
    }
  }

  timeouts {
    create = "20m"
    delete = "20m"
  }
}

resource "google_sql_database_instance" "lp-instance-sql-slave" {
  count            = "${var.env != "dev" ? 1:0}"
  name             = "${google_sql_database_instance.lp-instance-sql.name}-slave"
  database_version = "${var.database_version}"
  region           = "${var.region}"

  master_instance_name = "${google_sql_database_instance.lp-instance-sql.name}"

  settings {
    tier      = "${var.database_instance_type}"
    disk_size = "${var.database_disk_size}"

    ip_configuration {
      ipv4_enabled    = "false"
      private_network = "${data.terraform_remote_state.layer-base.lp-network-self-link}"
    }

    location_preference {
      zone = "${var.region}-a"
    }
  }

  replica_configuration = {
    failover_target = true
  }

  timeouts {
    create = "20m"
    delete = "20m"
  }
}

resource "google_sql_user" "lb-sql-admin" {
  depends_on = ["google_sql_database_instance.lp-instance-sql"]

  name     = "admin-${terraform.workspace}"
  instance = "lp-instance-sql-${terraform.workspace}-${var.unique_id}"
  password = "${var.admin_password}"
  host     = "%"
}

resource "google_sql_user" "lb-sql-app" {
  depends_on = ["google_sql_database_instance.lp-instance-sql"]

  name     = "app-${terraform.workspace}"
  instance = "lp-instance-sql-${terraform.workspace}-${var.unique_id}"
  password = "${var.app_password}"
  host     = "%"
}

resource "google_sql_database" "lp-sql-database" {
  depends_on = ["google_sql_database_instance.lp-instance-sql"]

  name      = "my-database"
  instance  = "lp-instance-sql-${terraform.workspace}-${var.unique_id}"
  charset   = "utf8"
  collation = "utf8_general_ci"
}

resource "google_dns_record_set" "mysql-instance" {
  name = "bdd.${data.terraform_remote_state.layer-base.dns-private-zone}"
  type = "A"
  ttl  = 300

  managed_zone = "${data.terraform_remote_state.layer-base.dns-private-zone-name}"

  rrdatas = ["${google_sql_database_instance.lp-instance-sql.private_ip_address}"]
}

resource "google_dns_record_set" "mysql-instance-slave" {
  count = "${var.env != "dev" ? 1:0}"
  name  = "bdd-slave-a.${data.terraform_remote_state.layer-base.dns-private-zone}"
  type  = "A"
  ttl   = 300

  managed_zone = "${data.terraform_remote_state.layer-base.dns-private-zone-name}"

  rrdatas = ["${google_sql_database_instance.lp-instance-sql-slave.private_ip_address}"]
}
