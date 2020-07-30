A solution for backing up AWS instances by Images

Features:
* Tags are used for selection of Instance as a source for Image. Also, specific tags are applied to images and snapshots;
* The same tags are used for setting how long save images;
* Images are created by Lambda function (server-less solution). So nothing needed to be installed on servers;
* Lambda function is launched by CloudWatch scheduler (cron-like);
* You can configure as many tasks as needed. Each task creates a snapshot for only one server and only one scheduler. For example, daily backups
* Terraform-ready

# How to use
1. using AWS CLI configure your named profile: `aws configure --profile my_aws_profile`
2. create `terraform.tfvars` with you values. For example:
  ```hcl-terraform
  aws_profile = "my_aws_profile"
  aws_region  = "us-west-1"
  plan = {
    Server1BackupDaily    = "cron(00 10 * * ? *)"
    Server1BackupWeekly   = "cron(20 10 ? * 1 *)"
    Server2BackupDaily    = "cron(40 10 * * ? *)"
    Server2BackupWeekly   = "cron(00 11 ? * 1 *)"
    Server2BackupMonthly  = "cron(20 11 1 * ? *)"
  }
  ```
3. Check and apply: `terraform apply`
4. Add tags to your instances:
  ```hcl-terraform
  Server1BackupDaily = 7
  Server1BackupWeekly = 21
  Server2BackupDaily = 14
  Server2BackupWeekly = 35
  Server2BackupMonthly = 120
  ```

# How it is works
When you run `terraform apply`, Terraform will:
1. use your AWS profile name from variable `aws_profile`. You need to add some IAM permissions for creating Lambda 
function, IAM policies and role, Cloudwatch rules and log groups. Or you can just create AWS Key with admin rights :)
2. create Lambda function (python 3.X) with code from `lambda` dir in this project;
3. create Cloudwatch rules from the `plan` variable (one rule per plan name). In example above plan variable consists 5 
plans;
4. create resources like IAM policied and so on.

When a specific plan is launched (by Cloudwatch rule with `plan_name` as a parameter) Lambda function does:
1. searches Instances (servers) with a specific tag name (the same
as the value of `plan_name`, for example: `Server1BackupDaily`) and makes list for work. 
2. for each Instance in this list looks at the value of the tag that == `plan_name`. This value is how long to save the image and its snapshots
3. for each instance in the list makes image and adds tags to resulting resources (image and its snapshots). Also, add the tag `BackupSaveDays` with the value from step 2;
4. searches all images with tag `BackupPolicy == plan_name` and with tag name `BackupSaveDays` and compares with the current date. If some images suits to deletion deregisters image and removes all associated with this image snapshots
