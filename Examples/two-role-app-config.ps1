# import AppRoller
remove-module AppRoller -ErrorAction SilentlyContinue
$currentPath = Split-Path $myinvocation.mycommand.path
Import-Module (Resolve-Path (Join-Path $currentPath  ..\AppRoller.psm1))

$applicationName = "MyApp"
$applicationVersion = 1.0.1

$secureData = Get-ItemProperty -Path "HKLM:SOFTWARE\AppRoller\Tests"
$adminUsername = $secureData.adminUsername
$adminPassword = $secureData.adminPassword

$securePassword = ConvertTo-SecureString $adminPassword -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential $adminUsername, $securePassword

# set global deployment configuration
#Set-DeploymentConfig applicationsFolder "$($env:SystemDrive)\applications"
Set-DeploymentConfig taskExecutionTimeout 60 # 1 min


# --------------------------------------------
#
#   Configuring application and environments
#
# --------------------------------------------

# create new application
$myApp = New-Application MyApp -BasePath "$($env:SystemDrive)\apps\myapp" -Variables @{
    "appveyorApiKey" = "key1"
    "appveyorApiSecret" = "secret1"
} -OnPackageDownload {
    #Write-Log "Download!!!!"
    #$context.Application.Variables
}

# add website role
Add-WebSiteRole $myapp -Name "MyAppWebsite" -DeploymentGroup web -PackageUrl http://www.mysite.com/web-package.zip `
    -BasePath "$($env:SystemDrive)\websites\myapp"


# add service role
Add-ServiceRole $myapp -Name "MyAppService" -PackageUrl http://www.mysite.com/service-package.zip -Variables @{
    "ConnectionString.Default" = "server=locahost;"
}

# add custom deployment task
Set-DeploymentTask task1 -Before deploy -Application $applicationName -Version 1.0.0 -DeploymentGroup web -PerGroup {
    Write-Log "task1: do something on ONE of the group nodes of web deployment group before deployment"
    $a
}

Set-DeploymentTask task2 -Before task1 {
    Write-Log "task2: do something on EACH node of every group before appliction deployment"
    $a = 1
}

Set-DeploymentTask task3 -After rollback -Application $applicationName -Version 1.2.0 -DeploymentGroup web {
    Write-Log "task3: do something on EACH node of web deployment group after successful rollback from 1.2.0"
}

# describe Staging environment
<#
$staging = New-Environment -Name Staging -Credential $credential
Add-EnvironmentServer $staging "test-ps2.cloudapp.net" -Port 51281 -DeploymentGroup web
Add-EnvironmentServer $staging "test-ps1.cloudapp.net" -Port 5986 -DeploymentGroup app `
    -Credential (New-Object System.Management.Automation.PSCredential "appveyor", $securePassword)
Add-EnvironmentServer $staging "test-ps3.cloudapp.net" -Port 5986 -DeploymentGroup app
#>
$staging = New-Environment -File (Join-Path $currentPath staging.json) -Credential $credential

$staging

# --------------------------------------------
#
#   Deploying tests
#
# --------------------------------------------

# perform deployment to staging
New-Deployment myapp 1.0.0 -To staging -Verbose #-Serial

Set-DeploymentTask setup:env -DeploymentGroup app {
    Write-Log "Setup environment for the first time: $($env:COMPUTERNAME)"
}

Invoke-DeploymentTask setup:env -On staging -Verbose

# remove deployment
#Remove-Deployment $myapp -From $staging

# rollback deployment
#Restore-Deployment $myapp -On $staging

# restart deployment
#Restart-Deployment $myapp -On $staging

# stop deployment
#Stop-Deployment $myapp -On $staging

# start deployment
#Start-Deployment $myapp -On $staging

<#
Events:
    deploy
    rollback
    remove
#>

Remove-Module AppRoller