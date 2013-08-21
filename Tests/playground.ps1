# import AppRoller
Remove-Module AppRolla -ErrorAction SilentlyContinue
$currentPath = Split-Path $myinvocation.mycommand.path
Import-Module (Resolve-Path (Join-Path $currentPath  ..\AppRolla.psm1))

$applicationName = "test-web"
$applicationVersion = "1.0.7"

$secureData = Get-ItemProperty -Path "HKCU:SOFTWARE\AppRolla\Tests"
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

function Get-AppVeyorPackageUrl
{
    param (
        $applicationName,
        $applicationVersion,
        $artifactName
    )

    return "https://ci.appveyor.com/api/projects/artifact?projectName=$applicationName`&versionName=$applicationVersion`&artifactName=$artifactName"
}

# add application
New-Application MyApp -Configuration @{
    "key1" = "value1"
}

# add "Web site" role
Add-WebSiteRole MyApp MyWebsite -DeploymentGroup web `
    -WebsiteName "test deploy" `
    -WebsitePort 8333 `
    -PackageUrl (Get-AppVeyorPackageUrl $applicationName $applicationVersion "HelloAppVeyor.Web") `
    -BasePath '$($env:SystemDrive)\websites\test-web'

# add "Windows service" role
Add-ServiceRole MyApp MyService -DeploymentGroup app `
    -PackageUrl (Get-AppVeyorPackageUrl $applicationName $applicationVersion "HelloAppVeyor.Service") `
    -Configuration @{
        "ConnectionString.Default" = "server=locahost;"
    }

# add Staging environment
New-Environment Staging -Configuration @{
    var1 = "value1"
    var2 = "value2"
}

# add environment servers
Add-EnvironmentServer Staging test-ps2.cloudapp.net -Port 51281 -DeploymentGroup web,app
Add-EnvironmentServer Staging test-ps1.cloudapp.net -DeploymentGroup app
Add-EnvironmentServer Staging test-ps3.cloudapp.net -DeploymentGroup app

# setup custom deployment tasks
Set-DeploymentTask remove-from-lb -Before deploy,restart -Application $myApp.Name {
    Write-Log "CUSTOM TASK: Remove machine from load balancer"
}

Set-DeploymentTask add-to-lb -After deploy,restart -Application $myApp.Name {
    Write-Log "CUSTOM TASK: Add machine to load balancer"
}

Set-DeploymentTask task3 -After rollback -Application $applicationName -Version 1.2.0 -DeploymentGroup web {
    Write-Log "task3: do something on EACH node of web deployment group after successful rollback from 1.2.0"
}


# custom task to setup database
Set-DeploymentTask setup-db -Before deploy,remove -DeploymentGroup app -PerGroup {
   # database setup code goes here
   Write-Log "Setup database on $($context.Environment.Name)!"
}

Set-DeploymentTask hello -DeploymentGroup web,app {
    Write-Output "Hello from $($env:COMPUTERNAME)!"
}

#Invoke-DeploymentTask hello -On staging -Serial -Verbose

# perform deployment to staging
#New-Deployment myapp 1.0.0 -To staging -Verbose #-Serial
#New-Deployment myapp 1.0.1 -To staging -Verbose #-Serial
New-Deployment myapp 1.0.2 -To staging -Verbose #-Serial
#New-Deployment myapp 1.0.4 -To staging -Verbose #-Serial

#New-Deployment myapp 1.0.0 -To local -Verbose -Serial

#Remove-Deployment myapp -From staging -Verbose -Serial
#Remove-Deployment myapp -From local -Verbose

#Restore-Deployment myapp -On local
#Restore-Deployment myapp -On staging

#Remove-Deployment myapp -From staging


#Restore-Deployment myapp -On staging -Verbose -Serial

#Restart-Deployment myapp -On staging -Serial -Verbose

#Get-DeploymentConfiguration UseSSL

#Stop-Deployment myapp -On local
#Stop-Deployment myapp -On staging
#Start-Deployment myapp -On local

#Start-Deployment myapp -On staging -Verbose

# start deployment
#Start-Deployment $myapp -On $staging

Remove-Module AppRolla