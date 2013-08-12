# import AppRoller
$currentPath = Split-Path $myinvocation.mycommand.path
Import-Module (Resolve-Path (Join-Path $currentPath  ..\AppRoller.psm1))

$applicationName = "MyApp"
$applicationVersion = 1.0.1

$secureData = Get-ItemProperty -Path "HKLM:SOFTWARE\AppRoller\Tests"
$adminUsername = $secureData.adminUsername
$adminPassword = $secureData.adminPassword
$deployVersion = 1.0.1

$securePassword = ConvertTo-SecureString $adminPassword -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential $adminUsername, $securePassword

# set global deployment configuration
# Set-DeploymentConfig applicationsFolder "$($env:SystemDrive)\applications"


# --------------------------------------------
#
#   Configuring application and environments
#
# --------------------------------------------

# create new application
$myApp = New-Application MyApp -BasePath "$($env:SystemDrive)\apps\myapp" -Variables @{
    "appveyorApiKey" = "key1"
    "appveyorApiSecret" = "secret1"
}

# add website role
Add-WebSiteRole $myapp -Name "MyAppWebsite" -DeploymentGroup web -PackageUrl http://www.mysite.com/web-package.zip -BasePath "$($env:SystemDrive)\websites\myapp"

# add service role
Add-ServiceRole $myapp -Name "MyAppService" -PackageUrl http://www.mysite.com/service-package.zip -Variables @{
    "ConnectionString.Default" = "server=locahost;"
}

# add custom deployment task
New-DeploymentTask task1 -Before deploy -DeploymentGroup web -Application $applicationName -Version 1.0.0 {
	# do something REMOTELY on "primary" node of "web" deployment group before deployment
	# this could be used for setting up load balancer or running SQL scripts, i.e. anything that must be run once for all role nodes
}

New-DeploymentTask task2 -Before deploy {
	# do something LOCALLY before deployment of the entire application
    Write-Output "Hello 1"
}

New-DeploymentTask task3 -After rollback -DeploymentGroupServer web -Application $applicationName -Version 1.2.0 {
	# do something REMOTELY on EACH node of "web" deployment group after successful rollback from 1.2.0 version
    Write-Output "Hello 2"
}

# describe Staging environment
$staging = New-Environment Staging -Default
Add-EnvironmentServer $staging "test-web1.cloudapp.net"

# describe Production environment
$production = New-Environment Production -Credential $credential
Add-EnvironmentServer $production "test-ps1.cloudapp.net" -Port 5986 -DeploymentGroup app
Add-EnvironmentServer $production "test-ps2.cloudapp.net" -Port 51281 -DeploymentGroup web -Primary


# --------------------------------------------
#
#   Deploying tests
#
# --------------------------------------------

# perform deployment to staging
New-Deployment $myapp 1.0.0 -To $staging -Serial

# remove deployment
Remove-Deployment $myapp -From $staging

# rollback deployment
Restore-Deployment $myapp -On $staging

# restart deployment
Restart-Deployment $myapp -On $staging

# stop deployment
Stop-Deployment $myapp -On $staging

# start deployment
Start-Deployment $myapp -On $staging

<#
Events:
    deploy
    rollback
    remove
#>

Remove-Module AppRoller