# value from data-platform tenant kit
bucket = "tenant-data-platform-state-bucket-46e6a1a5"
# value from data-platform tenant kit
dynamodb_table = "tenant-data-platform-lock-table-46e6a1a5"
# unique key for our resource across all projects creating infra in our account. Can be anything but we are using:
# <project>/<infra-region>/<resource-identifier>.tfstate
key = "data-platform-infra/us-east-1/cpp-integration-service.tfstate"
# region stated in data-platform tenant kit, not the region we want to create resources in
region = "eu-west-1"