# import AppRoller
$currentPath = Split-Path $myinvocation.mycommand.path
Import-Module "$currentPath\AppRoller.psm1"

# create new application
$myApp = New-Application MyApp

# add website role
Add-WebsiteRole $myapp -Name web -PackageUrl http://www.mysite.com/web-package.zip

# add service role
Add-ServiceRole $myapp -Name app -PackageUrl http://www.mysite.com/service-package.zip

# add custom deployment task
Add-DeploymentTask $myapp -BeforeDeploy -Role web -Version 1.0.0 {
	# do something on "primary" node of "web" role before deployment
	# this could be used for setting up load balancer or running SQL scripts, i.e. anything that must be run once for all role nodes
}

Add-DeploymentTask $myapp -BeforeDeploy {
	# do something LOCALLY before deployment of the entire application
    Write-Output "Hello 1"
}

Add-DeploymentTask $myapp -AfterRollback -Node web -Version 1.2.0 {
	# do something on EACH node of "web" role after successful rollback from 1.2.0 version
    Write-Output "Hello 2"
}

Add-DeploymentTask $myapp -Role web -AfterRollback -Version 1.2.0 {
    
}

$myApp

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