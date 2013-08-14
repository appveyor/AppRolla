# config
$config = @{}
$config.taskExecutionTimeout = 300 # 5 min

# context
$script:context = @{}
$currentContext = $script:context
$currentContext.applications = @{}
$currentContext.environments = @{}
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
        $Variables = @{},

        [Parameter(Mandatory=$false)]
        [scriptblock]$OnPackageDownload = $null
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
        OnPackageDownload = $OnPackageDownload
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


function Set-DeploymentTask
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
        
        [Parameter(Mandatory=$false)][Alias("On")]
        $After = $null,

        [Parameter(Mandatory=$false)]
        $Requires = @(),

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
        BeforeTasks = New-Object System.Collections.Generic.List[string]
        AfterTasks = New-Object System.Collections.Generic.List[string]
        RequiredTasks = $Requires
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
            $beforeTask.BeforeTasks.Add($task.Name) > $null
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
            $afterTask.AfterTasks.Add($task.Name) > $null
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
        [PSCredential]$Credential
    )

    Write-Verbose "New-Environment $Name"

    # create new environment
    $environment = @{
        Name = $Name
        Credential = $Credential
        Servers = @{}
    }

    # verify if environment already exists
    if($currentContext.environments[$environment.Name] -eq $null)
    {
        $currentContext.environments[$environment.Name] = $environment
    }
    else
    {
        throw "Environment $Name already exists. Choose a different name."
    }

    # output to pipeline
    return $environment
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

function Invoke-DeploymentTask
{
    param
    (
        [Parameter(Position=0, Mandatory=$true)]
        [string]$taskName,

        [Parameter(Position=1, Mandatory=$true)][alias("On")]
        $environment,
        
        [Parameter(Position=2, Mandatory=$false)]
        $application,
        
        [Parameter(Position=3, Mandatory=$false)]
        [string]$version,
        
        [Parameter(Mandatory=$false)]
        $serial = $false
    )

    if($application -ne $null -and $application -is [string])
    {
        $application = Get-Application $Application
    }

    if($environment -is [string])
    {
        $environment = Get-Environment $environment
    }

    if($application)
    {
        Write-Verbose "Running `"$taskName`" task on `"$($environment.Name)` environment for application $($application.Name) version $version"
    }
    else
    {
        Write-Verbose "Running `"$taskName`" task on `"$($environment.Name)` environment"
    }

    # build remote task context
    $taskContext = @{
        TaskName = $taskName
        Application = $Application
        Version = $Version
        Environment = $Environment
        ServerTasks = @{}
        Serial = $Serial
    }

    # add main task
    $task = $currentContext.tasks[$taskName]
    if($task -eq $null)
    {
        throw "Task $taskName not found"
    }

    # change task deployment group to application roles union
    if($taskContext.Application)
    {
        $task.DeploymentGroup = @(0) * $taskContext.Application.Roles.count
        $i = 0
        foreach($role in $taskContext.Application.Roles.values)
        {
            $task.DeploymentGroup[$i++] = $role.DeploymentGroup
        }
    }

    # setup tasks for each server
    $perGroupTasks = @{}
    foreach($server in $taskContext.Environment.Servers.values)
    {
        $serverTasks = @{}

        $filter = @{
            Application = $Application
            Version = $Version
            Server = $server
            PerGroupTasks = $perGroupTasks
        }

        # process main task
        Add-ApplicableTasks $serverTasks $task $filter

        # filter per-group tasks
        $keys = $serverTasks.keys | ToArray
        foreach($name in $keys)
        {
            $t = $serverTasks[$name]
            if($t.PerGroup -and $perGroupTasks[$name] -eq $null)
            {
                # add it to the group tasks
                $perGroupTasks[$name] = $true
            }
            elseif($t.PerGroup -and $perGroupTasks[$name] -ne $null)
            {
                # remove it from server tasks
                $serverTasks.Remove($name)
            }
        }

        if($serverTasks.Count -gt 0)
        {
            # insert "init" tasks
            $initTask = $currentContext.tasks["init"]
            Add-ApplicableTasks $serverTasks $initTask $filter

            # add required tasks
            Add-RequiredTasks $serverTasks $task.RequiredTasks $filter

            # add to context
            $taskContext.ServerTasks[$server.ServerAddress] = @{
                Tasks = $serverTasks
                Script = @("init", $taskName)
            }
        }
    }

    # run scripts on each server
    $jobs = @(0) * $taskContext.ServerTasks.count
    $jobCount = 0
    foreach($serverAddress in $taskContext.ServerTasks.keys)
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
        $serverTasks = $taskContext.ServerTasks[$serverAddress]

        $scriptContext = @{
            TaskName = $taskContext.TaskName
            Application = $taskContext.Application
            Version = $taskContext.Version
            ServerAddress = $server.ServerAddress
            ServerDeploymentGroup = $server.DeploymentGroup
            Tasks = $serverTasks.Tasks
        }

        $script = $serverTasks.Script

        $remoteScript = {
            param (
                $context,
                $script
            )

            $context.CallStack = New-Object System.Collections.Generic.Stack[string]

            function Invoke-DeploymentTask($taskName)
            {
                Write-Verbose "Invoke task $taskName $($context.Tasks.count)"
                $task = $context.Tasks[$taskName]
                if($task -ne $null)
                {
                    # push task name to call stack
                    $context.CallStack.Push($taskName) > $null

                    # run before tasks recursively
                    foreach($beforeTask in $task.BeforeTasks)
                    {
                        Invoke-DeploymentTask $beforeTask
                    }

                    # run task
                    .([scriptblock]::Create($task.Script))

                    # run after tasks recursively
                    foreach($afterTask in $task.AfterTasks)
                    {
                        Invoke-DeploymentTask $afterTask
                    }

                    # pop
                    $context.CallStack.Pop() > $null
                }
            }

            # run script parts one-by-one
            foreach($taskName in $script)
            {
                Invoke-DeploymentTask $taskName
            }
        }

        if($taskContext.Serial)
        {
            # run script on remote server synchronously
            Invoke-Command -Session $session -ScriptBlock $remoteScript -ArgumentList $scriptContext,$script
        }
        else
        {
            # run script on remote server as a job
            $jobs[$jobCount++] = Invoke-Command -Session $session -ScriptBlock $remoteScript -AsJob -ArgumentList $scriptContext,$script
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

function Add-ApplicableTasks($tasks, $task, $filter)
{
    if((IsTaskAppicable $task $filter))
    {
        # before tasks recursively
        Add-BeforeTasks $tasks $task.BeforeTasks $filter

        $tasks[$task.Name] = $task

        # after tasks recursively
        Add-AfterTasks $tasks $task.AfterTasks $filter
    }
}

function Add-BeforeTasks($tasks, $beforeTasks, $filter)
{
    foreach($taskName in $beforeTasks)
    {
        $task = $currentContext.tasks[$taskName]
        if($task -ne $null -and (IsTaskAppicable $task $filter))
        {
            # add task before tasks
            Add-BeforeTasks $tasks $task.BeforeTasks $filter
        
            # add task itself
            $tasks[$taskName] = $task
        }
    }
}

function Add-AfterTasks($tasks, $afterTasks, $filter)
{
    foreach($taskName in $afterTasks)
    {
        $task = $currentContext.tasks[$taskName]
        if($task -ne $null -and (IsTaskAppicable $task $filter))
        {
            # add task itself
            $tasks[$taskName] = $task
                
            # add tasks after
            Add-AfterTasks $tasks $task.AfterTasks $filter
        }
    }
}

function Add-RequiredTasks($tasks, $requiredTasks, $filter)
{
    foreach($taskName in $requiredTasks)
    {
        $task = $currentContext.tasks[$taskName]

        if($task -ne $null -and (IsTaskAppicable $task $filter))
        {
            # add task before tasks
            Add-RequiredTasks $tasks $task.RequiredTasks $filter
        
            # add task itself
            $tasks[$taskName] = $task
        }
    }
}

function IsTaskAppicable($task, $filter)
{
    # filter by application name and version
    if($task.Application -ne $null -and $task.Application -ne $filter.Application.Name)
    {
        # task application name is specified but does not match
        return $false
    }
    else
    {
        # OK, application name does match, check version now if specified
        if($task.Version -ne $null -and $task.Version -ne $filter.Version)
        {
            # version is specified but does not match
            return $false
        }
    }

    if($task.DeploymentGroup -eq $null -or $filter.Server.DeploymentGroup -eq $null)
    {
        # task is applicable to all groups
        return $true
    }
    else
    {
        # find intersection of two arrays of DeploymentGroup
        $commonGroups = $task.DeploymentGroup | ?{$filter.Server.DeploymentGroup -contains $_}

        if($commonGroups.length -gt 0)
        {
            return $true
        }
    }

    return $false
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

    Invoke-DeploymentTask deploy $environment $application $version -serial $serial
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

function ToArray
{
    begin
    {
        $output = @(); 
    }
    process
    {
        $output += $_; 
    }
    end
    {
        return ,$output; 
    }
}

# --------------------------------------------
#
#   Init tasks
#
# --------------------------------------------
Set-DeploymentTask init {
    
    $m = New-Module -Name "CommonFunctions" -ScriptBlock {
        function Write-Log($message)
        {
            $callStack = $context.CallStack.ToArray()
            [array]::Reverse($callStack)
            $taskName = $callStack -join "]["
            Write-Output "[$($context.ServerAddress)][$taskName] $(Get-Date -f g) - $message"
        }

        Export-ModuleMember -Function Write-Log
    }
}

Set-DeploymentTask deploy {
    Write-Log "Deploying application"

    if($context.Application.OnPackageDownload)
    {
        $scr = $ExecutionContext.InvokeCommand.NewScriptBlock($context.Application.OnPackageDownload)
        .$scr
    }

    Start-Sleep -s 1
}

Set-DeploymentTask remove {
    Write-Log "Removing application"
}

Set-DeploymentTask rollback {
    Write-Log "Rolling back application to the previous version"
}

Set-DeploymentTask functions -On init {
    Write-Log "Add custom functions..."
}

Export-ModuleMember -Function `
    Set-DeploymentConfig, `
    New-Application, Add-WebSiteRole, Add-ServiceRole, Set-DeploymentTask, `
    New-Environment, Add-EnvironmentServer, `
    Invoke-DeploymentTask, New-Deployment, Remove-Deployment, Restore-Deployment, Restart-Deployment, Stop-Deployment, Start-Deployment