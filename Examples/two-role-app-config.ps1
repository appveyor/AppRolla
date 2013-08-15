# import AppRoller
Remove-Module AppRoller -ErrorAction SilentlyContinue
$currentPath = Split-Path $myinvocation.mycommand.path
Import-Module (Resolve-Path (Join-Path $currentPath  ..\AppRoller.psm1))

$applicationName = "test-web"
$applicationVersion = "1.0.7"

$secureData = Get-ItemProperty -Path "HKLM:SOFTWARE\AppRoller\Tests"
$adminUsername = $secureData.adminUsername
$adminPassword = $secureData.adminPassword

$securePassword = ConvertTo-SecureString $adminPassword -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential $adminUsername, $securePassword

# set global deployment configuration
Set-DeploymentConfiguration TaskExecutionTimeout 60 # 1 min

#Set-DeploymentConfiguration UseSSL $false
#Set-DeploymentConfiguration SkipCACheck $false
#Set-DeploymentConfiguration SkipCNCheck $false

# AppVeyor API keys for downloading application artifacts
Set-DeploymentConfiguration AppveyorApiKey $secureData.appveyorApiKey
Set-DeploymentConfiguration AppveyorApiSecret $secureData.appveyorApiSecret


# --------------------------------------------
#
#   Configuring application and environments
#
# --------------------------------------------

# create new application
$myApp = New-Application MyApp -Configuration @{
    "key1" = "value1"
}

# add website role
Add-WebSiteRole $myapp -Name "MyAppWebsite" -DeploymentGroup web `
    -PackageUrl (Get-AppVeyorPackageUrl $applicationName $applicationVersion "HelloAppVeyor.Web") `
    -BasePath "c:\websites\$applicationName"


# add service role
Add-ServiceRole $myapp -Name "MyAppService" -DeploymentGroup app `
    -PackageUrl (Get-AppVeyorPackageUrl $applicationName $applicationVersion "HelloAppVeyor.Service") `
    -Configuration @{
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
$staging = New-Environment -Name Staging -Configuration @{
    var1 = "value1"
    var2 = "value2"
}
Add-EnvironmentServer $staging "test-ps2.cloudapp.net" -Port 51281 -DeploymentGroup web,app
Add-EnvironmentServer $staging "test-ps1.cloudapp.net" -DeploymentGroup app
Add-EnvironmentServer $staging "test-ps3.cloudapp.net" -DeploymentGroup app

#$staging = New-Environment -File (Join-Path $currentPath staging.json) -Credential $credential

# --------------------------------------------
#
#   Deploying tests
#
# --------------------------------------------

Set-DeploymentTask setup:env -Requires setup:web,setup:app -PerGroup -DeploymentGroup app {
    Write-Log "Setup environment for the first time: $($env:COMPUTERNAME)"

    $a = 42
    function Test()
    {
        Write-Log "Test!!!!"
    }

    $context.ServerDeploymentGroup

    Invoke-DeploymentTask setup:web
}

Set-DeploymentTask setup:web {
    Write-Log "Setup web group only"
    Test
    $a
}

#Invoke-DeploymentTask setup:env -On staging -Verbose

# perform deployment to staging
New-Deployment myapp 1.0.0 -To staging -Verbose #-Serial

# remove deployment
#Remove-Deployment $myapp -From $staging

# rollback deployment
#Restore-Deployment $myapp -On $staging

# restart deployment
#Restart-Deployment $myapp -On $staging -Verbose

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