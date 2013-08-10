# import AppRoller
$currentPath = Split-Path $myinvocation.mycommand.path
Import-Module (Resolve-Path (Join-Path $currentPath  ..\AppRoller.psm1))

# create new application
$myApp = New-Application MyApp

# add website role
Add-WebsiteRole $myapp -Name web -PackageUrl http://www.mysite.com/web-package.zip

# add service role
Add-ServiceRole $myapp -Name app -PackageUrl http://www.mysite.com/service-package.zip

# add custom deployment task
Add-DeploymentTask $myapp -Role web -BeforeDeploy -Version 1.0.0 {
	# do something REMOTELY on "primary" node of "web" role before deployment
	# this could be used for setting up load balancer or running SQL scripts, i.e. anything that must be run once for all role nodes
}

Add-DeploymentTask $myapp -BeforeDeploy {
	# do something LOCALLY before deployment of the entire application
    Write-Output "Hello 1"
}

Add-DeploymentTask $myapp -Node web -AfterRollback -Version 1.2.0 {
	# do something REMOTELY on EACH node of "web" role after successful rollback from 1.2.0 version
    Write-Output "Hello 2"
}

$myApp

# describe Staging environment
$staging = New-Environment Staging -Default
Add-EnvironmentServer $staging "test-web1.cloudapp.net"

# describe Production environment
$production = New-Environment Production
Add-EnvironmentServer $production "prod-web1.cloudapp.net" -Roles web,app -Primary
Add-EnvironmentServer $production "prod-web2.cloudapp.net" -Roles web

# set global deployment configuration
Set-DeploymentConfig applicationsFolder "$($env:SystemDrive)\applications"

# perform deployment to staging
New-Deployment $myapp 1.0.0 -To $staging -Serial

# remove deployment
Remove-Deployment $myapp -From $staging

# rollback deployment
Restore-Deployment $myapp -On $staging

# restart deployment
Restart-Deployment $myapp -On $staging

<#
Application events:
	-BeforeDeploy
	-AfterDeploy
	-BeforeRemove
	-AfterRemove
	-BeforeRollback
	-AfterRollback

Role events:
	-BeforeDeploy
	-AfterDeploy
	-BeforeRemove
	-AfterRemove
	-BeforeRollback
	-AfterRollback
	
	-BeforeNodeDeploy
	-AfterNodeDeploy
	-BeforeNodeRemove
	-AfterNodeRemove
	-BeforeNodeRollback
	-AfterNodeRollback
#>

Remove-Module AppRoller