terraform {
  backend "remote" {
    hostname = "app.terraform.io"
    organization = "snapshot_tf_serverless"
    workspaces {
      name = "vault-gh-actions"
    }
  }
}
