# import AppRoller module
Remove-Module AppRolla -ErrorAction SilentlyContinue
$path = Split-Path -Parent $MyInvocation.MyCommand.Definition
Import-Module (Join-Path $path AppRolla.psm1)

# add application and roles
New-Application MyApp

Add-WebSiteRole MyApp MyWebsite -DeploymentGroup web `
    -PackageUrl "http://my-storage.com/website-package.zip"

Add-ServiceRole MyApp MyService -DeploymentGroup app `
    -PackageUrl "http://my-storage.com/service-package.zip"

# define Staging environment
New-Environment Staging
Add-EnvironmentServer Staging "staging.server.com"

# define Production environment
New-Environment Production
Add-EnvironmentServer Production "web.server.com" -DeploymentGroup web
Add-EnvironmentServer Production "app.server.com" -DeploymentGroup app