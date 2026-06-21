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
    [string]$PublicSubnetCidr = '10.10.1.0/24',

    [switch]$SkipApply
)

$ErrorActionPreference = 'Stop'

function Invoke-Step {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [scriptblock]$Action
    )

    Write-Host "==> $Name"
    & $Action
    Write-Host "OK: $Name"
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$terraformDir = Join-Path $repoRoot 'terraform'
$modeScript = Join-Path $PSScriptRoot 'set-terraform-mode.ps1'

$hasNativeTerraform = $null -ne (Get-Command terraform -ErrorAction SilentlyContinue)
$useWslTerraform = $false
$terraformDirUnix = ''

if (-not $hasNativeTerraform) {
    if ($null -eq (Get-Command wsl -ErrorAction SilentlyContinue)) {
        throw 'Terraform CLI not found in PowerShell PATH and WSL is unavailable. Install Terraform or enable WSL Terraform access.'
    }

    & wsl bash -lc 'command -v terraform >/dev/null 2>&1'
    if ($LASTEXITCODE -ne 0) {
        throw 'Terraform CLI not found in PowerShell PATH or WSL. Install Terraform first: https://developer.hashicorp.com/terraform/downloads'
    }

    $terraformDirUnix = (& wsl wslpath -a $terraformDir).Trim()
    $useWslTerraform = $true
    Write-Host 'Terraform will run via WSL.'
}

function Invoke-Terraform {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Arguments
    )

    if ($useWslTerraform) {
        & wsl bash -lc "cd '$terraformDirUnix' && terraform $Arguments"
        if ($LASTEXITCODE -ne 0) {
            throw "terraform $Arguments failed with exit code $LASTEXITCODE"
        }
        return
    }

    Push-Location $terraformDir
    try {
        Invoke-Expression "terraform $Arguments"
        if ($LASTEXITCODE -ne 0) {
            throw "terraform $Arguments failed with exit code $LASTEXITCODE"
        }
    }
    finally {
        Pop-Location
    }
}

if (-not (Test-Path $modeScript)) {
    throw 'set-terraform-mode.ps1 not found under scripts/.'
}

Invoke-Step -Name 'Generate terraform.tfvars for selected mode' -Action {
    & $modeScript `
        -Mode $Mode `
        -Region $Region `
        -AccountId $AccountId `
        -DockerhubUsername $DockerhubUsername `
        -ImageTag $ImageTag `
        -SshUser $SshUser `
        -SshPrivateKeyPath $SshPrivateKeyPath `
        -InstanceId $InstanceId `
        -VpcId $VpcId `
        -SubnetId $SubnetId `
        -SecurityGroupId $SecurityGroupId `
        -OpenFrontendPort $OpenFrontendPort `
        -OpenSshPort $OpenSshPort `
        -SshAllowedCidr $SshAllowedCidr `
        -OpenServicePorts $OpenServicePorts `
        -ServicePortsAllowedCidr $ServicePortsAllowedCidr `
        -InstanceType $InstanceType `
        -KeyName $KeyName `
        -VpcCidr $VpcCidr `
        -PublicSubnetCidr $PublicSubnetCidr
}

Invoke-Step -Name 'terraform init' -Action { Invoke-Terraform 'init -input=false' }
Invoke-Step -Name 'terraform fmt' -Action { Invoke-Terraform 'fmt' }
Invoke-Step -Name 'terraform validate' -Action { Invoke-Terraform 'validate' }
Invoke-Step -Name 'terraform plan' -Action { Invoke-Terraform 'plan' }

if (-not $SkipApply) {
    Invoke-Step -Name 'terraform apply' -Action { Invoke-Terraform 'apply -auto-approve' }
    Invoke-Step -Name 'terraform output frontend_url' -Action { Invoke-Terraform 'output frontend_url' }
    Invoke-Step -Name 'terraform output service_urls' -Action { Invoke-Terraform 'output service_urls' }
} else {
    Write-Host 'SkipApply detected. Apply step was skipped.'
}
