# config
$config = @{}
$config.taskExecutionTimeout = 300 # 5 min

# context
$script:context = @{}
$currentContext = $script:context
$currentContext.applications = @{}
$currentContext.environments = @{}
$currentContext.defaultEnvironment = $null
$currentContext.tasks = @{}
$currentContext.remoteSessions = @{}

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

    $config[$Name] = $Value
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
    if($app -eq $null)
    {
        throw "Application $Name not found."
    }
    return $app
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
        $Application = $null,
        
        [Parameter(Mandatory=$false)]
        $Version = $null,

        [Parameter(Mandatory=$false)]
        [string[]]$DeploymentGroup = $null,

        [Parameter(Mandatory=$false)]
        [switch]$PerGroup = $false
    )

    Write-Verbose "New-DeploymentTask"

    # verify if task already exists
    if($currentContext.tasks[$Name] -ne $null)
    {
        throw "Deployment task $Name already exists. Choose a different name."
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
        PerGroup = $PerGroup
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
        else
        {
            throw "Wrong before task: $Before"
        }
    }

    if($After -ne $null)
    {
        $afterTask = $currentContext.tasks[$After]
        if($afterTask -ne $null)
        {
            $afterTask.AfterTasks.Add($task) > $null
        }
        else
        {
            throw "Wrong after task: $After"
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

function Get-Environment
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position=0, Mandatory=$true)]
        $Name
    )

    $environment = $currentContext.environments[$Name]
    if($environment -eq $null)
    {
        throw "Environment $Name not found."
    }
    return $environment
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

    Invoke-RemoteTask deploy $application $version $environment $serial
}

function Invoke-RemoteTask
{
    param
    (
        [Parameter(Position=0, Mandatory=$false)]
        [string]$taskName,
        
        [Parameter(Position=1, Mandatory=$false)]
        $application,
        
        [Parameter(Position=2, Mandatory=$false)]
        [string]$version,
        
        [Parameter(Position=3, Mandatory=$false)]
        $environment,
        
        [Parameter(Position=4, Mandatory=$false)]
        [switch]$serial = $false
    )

    if($application -is [string])
    {
        $application = Get-Application $Application
    }

    if($environment -is [string])
    {
        $environment = Get-Environment $environment
    }

    Write-Verbose "Running `"$taskName`" task for application $($application.Name) version $version on `"$($environment.Name)` environment"

    # build remote task context
    $taskContext = @{
        TaskName = $taskName
        Application = $Application
        Version = $Version
        Environment = $Environment
        ServerScripts = @{}
        Serial = $Serial
    }

    # add init task scripts
    $initTask = $currentContext.tasks["init"]
    Add-BeforeTasks $taskContext $initTask.BeforeTasks
    Add-TaskScriptToServers $taskContext $initTask
    Add-AfterTasks $taskContext $initTask.AfterTasks

    # add main task
    $task = $currentContext.tasks[$taskName]

    # change task deployment group to application roles union
    $task.DeploymentGroup = @(0) * $taskContext.Application.Roles.count
    $i = 0
    foreach($role in $taskContext.Application.Roles.values)
    {
        $task.DeploymentGroup[$i++] = $role.DeploymentGroup
    }

    # add before tasks recursively
    Add-BeforeTasks $taskContext $task.BeforeTasks

    # add task itself
    Add-TaskScriptToServers $taskContext $task

    # add after tasks recursively
    Add-AfterTasks $taskContext $task.AfterTasks

    if($taskContext.ServerScripts.count -eq 0)
    {
        throw "No servers will be affected by `"$taskName`" command."
    }

    # run scripts on each server
    $jobs = @(0) * $taskContext.ServerScripts.count
    $jobCount = 0
    foreach($serverAddress in $taskContext.ServerScripts.keys)
    {
        Write-Verbose "Run script on $($serverAddress) server"

        # get server remote session
        $server = $taskContext.Environment.Servers[$serverAddress]
        $credential = $server.Credential
        if($credential -eq $null)
        {
            $credential = $taskContext.Environment.Credential
        }
        $session = Get-RemoteSession -serverAddress $server.ServerAddress -port $server.Port -credential $credential

        # server sequence to run
        $script = $taskContext.ServerScripts[$serverAddress]

        $remoteScript = {
            param (
                $taskName,
                $application,
                $version,
                $deploymentGroup,
                $script
            )

            # run script parts one-by-one
            foreach($scriptBlock in $script)
            {
                $sb = $ExecutionContext.InvokeCommand.NewScriptBlock($scriptBlock)
                .$sb
            }
        }

        if($taskContext.Serial)
        {
            # run script on remote server synchronously
            Invoke-Command -Session $session -ScriptBlock $remoteScript -ArgumentList `
                $taskContext.TaskName,`
                $taskContext.Application,`
                $taskContext.Version,`
                $server.DeploymentGroup,`
                (,$script)
        }
        else
        {
            # run script on remote server as a job
            $jobs[$jobCount++] = Invoke-Command -Session $session -ScriptBlock $remoteScript -AsJob -ArgumentList `
                $taskContext.TaskName,`
                $taskContext.Application,`
                $taskContext.Version,`
                $server.DeploymentGroup,`
                (,$script)
        }
    }

    # wait jobs
    if(-not $taskContext.Serial)
    {
        Wait-Job -Job $jobs -Timeout $config.taskExecutionTimeout > $null

        # get results
        for($i = 0; $i -lt $jobCount; $i++)
        {
            Receive-Job -Job $jobs[$i]
        }
    }

    # close remote sessions
    Remove-RemoteSessions
}

function Add-TaskScriptToServers($taskContext, $task)
{
    # filter by application name and version
    if($task.Application -ne $null -and $task.Application -ne $taskContext.Application.Name)
    {
        # task application name is specified but does not match
        return
    }
    else
    {
        # OK, application name does match, check version now if specified
        if($task.Version -ne $null -and $task.Version -ne $taskContext.Version)
        {
            # version is specified but does not match
            Write-Output "App version does not match!!!!"
            return
        }
    }

    # iterate through all environment servers and see if the task applies
    foreach($server in $taskContext.Environment.Servers.values)
    {
        $applied = $false
        if($task.DeploymentGroup -eq $null -or $server.DeploymentGroup -eq $null)
        {
            # task is applied to all groups
            $applied = $true
        }
        else
        {
            # find intersection of two arrays of DeploymentGroup
            $commonGroups = $task.DeploymentGroup | ?{$server.DeploymentGroup -contains $_}

            if($commonGroups.length -gt 0)
            {
                $applied = $true
            }
        }

        if($applied)
        {
            # add task script to the array of server scripts
            $serverScripts = $taskContext.ServerScripts[$server.ServerAddress]
            if($serverScripts -eq $null)
            {
                $serverScripts = New-Object System.Collections.ArrayList
                $taskContext.ServerScripts[$server.ServerAddress] = $serverScripts
            }
            $serverScripts.Add($task.Script) > $null

            # is it per group task
            if($task.PerGroup)
            {
                break
            }
        }
    }
}

function Add-BeforeTasks($taskContext, $beforeTasks)
{
    foreach($task in $beforeTasks)
    {
        # add task before tasks
        Add-BeforeTasks $taskContext $task.BeforeTasks
        
        # add task itself
        Add-TaskScriptToServers $taskContext $task
    }
}

function Add-AfterTasks($taskContext, $afterTasks)
{
    foreach($task in $afterTasks)
    {
        # add task itself
        Add-TaskScriptToServers $taskContext $task
                
        # add tasks after
        Add-AfterTasks $taskContext $task.AfterTasks > $null
    }
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


# --------------------------------------------
#
#   Private functions
#
# --------------------------------------------

function Get-RemoteSession
{
    [CmdletBinding()]
    param
    (
        [string]$serverAddress,
        [int]$port,
        [PSCredential]$credential
    )

    $session = $currentContext.remoteSessions[$serverAddress]
    if($session -eq $null)
    {
        Write-Verbose "Connecting to $($serverAddress) port $port"

        # start new session
        $session = New-PSSession -ComputerName $serverAddress -Port $port -Credential $credential `
            -UseSSL -SessionOption (New-PSSessionOption -SkipCACheck -SkipCNCheck)

        # store it in a cache
        $currentContext.remoteSessions[$serverAddress] = $session
    }

    return $session
}

function Remove-RemoteSessions
{
    foreach($session in $currentContext.remoteSessions.values)
    {
        Write-Verbose "Closing remote session to $($session.ComputerName)"
        Remove-PSSession -Session $session
    }

    $currentContext.remoteSessions.Clear()
}

function ValueOrDefault($value, $default)
{
    If($value)
    {
        return $value
    }
    return $default
}

# --------------------------------------------
#
#   Init tasks
#
# --------------------------------------------
New-DeploymentTask init {
    Write-Log "Initializing deployment framework"
}

New-DeploymentTask deploy {
    Write-Log "Deploying application"
    Start-Sleep -s 3
}

New-DeploymentTask remove {
    Write-Log "Removing application"
}

New-DeploymentTask rollback {
    Write-Log "Rolling back application to the previous version"
}

New-DeploymentTask common-functions -Before init {
    function Write-Log($message)
    {
        Write-Output "[$($env:COMPUTERNAME)] $(Get-Date -f g) - $message"
    }
}

Export-ModuleMember -Function `
    Set-DeploymentConfig, `
    New-Application, Add-WebSiteRole, Add-ServiceRole, New-DeploymentTask, `
    New-Environment, Add-EnvironmentServer, `
    New-Deployment, Remove-Deployment, Restore-Deployment, Restart-Deployment, Stop-Deployment, Start-Deployment