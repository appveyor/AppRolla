# setup context
$script:context = @{}
$currentContext = $script:context
$currentContext.applications = @{}
$currentContext.environments = @{}
$currentContext.defaultEnvironment = $null
$currentContext.tasks = @{}

function Set-DeploymentConfig
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position=0, Mandatory=$true)]
        $Name,

        [Parameter(Position=1, Mandatory=$true)]
        $Value
    )

    # todo
}

function New-Application
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position=0, Mandatory=$true)]
        $Name,

        [Parameter(Mandatory=$false)]
        $BasePath,

        [Parameter(Mandatory=$false)]
        $Variables = @{}
    )

    Write-Verbose "New-Application $Name"

    # verify if application already exists
    if($currentContext.applications[$Name] -ne $null)
    {
        throw "Application $Name already exists. Choose a different name."
    }

    # add new application
    $app = @{
        Name = $Name
        BasePath = $BasePath
        Variables = $Variables
        Roles = @{}
        DeploymentTasks = New-Object System.Collections.ArrayList
    }

    $currentContext.applications[$Name] = $app

    # output to pipeline
    $app
}

function Get-Application
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position=0, Mandatory=$true)]
        $Name
    )

    $app = $currentContext.applications[$Name]
    if($app -ne $null)
    {
        throw "Application $Name not found."
    }
}


function Add-WebSiteRole
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
        $Application,

        [Parameter(Mandatory=$true)]
        [string]$Name,

        [Parameter(Mandatory=$false)]
        [string]$DeploymentGroup,

        [Parameter(Mandatory=$true)]
        [string]$PackageUrl,

        [Parameter(Mandatory=$false)]
        [string]$BasePath = $null,

        [Parameter(Mandatory=$false)]
        [string]$WebsiteName = $null,

        [Parameter(Mandatory=$false)]
        [string]$WebsiteProtocol = $null,

        [Parameter(Mandatory=$false)]
        [string]$WebsiteIP = $null,

        [Parameter(Mandatory=$false)]
        [int]$WebsitePort = $null,

        [Parameter(Mandatory=$false)]
        [string]$WebsiteHost = $null,

        [Parameter(Mandatory=$false)]
        $Variables = @{}
    )

    Write-Verbose "Add-WebsiteRole"

    # verify if the role with such name exists
    $role = $Application.Roles[$Name]
    if($role -ne $null)
    {
        throw "Application $($Application.Name) has already $Name role configured. Choose a different role name."
    }

    # add role info to the application config
    $role = @{
        Name = $Name
        DeploymentGroup = ValueOrDefault $DeploymentGroup "web"
        PackageUrl = $PackageUrl
        BasePath = $BasePath
        WebsiteName = ValueOrDefault $WebsiteName "Default Web Site"
        WebsiteProtocol = ValueOrDefault $WebsiteProtocol "http"
        WebsiteIP = ValueOrDefault $WebsiteIP "*"
        WebsitePort = ValueOrDefault $WebsitePort 80
        WebsiteHost = $WebsiteHost
        Variables = $Variables
    }
    $Application.Roles[$Name] = $role
}

function Add-ServiceRole
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
        $Application,

        [Parameter(Mandatory=$true)]
        $Name,

        [Parameter(Mandatory=$false)]
        $DeploymentGroup,

        [Parameter(Mandatory=$true)]
        $PackageUrl,

        [Parameter(Mandatory=$false)]
        [string]$BasePath,

        [Parameter(Mandatory=$false)]
        [string]$ServiceName = $null,

        [Parameter(Mandatory=$false)]
        [string]$ServiceDisplayName = $null,

        [Parameter(Mandatory=$false)]
        [string]$ServiceDescription = $null,

        [Parameter(Mandatory=$false)]
        $Variables = @{}
    )

    Write-Verbose "Add-ServiceRole"

    # verify if the role with such name exists
    $role = $Application.Roles[$Name]
    if($role -ne $null)
    {
        throw "Application $($Application.Name) has already $Name role configured. Choose a different role name."
    }

    # add role info to the application config
    $role = @{
        Name = $Name
        DeploymentGroup = ValueOrDefault $DeploymentGroup "app"
        PackageUrl = $PackageUrl
        BasePath = $BasePath
        ServiceName = ValueOrDefault $ServiceName $Name
        ServiceDisplayName = ValueOrDefault $ServiceDisplayName $Name
        ServiceDescription = $ServiceDescription
        Variables = $Variables
    }
    $Application.Roles[$Name] = $role
}


function New-DeploymentTask
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position=0, Mandatory=$true)]
        $Name,

        [Parameter(Position=1, Mandatory=$true)]
        [scriptblock]$Script,

        [Parameter(Mandatory=$false)]
        $Before = $null,
        
        [Parameter(Mandatory=$false)]
        $After = $null,

        [Parameter(Mandatory=$false)]
        $Application,
        
        [Parameter(Mandatory=$false)]
        $Version = $null,

        [Parameter(Mandatory=$false)]
        [string[]]$DeploymentGroup = $null,

        [Parameter(Mandatory=$false)]
        [string[]]$DeploymentGroupServer = $null
    )

    Write-Verbose "New-DeploymentTask"

    # verify if task already exists
    if($currentContext.tasks[$Name] -ne $null)
    {
        throw "Deployment task $Name already exists. Choose a different name."
    }

    # verify parameters
    if($Before -eq $null -and $After -eq $null)
    {
        throw "Either -Before or -After should be specified."
    }

    # create new deployment task object
    $task = @{
        Name = $Name
        Script = $Script
        BeforeTasks = New-Object System.Collections.ArrayList
        AfterTasks = New-Object System.Collections.ArrayList
        Application = $Application
        Version = $Version
        DeploymentGroup = $DeploymentGroup
        DeploymentGroupServer = $DeploymentGroupServer
    }

    # add task
    $currentContext.tasks[$Name] = $task

    # bind task to others
    if($Before -ne $null)
    {
        $beforeTask = $currentContext.tasks[$Before]
        if($beforeTask -ne $null)
        {
            $beforeTask.BeforeTasks.Add($task) > $null
        }
    }

    if($After -ne $null)
    {
        $afterTask = $currentContext.tasks[$After]
        if($afterTask -ne $null)
        {
            $afterTask.AfterTasks.Add($task) > $null
        }
    }
}


function New-Environment
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position=0, Mandatory=$true)]
        $Name,

        [Parameter(Mandatory=$false)]
        [PSCredential]$Credential,

        [Parameter(Mandatory=$false)]
        [switch]$Default = $false
    )

    Write-Verbose "New-Environment $Name"

    # verify if environment already exists
    if($currentContext.environments[$Name] -ne $null)
    {
        throw "Environment $Name already exists. Choose a different name."
    }

    # add new environment
    $environment = @{
        Name = $Name
        Credential = $Credential
        Servers = @{}
    }

    $currentContext.environments[$Name] = $environment

    # set default environment
    if($Default)
    {
        $currentContext.defaultEnvironment = $environment
    }

    # output to pipeline
    $environment
}


function Add-EnvironmentServer
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
        $Environment,

        [Parameter(Position=1, Mandatory=$true)]
        [string]$ServerAddress,

        [Parameter(Mandatory=$false)]
        [int]$Port,

        [Parameter(Mandatory=$false)]
        [string[]]$DeploymentGroup = $null,
        
        [Parameter(Mandatory=$false)]
        [switch]$Primary = $false,

        [Parameter(Mandatory=$false)]
        [PSCredential]$Credential = $null
    )

    Write-Verbose "Add-EnvironmentServer $ServerAddress"

    # verify if the server with specified address exists
    $server = $Environment.Servers[$ServerAddress]
    if($server -ne $null)
    {
        throw "Environment $($Environment.Name) has already $ServerAddress server added."
    }

    # add role info to the application config
    $server = @{
        ServerAddress = $ServerAddress
        Port = ValueOrDefault $Port 5986
        DeploymentGroup = $DeploymentGroup
        Credential = ValueOrDefault $Credential $Environment.Credential
    }
    $Environment.Servers[$ServerAddress] = $server
}

function New-Deployment
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
        $Application,

        [Parameter(Position=1, Mandatory=$true)]
        $Version,

        [Parameter(Position=2, Mandatory=$false)][alias("To")]
        $Environment,

        [Parameter(Mandatory=$false)]
        [switch]$Serial = $false
    )

    Write-Output "Deploying application $($Application.name) $Version to $($Environment.name)"
}

function Remove-Deployment
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
        $Application,

        [Parameter(Position=1, Mandatory=$false)]
        $Version,

        [Parameter(Mandatory=$false)][alias("From")]
        $Environment,

        [Parameter(Mandatory=$false)]
        [switch]$Serial = $false
    )

    Write-Output "Removing application $($Application.name) $Version from $($Environment.name)"
}

function Restore-Deployment
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
        $Application,

        [Parameter(Position=1, Mandatory=$false)][alias("On")]
        $Environment,

        [Parameter(Mandatory=$false)]
        $Version,

        [Parameter(Mandatory=$false)]
        [switch]$Serial = $false
    )

    Write-Output "Restore application $($Application.name) on $($Environment.name)"
}

function Restart-Deployment
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
        $Application,

        [Parameter(Position=1, Mandatory=$false)][alias("On")]
        $Environment,

        [Parameter(Mandatory=$false)]
        [switch]$Serial = $false
    )

    Write-Output "Restart application $($Application.name) on $($Environment.name)"
}

function Stop-Deployment
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
        $Application,

        [Parameter(Position=1, Mandatory=$false)][alias("On")]
        $Environment,

        [Parameter(Mandatory=$false)]
        [switch]$Serial = $false
    )

    Write-Output "Stopping application $($Application.name) on $($Environment.name)"
}

function Start-Deployment
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
        $Application,

        [Parameter(Position=1, Mandatory=$false)][alias("On")]
        $Environment,

        [Parameter(Mandatory=$false)]
        [switch]$Serial = $false
    )

    Write-Output "Starting application $($Application.name) on $($Environment.name)"
}

function ValueOrDefault($value, $default)
{
    If($value)
    {
        return $value
    }
    return $default
}

function AddStandardTask($taskName)
{
    $currentContext.tasks[$taskName] = @{
        Name = $taskName
        BeforeTasks = New-Object System.Collections.ArrayList
        AfterTasks = New-Object System.Collections.ArrayList
    }
}

# add standard tasks
AddStandardTask "deploy"
AddStandardTask "remove"
AddStandardTask "rollback"

Export-ModuleMember -Function `
    New-Application, Add-WebSiteRole, Add-ServiceRole, New-DeploymentTask, `
    New-Environment, Add-EnvironmentServer, `
    New-Deployment, Remove-Deployment, Restore-Deployment, Restart-Deployment, Stop-Deployment, Start-Deployment