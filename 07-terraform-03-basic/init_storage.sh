#!/usr/bin/env bash

echo $'\n''Get vars...'
storage_account=$(cat init.conf | grep storage_account | sed 's/storage_account = //')
folder_id=$(cat init.conf | grep folder_id | sed 's/folder_id = //')
bucket=$(cat init.conf | grep bucket | sed 's/bucket = //')

echo $'\n''Init storage admin account...'
stor_serv_acc_id=$(yc iam service-account create --name ${storage_account} --folder-id ${folder_id} | grep ^id: | sed 's/id: //')
yc resource-manager folder add-access-binding default --role="editor" --subject="serviceAccount:${stor_serv_acc_id}"
yc iam access-key create --service-account-name=${storage_account} >> access.key

echo $'\n''Get storage admin account access key...'
access_key=$(cat access.key | grep key_id: | sed 's/  key_id: //')
secret_key=$(cat access.key | grep secret: | sed 's/secret: //')
rm access.key

echo $'\n''Create bucket in cloud storage...'
mkdir temp_module && cd temp_module
cat > ./main.tf << _EOF_
terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}
resource "yandex_storage_bucket" "backet" {
  access_key = "${access_key}"
  secret_key = "${secret_key}"
  bucket     = "${bucket}"
}
_EOF_
terraform init

terraform apply

echo $'\n''Init main.tf file'

cd .. && rm -r temp_module
cat > ./main.tf << _EOF_
terraform {
  backend "s3" {
    endpoint   = "storage.yandexcloud.net"
    bucket     = "${bucket}"
    key        = "07-terraform/main.tfstate"
    access_key = "${access_key}"
    secret_key = "${secret_key}"
    skip_region_validation      = true
    skip_credentials_validation = true
  }
}
_EOF_
terraform init