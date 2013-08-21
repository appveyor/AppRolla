# AppRolla

AppRolla is extensible framework for automating deployment of distributed .NET applications to multi-server environments.

AppRolla can be used as utility for executing commands in parallel on multiple machines via remote PowerShell. Tasks can be implemented in PowerShell and then applied to machines in certain roles.

AppRolla was inspired by Capistrano - a super popular deployment framework from Linux world. Though initial motivation to build AppRolla was having easy to use deployment framework as part of [AppVeyor Continuous Integration](http://www.appveyor.com) pipeline after starting the project it became clear AppRolla could be used in any build automation script or interactively from command line.


### Example
The script below performs the deployment of sample project consisting of **ASP.NET web application** (front-end) and **Windows service** (back-end) to "staging" environment with one server and then to "production" environment with 2 web (front-end) servers and 2 application (back-end) servers:

```posh
Import-Module AppRolla

# describe application
New-Application MyApp
Add-WebsiteRole MyApp MyWebsite -PackageUrl "http://www.site.com/packages/myapp.web.zip"
Add-ServiceRole MyApp MyService -PackageUrl "http://www.site.com/packages/myapp.service.zip"

# Staging environment
New-Environment Staging
Add-EnvironmentServer Staging staging-server

# Production environment
New-Environment Production
Add-EnvironmentServer Production web1.hostname.com -DeploymentGroup web
Add-EnvironmentServer Production web2.hostname.com -DeploymentGroup web
Add-EnvironmentServer Production app1.hostname.com -DeploymentGroup app
Add-EnvironmentServer Production app2.hostname.com -DeploymentGroup app

# custom task to setup database
Set-DeploymentTask setup-db -Before deploy -DeploymentGroup app -PerGroup {
   # database setup code goes here
}

# deploy to Staging
New-Deployment MyApp 1.0.0 -To Staging

# deploy to Production
New-Deployment MyApp 1.0.0 -To Production
```

### Features and benefits

- Deploys distributed applications to multi-server environments in parallel or server-by-server.
- Compact module without external dependencies - just a single `AppRolla.psm1` file.
- Provides natural PowerShell cmdlets with valid verbs, intuitive syntax and validation. We do not trying to mimic Capistrano, Chef or Puppet.
- Can deploy to local machine for testing/development.
- Easily extendable by writing your own custom tasks.
- Open-source under Apache 2.0 license - easy to adopt and modify without the fear to be locked-in.


### Assumptions

- AppRolla does not build application. It must be pre-built, pre-published (if it's web application project) and zipped. Use [AppVeyor](http://www.appveyor.com) to build your application and store artifacts in a cloud.
- AppRolla does not upload or push application packages to remote machines. Packages must be uploaded to any external location accessible from remote servers.
- AppRolla uses remote PowerShell. No agent installation required. We prepared [complete guide on how to setup PowerShell remoting](https://github.com/AppVeyor/AppRolla/wiki/Configuring-Windows-PowerShell-remoting).
- AppRolla is a *deployment* solution, not a *release management* with deployment workflow and security. Though AppRolla can rollback, remove and restart deployments it is basically “point and shoot” tool.


### Installing AppRolla

Download [`AppRolla.psm1`](https://raw.github.com/AppVeyor/AppRolla/master/AppRolla.psm1) file to `deployment` directory inside your project repository folder.

If you want to install AppRolla globally for your account create new `AppRolla` folder inside `$Home\Documents\WindowsPowerShell\Modules` and put `AppRolla.psm1` into it, or just run this script in PowerShel console:

```posh
$path = "$home\Documents\WindowsPowerShell\Modules\AppRolla"
New-Item $path -ItemType Directory -Force | Out-Null
(New-Object Net.WebClient).DownloadFile("https://raw.github.com/AppVeyor/AppRolla/master/AppRolla.psm1", "$path\AppRolla.psm1")
```

Inside `deployment` directory create a new "configuration" script named [`config.ps1`](https://github.com/AppVeyor/AppRolla/blob/master/config.ps1) where you describe your application and environments. You can use this template for your own config:

```posh
# import AppRolla module
Remove-Module AppRolla -ErrorAction SilentlyContinue
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
Import-Module (Join-Path $scriptPath AppRolla.psm1)

# use this snippet to import AppRolla module if it was installed globally
# Import-Module AppRolla

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
```

Now, if want to use AppRolla interactively just open PowerShell console in `deployment` directory and load configuration:

```posh
PS> .\config.ps1
```

`config.ps1` script will load AppRolla module and add application and environments to the current session.

Now you can just run AppRolla cmdlets from PowerShell command line, for example:

```posh
PS> New-Deployment MyApp 1.0.0 -To Staging
```

If you are going to use AppRolla in your continuous integration environment add [`deploy.ps1`](https://github.com/AppVeyor/AppRolla/blob/master/deploy.ps1) script performing application deployment and using configuration from `config.ps1`:

```posh
# load configuration script
$path = Split-Path -Parent $MyInvocation.MyCommand.Definition
. (Join-Path $path config.ps1)

# deploy to Staging
New-Deployment MyApp 1.0.0 -To Staging
```

### Using AppRolla

#### Describe your applications

AppRolla deploys *applications*. Application is a logical group of roles that are deployed/manipulated as a single entity under the same version. You can think application is VS.NET solution and role is VS.NET project.

Out-of-the-box AppRolla supports two types of roles:

* **WebSite** role - this is IIS web site
* **Service** role - Windows service

Application should have at least one role defined, for example website role if you are going to deploy your ASP.NET application.

Each role should have a corresponding package with application files. Package is just a zip with ASP.NET application or Windows service files - nothing more. Packages should be available for download from remote environment machines. When you build your project with [AppVeyor CI](http://www.appveyor.com) package is an artifact.

To add a new application:

```posh
New-Application MyApp
```

To add website role to the application:

```posh
Add-WebsiteRole MyApp MyWebsite -PackageUrl "http://www.site.com/packages/myapp.web.zip"
```	

Be default, website role is deployed to "Defaul Web Site" which is cool if you plan to have only one web application running on the target server. However, if you need to create a new IIS web site you can specify its details when adding role:

```posh
Add-WebsiteRole MyApp MyWebsite `
	  -PackageUrl "http://www.site.com/packages/myapp.web.zip"
	  -WebsiteName "MyWebsite" `
	  -WebsiteProtocol http `
	  -WebsiteHost www.mywebsite.com
	  -WebsitePort 8088
	  -WebsiteIP *
```

To add service role:

```posh
Add-ServiceRole MyApp MyService -PackageUrl "http://www.site.com/packages/myapp.service.zip"
```

By default, a Windows service will use the first .exe file found in the package, have service name and service display name equal to the role name ("MyService" in our case). If you have more than one .exe in the package or want to customize Windows service details you can use extended `Add-ServiceRole` syntax:

```posh
Add-ServiceRole MyApp MyService `
	  -PackageUrl "http://www.site.com/packages/myapp.service.zip"
	  -ServiceExecutable "myservice.exe" `
	  -ServiceName "myapp.myservice" `
	  -ServiceDisplayName "My app service"
	  -ServiceDescription "The service for hosting WCF back-end of my application."
```

#### Describe your environments

Application is deployed to *environment*. Environment has a name and could include one or more *servers* with remote PowerShell configured.

To add a new "staging: environment with two web servers and one application server:

```posh
New-Environment Staging
Add-EnvironmentServer Staging web1.hostname.com -DeploymentGroup web
Add-EnvironmentServer Staging web2.hostname.com -DeploymentGroup web
Add-EnvironmentServer Staging app1.hostname.com -DeploymentGroup app
```


##### What is deployment group?

If you have a complex application with several roles that you want to deploy to a multi-server environment how would you tell AppRolla to deploy certain application roles to specific servers? You could use `DeploymentGroup` parameter that could be specified for application roles and environment servers.

For example, we have an application consisting of web application and a Windows service and we want to deploy web application to IIS *web cluster* and Windows service to an application server.

First, we apply `DeploymentGroup` when adding website and service roles. Our example above could be extended as:

```posh
Add-WebsiteRole MyApp MyWebsite -DeploymentGroup web ...
Add-ServiceRole MyApp MyService -DeploymentGroup app ...
```

Application role could belong to zero or one deployment group only. If a role doesn't have deployment group specified it will be deployed to all servers. `DeploymentGroup` is an arbitrary string and you can use your own naming conventions.

Each environment server could belong to zero or many deployment groups. If server deployment group is not specified all application roles will be deployed to it. For example:

```posh
# this server accepts roles of "web" group only
Add-EnvironmentServer Staging web1.hostname.com -DeploymentGroup web

# this server accepts roles of "web" and "app" groups
Add-EnvironmentServer Staging srv1.hostname.com -DeploymentGroup web,app

# this server accepts roles of all groups
Add-EnvironmentServer Staging srv2.hostname.com
```


#### Deploying application

To deploy application to "staging" environment use the following command:

```posh
New-Deployment MyApp 1.0.0 -To Staging
```

This command will create a new "1.0.0" deployment of "MyApp" application on "Staging" environment servers. Website role will be deployed to `web1.hostname.com` and `web2.hostname.com` servers and service role to `app1.hostname.com`.

> We recommend using release version as a deployment name, however you can put any semantics into it.


##### Running deployment script server-by-server

By default, AppRolla deployment tasks are executed on all environment servers in parallel. However, in some cases you might want to run a script server-by-server. For example, you may have a custom task extension removing web node from load balancer before deployment and adding it back after it. To run deployment task server-by-server use `Serial` switch:

```posh
New-Deployment MyApp 1.0.0 -To Staging -Serial
```


##### Deployment directory structure

Default base path for all application deployments is `<system_drive>:\applications` where `<system_drive>` is a system drvie on remote server.

Each application role deployment creates a new directory on remote server:

    <base_path>\<application_name>\<role_name>\<deployment_name>

for example, deploying version 1.0.0 of our sample application with two roles to a single-server staging environment will create the following directory structure:

```posh
c:\applications\MyApp\
c:\applications\MyApp\MyWebsite
c:\applications\MyApp\MyWebsite\1.0.0
c:\applications\MyApp\MyService
c:\applications\MyApp\MyService\1.0.0
```

After deploying of another 1.0.1 version we will have this sctructure:

```posh
c:\applications\MyApp\
c:\applications\MyApp\MyWebsite
c:\applications\MyApp\MyWebsite\1.0.0
c:\applications\MyApp\MyWebsite\1.0.1   # "current" deployment
c:\applications\MyApp\MyService
c:\applications\MyApp\MyService\1.0.0
c:\applications\MyApp\MyService\1.0.1   # "current" deployment
```

Website root folder and Windows service executable path will be changed to a new path.

To change a base path for all deployments globally use this command:

```posh
Set-DeploymentConfiguration ApplicationsPath 'c:\myapps'
```

You can use environment variables in the path to be resolved on remote server. Path must be set in a **single quotes** then:

```posh
Set-DeploymentConfiguration ApplicationsPath '$($env:SystemDrive)\myapps'
```

To set a base path on role level use `BasePath` parameter when adding a role:

```posh
# to deploy website to c:\websites\<deployment_name> directory
Add-WebsiteRole MyApp MyWebsite -BasePath 'c:\websites' ...

# to deploy Windows service to Program Files directory
Add-ServiceRole MyApp MyService -BasePath '$($env:ProgramFiles)\MyService' ...
```

##### How to deploy locally?

AppRolla allows running deployment tasks locally. This is useful for development/testing purposes as well as for testing custom deployment tasks.

To deploy locally use built-in "local" environment:

```posh
New-Deployment MyApp 1.0.0 -To local
```

This environment has only one "localhost" server. If you need to deploy to local machine as part of your own environment (it's really hard to figure out a real use-case, but anyway :) add a server with reserved "localhost" name:

```posh
New-Environment Dev
...
Add-EnvironmentServer Dev localhost
```

##### How to update application configuration files?

AppRolla can update configuration settings in `appSettings` and `connectionString` sections on web.config and app.config files while deploying web applications and Windows services.

Specify configuration settings in the format `appSettings.<key>` or `connectionString.<name>` to update keys in corresponding sections while adding a role:

```posh
Add-WebsiteRole MyApp MyWebsite ... -Configuration {
  "appSettings.SiteUrl" = "http://www.mysite.com"
}

Add-ServiceRole MyApp MyWebsite ... -Configuration {
  "connectionString.Default" = "server=locahost; ..."
}
```

#### Rollback deployment

What if you did a mistake and accidentially deployed a broken release (it could never happen if you deploy as part of continuous integration process in [AppVeyor](http://www.appveyor.com) as only green builds are being deployed)?

You can rollback deployment to a previous release by this command:

```posh
Restore-Deployment MyApp -On Production
```

To rollback to a specific version:

```posh
Restore-Deployment MyApp 1.0.0 -On Production
```

By default, AppRolla stores 5 previous releases on remote servers, but you can change this number by modifying the following setting:

```posh
Set-DeploymentConfiguration KeepPreviousVersions 10
```

During the rollback AppRolla switches websites and Windows services to new directories and deletes current release directories.

#### Removing deployment

To delete specific (previous as you cannot delete current deployment) application deployment use the following command:

```posh
Remove-Deployment MyApp 1.0.0 -From Staging
```

To delete all application deployments ommit version parameter:

```posh
Remove-Deployment MyApp -From Staging
```

#### Start/Stop/Restart deployed application

When you start/stop/restart application on specific environment its role IIS website application pools or Windows services are started/stopped/restarted on all remote servers.

To stop application:

```posh
Stop-Deployment MyApp -On Staging
```

To start application:

```posh
Start-Deployment MyApp -On Staging
```

To restart application:

```posh
Restart-Deployment MyApp -On Staging
```


#### PowerShell remoting

AppRolla uses remote PowerShell to run deployment tasks on remote servers. By relying on remote PowerShell technology we are strongly commited to provide you all required information on how to get started saving you hours of crawling the internet and find the answers.

Read [complete guide on how to setup PowerShell remoting](https://github.com/AppVeyor/AppRolla/wiki/Configuring-Windows-PowerShell-remoting). In that article you will know how to issue correct SSL certificate that could be used to setup WinRM HTTPS listener, install SSL certificate on remote machine, enable remote PowerShell and configure firewall.

##### Configuring PowerShell remoting settings

By default, AppRolla will try to connect remote environment server via HTTPS on port 5986. To change default communication protocol to HTTP on port 5985 update this global setting:

```posh
Set-DeploymentConfiguration UseSSL $false
```

To set a custom port for each environment server use `-Port` parameter when adding a server:

```posh
Add-EnvironmentServer Staging web1.hostname.com -Port 51434 ...
```


##### Authenticating remote PowerShell sessions

To connect remote server that is not a member of the same AD domain you should provide user account credentials (username/password). How to securely store those credentials and pass them to AppRolla?

When using AppRolla interactively from your development machine the best way to store servers credentials is **Windows Credential Manager**. You find Credential Manager by searching for "credential" in Control Panel. You should add **Windows credentials** for each server you are going to deploy to.

What if you are deploying to a very large environment with dozens of servers and want to use the same username/password to connect them. You can specify credentials for the entire environment using `-Credential` parameter when adding environment. For example, using the code below you will be asked to type "Administrator" account password every time you deploy:

```posh
$cred = Get-Credential -UserName Administrator
New-Environment Staging -Credential $cred
```

If you don't want to type a password every time you can store it in the registry and then create credentials object like that:

```posh
$secureData = Get-ItemProperty -Path "HKCU:SOFTWARE\AppRolla\Tests" # your path here
$adminUsername = $secureData.adminUsername  # your key here
$adminPassword = $secureData.adminPassword  # your key here
$securePassword = ConvertTo-SecureString $adminPassword -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential $adminUsername, $securePassword

New-Environment Staging -Credential $cred
```

Storing any settings in the registry will ensure you don't check-in sensitive information in source control and also allows every developer of your team to use their own settings.

You can also set credentials for each server individually:

```posh
New-Environment Staging
Add-EnvironmentServer Staging web1.hostname.com -Credential $cred ...
```


### Custom tasks

By implementing tasks you can extend existing functionality or add a completely new scenarios to AppRolla. Those tasks could be anything from putting application settings into registry, creating application database or setting permissions to excluding/including server from load balancing during the deployment.

#### Basic example

OK, let's say we want to do something *before* application deployment on each environment server. The task could look like:

```posh
Set-DeploymentTask mytask1 -Before deploy {
   # this code runs on every environment server BEFORE deployment
}
```

#### Extending existing tasks

You can add a custom action to run *before* or *after* any task.

AppRolla defines the following standard tasks:

* init
* deploy
 * authenticate-download-client
 * deploy-website
 * deploy-service
* remove
* rollback
* start
* stop
* restart

For example, to have a custom task doing something *after* deployment use `-After` parameter:

```posh
Set-DeploymentTask mytask2 -After deploy {
   # this code runs on every environment server AFTER deployment
}
```

You can combine both `-Before` and `-After` for the same task. Also, you can specify multiple dependent tasks, like that:

```posh
Set-DeploymentTask mytask3 -Before deploy -After deploy,rollback {
   # this code runs on every environment server BEFORE deployment and AFTER deployment or rollback
}
```

#### Applying task to specific deployment groups
To apply the task to specific deployment groups only use `-DeploymentGroup` parameter:

```posh
Set-DeploymentTask mytask4 -Before deploy -DeploymentGroup web {
   # this code runs on environment servers of 'web' group only BEFORE deployment
}
```

Sometimes, you have to execute some code once per group, for example to setup an application SQL Server database. Obviously, running database setup scripts on *every* server will cause racing condition and won't work. To run task once per group use `-PerGroup` parameter:

```posh
Set-DeploymentTask setup-db -Before deploy -DeploymentGroup web -PerGroup {
   # setup application database here
   # this code will run on a single server from 'web' deployment group
}
```

Oh, suppose we have to deploy an application to a load-balanced web cluster. Usually, we want to deploy node-by-node with removing a node from load balancing before deployment and adding it back when deployment is finished. How do we do that? Every *-Deployment cmdlet has `-Serial` switch to execute a task no in parallel, but server-by-server. To deploy to load balanced cluster you could use the following skeleton:

```posh
Set-DeploymentTask remove-from-lb -Before deploy -DeploymentGroup web {
   # code to remove current node from load balancer
}

Set-DeploymentTask add-to-lb -After deploy -DeploymentGroup web {
   # code to add current node to load balancer
}

New-Deployment MyApp 1.0.0 -To Production -Serial        # run script server-by-server
```


#### Applying task to a specific application

To define a task specific for some application or even version use `-Application` and `-Version` parameters:

```posh
Set-DeploymentTask myapp-specific-task -Before deploy -Application MyApp -Version 1.0.0 {
   # do something here
}
```

Another cool example - running some compensation code against application database while rolling back *from* version 1.1.0:

```posh
Set-DeploymentTask rollback-db -After rollback -Application MyApp -Version 1.1.0 -PerGroup {
   # this code will run only once per environment
   # when rolling back MyApp application from 1.1.0 version
}
```

### Custom tasks

You can define your own custom tasks and then apply them to machines in certain deployment groups.

Let's enjoy a greeting from every server in Staging environment:

```posh
Set-DeploymentTask hello {
   Write-Output "Hello from $($env:COMPUTERNAME)!"
}

Invoke-DeploymentTask hello -On Staging
```

To run the task on "web" servers only add `-DeploymentGroup`:

```posh
Set-DeploymentTask hello-from-web -DeploymentGroup web {
   Write-Output "Hello from $($env:COMPUTERNAME)!"
}
```

To run a task not in parallel use `-Serial` parameter:

```posh
Invoke-DeploymentTask hello -On Staging -Serial
```

#### Pushing configuration to remote servers

All tasks run in the same PowerShell scope. The following variables are pre-defined in the scope by AppRolla:

- `$context.Configuration` - hashtable with global configuration. To set global variables use `Set-DeploymentConfiguration` cmdlet.
- `$context.TaskName` - the name of currently executing task.
- `$context.Application` - the name of currently deploying application.
- `$context.Version` - currently deploying application version.
- `$context.Server.ServerAddress` - the host name of environment server running the script.
- `$context.Server.DeploymentGroup` - array of deployment groups assigned to the current server.
- `$context.Environment.Name` - the name of current environment
- `$context.Environment.Configuration` - hashtable of configuration variables defined on environment level.

To define configuration variables on environment level use `-Configuration` parameter:

```posh
New-Environment Staging -Configuration @{
  "variable1" = "value1"
  "variable2" = "value2"
  ...
}
```

To define configuration variables on role level use `-Configuration` parameter when adding a role:

```posh
Add-WebsiteRole MyApp MyWebsite ... -Configuration @{
  "variable1" = "value1"
  "appSettings.setting1" = "value2"
  "connectionStrings.Name" = "connection string details"
  ...
}
```

When extending standard `<deploy|rollback|remove|start|stop>-website` or `<deploy|rollback|remove|start|stop>-service` tasks `$role` variable is added to the scope with current role details:

- `$role.Type` - role type
- `$role.Name` - the name of role
- `$role.PackageUrl` - URL of role artifact package
- `$role.BasePath` - base path for role releases
- `$role.RootPath` - release installation installation root (application root)
- `$role.Versions` - the list of installed versions (latest first)



### License

[Apache 2.0](http://www.apache.org/licenses/LICENSE-2.0.html)



### How to contribute

Contributions are welcome! Submit a pull request or issue here on GitHub or just drop us a message at [team@appveyor.com](mailto:team@appveyor.com).



### Credits

* [Capistrano](https://github.com/capistrano/capistrano) for the basic idea on how cool deployment framework should look like.
* [Unfold](https://github.com/thomasvm/unfold) for the idea on how Capistrano-like deployment framework might look on Windows platform. Thanks Thomas, the author of Unfold, for super-clean and easy to read code - we got some code snippets and principles from Unfold.
