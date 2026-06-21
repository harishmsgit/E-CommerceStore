param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('existing', 'provision')]
    [string]$Mode,

    [string]$Region = 'ap-south-1',
    [string]$AccountId = '495013583028',
    [string]$DockerhubUsername = 'harsen',
    [string]$ImageTag = 'latest',
    [string]$SshUser = 'ec2-user',
    [string]$SshPrivateKeyPath = 'C:/path/to/your-key.pem',

    [string]$InstanceId = 'i-0523c91cfc25de02b',
    [string]$VpcId = 'vpc-0714e469a68ae1721',
    [string]$SubnetId = 'subnet-00bf4ffcdb135dfba',
    [string]$SecurityGroupId = 'sg-0fe408481fc8b427d',
    [bool]$OpenFrontendPort = $false,
    [bool]$OpenSshPort = $true,
    [string]$SshAllowedCidr = '0.0.0.0/0',
    [bool]$OpenServicePorts = $false,
    [string]$ServicePortsAllowedCidr = '0.0.0.0/0',

    [string]$InstanceType = 't3.medium',
    [string]$KeyName = '',
    [string]$VpcCidr = '10.10.0.0/16',
    [string]$PublicSubnetCidr = '10.10.1.0/24'
)

$repoRoot = Split-Path -Parent $PSScriptRoot
$tfvarsPath = Join-Path $repoRoot 'terraform/terraform.tfvars'

if (-not (Test-Path (Join-Path $repoRoot 'terraform'))) {
    throw 'terraform folder not found. Run this script from the repository where terraform/ exists.'
}

if ($Mode -eq 'provision' -and [string]::IsNullOrWhiteSpace($KeyName)) {
    throw 'KeyName is required for provision mode. Pass -KeyName <your-ec2-keypair-name>.'
}

$content = @"
aws_region           = "$Region"
deployment_mode      = "$Mode"
account_id           = "$AccountId"
instance_id          = "$InstanceId"
vpc_id               = "$VpcId"
subnet_id            = "$SubnetId"
security_group_id    = "$SecurityGroupId"
instance_type        = "$InstanceType"
key_name             = "$KeyName"
vpc_cidr             = "$VpcCidr"
public_subnet_cidr   = "$PublicSubnetCidr"
dockerhub_username   = "$DockerhubUsername"
image_tag            = "$ImageTag"
ssh_user             = "$SshUser"
ssh_private_key_path = "$SshPrivateKeyPath"
open_frontend_port   = $($OpenFrontendPort.ToString().ToLower())
open_ssh_port        = $($OpenSshPort.ToString().ToLower())
ssh_allowed_cidr     = "$SshAllowedCidr"
open_service_ports   = $($OpenServicePorts.ToString().ToLower())
service_ports_allowed_cidr = "$ServicePortsAllowedCidr"
"@

Set-Content -Path $tfvarsPath -Value $content -Encoding utf8
Write-Host "Updated terraform.tfvars for mode: $Mode"
Write-Host "File: $tfvarsPath"

if ($Mode -eq 'existing') {
    Write-Host 'Using provided existing IDs for EC2/VPC/Subnet/Security Group.'
} else {
    Write-Host 'Provision mode selected. Terraform will create VPC, subnet, SG, and EC2.'
}
