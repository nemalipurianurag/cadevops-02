################################################################################################################
#issuance_policy & issuance_policy.identity_constraints.cel_expression.expression is null and fail condition with block doesnot exist
##################################################################################################################   

# Required Google APIs
locals {
  googleapis = ["privateca.googleapis.com", "storage.googleapis.com", "cloudkms.googleapis.com"]
}
# Enable required services
resource "google_project_service" "apis" {
  for_each           = toset(local.googleapis)
  project            = var.project_id
  service            = each.key
  disable_on_destroy = false
}
# resource "google_service_account" "service_account" {
#   account_id   = "test-service-account"
#   display_name = "Test Service Account for CA Enterprise Environment"
#   project  = "internal-test-prj-ly"
# }

# Create a service account to the CA service
resource "google_project_service_identity" "privateca_sa" {
  provider = google-beta
  service  = "privateca.googleapis.com"
  project  = "modular-scout-345114"
}

# Create a KMS key-ring
resource "google_kms_key_ring" "keyring" {
  name     = "keyring-example37"
  location = "us-central1"
}
# # Create a KMS key within the provided KMS key-ring
resource "google_kms_crypto_key" "secret" {
  name     = "crypto-key-example"
  key_ring = google_kms_key_ring.keyring.id
  purpose  = "ASYMMETRIC_SIGN"

  version_template {
    algorithm        = "RSA_SIGN_PSS_2048_SHA256"
    protection_level = "HSM"
  }

  lifecycle {
    prevent_destroy = false
  }
}
data "google_kms_crypto_key_version" "secret_version" {
  crypto_key = google_kms_crypto_key.secret.id
  depends_on = [google_kms_crypto_key_iam_member.cas_kms_viewer, google_kms_crypto_key_iam_member.cas_kms_signer]
}

# locals {
#   roles = ["roles/cloudkms.signerVerifier","roles/viewer","roles/cloudkms.admin","roles/cloudkms.cryptoKeyDecrypter","roles/cloudkms.cryptoKeyDecrypterViaDelegation","roles/cloudkms.cryptoKeyEncrypter","roles/cloudkms.cryptoKeyEncrypterDecrypter","roles/cloudkms.cryptoKeyEncrypterDecrypterViaDelegation","roles/cloudkms.cryptoKeyEncrypterViaDelegation","roles/cloudkms.cryptoOperator","roles/cloudkms.expertRawPKCS1","roles/cloudkms.publicKeyViewer","roles/cloudkms.verifier"]
# }

# resource "google_kms_crypto_key_iam_member" "cas_kms_signer" {
#   for_each = toset(local.roles)
#   crypto_key_id = google_kms_crypto_key.secret.id
#   role          = each.key
#   member        = "serviceAccount:${google_project_service_identity.privateca_sa.email}"
# }

# # Grant access to CAS sa to sign keys using CMEK
resource "google_kms_crypto_key_iam_member" "cas_kms_signer" {
  crypto_key_id = google_kms_crypto_key.secret.id
  role          = "roles/cloudkms.signerVerifier"
  member        = "serviceAccount:${google_project_service_identity.privateca_sa.email}"
}
# Grant access to CAS sa to view keys using CMEK
resource "google_kms_crypto_key_iam_member" "cas_kms_viewer" {
  crypto_key_id = google_kms_crypto_key.secret.id
  role          = "roles/viewer"
  member        = "serviceAccount:${google_project_service_identity.privateca_sa.email}"
}

# Grant access to the CA Pool
resource "google_privateca_ca_pool_iam_member" "policy" {
  ca_pool = google_privateca_ca_pool.example_ca_pool_enterprise.id
  role    = "roles/privateca.certificateManager"
  member  = "serviceAccount:${google_project_service_identity.privateca_sa.email}"
}

# Grant access to CAS sa to write objects to storage buckets
resource "google_storage_bucket_iam_member" "cas_bucket_object_writer" {
  bucket = google_storage_bucket.cmek_bucket.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_project_service_identity.privateca_sa.email}"
}

#Grant access to CAS sa to read storage buckets
resource "google_storage_bucket_iam_member" "cas_bucket_reader" {
  bucket = google_storage_bucket.cmek_bucket.name
  role   = "roles/storage.legacyBucketReader"
  member = "serviceAccount:${google_project_service_identity.privateca_sa.email}"
}

#Create a customer-managed bucket
resource "google_storage_bucket" "cmek_bucket" {
  project       = "modular-scout-345114"
  name          = "default237"
  force_destroy = true
  # encryption {
  #   default_kms_key_name = google_kms_crypto_key.secret.name
  # }
  location = "us-central1"
}

#creation of CA pool with teir as Enterprise
resource "google_privateca_ca_pool" "example_ca_pool_enterprise" {
  name     = "my-pool37"
  location = "us-central1"
  tier     = "DEVOPS"

  publishing_options {
    publish_ca_cert = false
    publish_crl     = false
  }
  labels = {
    foo = "bar"
  }
  issuance_policy {}
}
resource "google_privateca_certificate_authority" "default" {
  // This example assumes this pool already exists.
  // Pools cannot be deleted in normal test circumstances, so we depend on static pools
  pool                     = google_privateca_ca_pool.example_ca_pool_enterprise.name
  certificate_authority_id = "my-certificate-authority"
  location                 = "us-central1"
  deletion_protection      = false
  config {
    subject_config {
      subject {
        organization = "HashiCorp"
        common_name  = "my-certificate-authority"
      }
      subject_alt_name {
        dns_names = ["hashicorp.com"]
      }
    }
    x509_config {
      ca_options {
        is_ca                  = true
        max_issuer_path_length = 10
      }
      key_usage {
        base_key_usage {
          digital_signature  = true
          content_commitment = true
          key_encipherment   = false
          data_encipherment  = true
          key_agreement      = true
          cert_sign          = true
          crl_sign           = true
          decipher_only      = true
        }
        extended_key_usage {
          server_auth      = true
          client_auth      = false
          email_protection = true
          code_signing     = true
          time_stamping    = true
        }
      }
    }
  }
  lifetime = "86400s"
  key_spec {
    algorithm = "RSA_PSS_2048_SHA256"
  }
  type       = "SELF_SIGNED"
  gcs_bucket = google_storage_bucket.cmek_bucket.name
}


