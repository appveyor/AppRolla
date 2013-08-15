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
    -WebsiteName "test deploy" `
    -WebsitePort 8333 `
    -PackageUrl (Get-AppVeyorPackageUrl $applicationName $applicationVersion "HelloAppVeyor.Web") `
    -BasePath "c:\websites\$applicationName"


# add service role
Add-ServiceRole $myapp -Name "MyAppService" -DeploymentGroup app `
    -PackageUrl (Get-AppVeyorPackageUrl $applicationName $applicationVersion "HelloAppVeyor.Service") `
    -Configuration @{
        "ConnectionString.Default" = "server=locahost;"
    }

# add custom deployment task
Set-DeploymentTask remove-from-lb -Before deploy,restart -Application $myApp.Name {
    Write-Log "CUSTOM TASK: Remove machine from load balancer"
}

Set-DeploymentTask add-to-lb -After deploy,restart -Application $myApp.Name {
    Write-Log "CUSTOM TASK: Add machine to load balancer"
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

$local = New-Environment local
Add-EnvironmentServer $local "localhost"

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
#New-Deployment myapp 1.0.0 -To staging -Verbose #-Serial
#New-Deployment myapp 1.0.1 -To staging -Verbose #-Serial
#New-Deployment myapp 1.0.2 -To staging -Verbose #-Serial
#New-Deployment myapp 1.0.3 -To staging -Verbose #-Serial

#New-Deployment myapp 1.0.0 -To local -Verbose -Serial

#Remove-Deployment myapp -From staging -Verbose -Serial

#Restore-Deployment myapp -On local
#Restore-Deployment myapp -On staging

#Remove-Deployment myapp -From staging
#Remove-Deployment $myapp -From $staging


#Restore-Deployment myapp -On staging -Verbose -Serial

#Restart-Deployment myapp -On staging -Serial -Verbose


#Stop-Deployment myapp -On local
#Stop-Deployment myapp -On staging
#Start-Deployment myapp -On local

Start-Deployment myapp -On staging

# start deployment
#Start-Deployment $myapp -On $staging

<#
Events:
    deploy
    rollback
    remove
#>

Remove-Module AppRoller