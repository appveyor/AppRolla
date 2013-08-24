# Copyright 2013 Appveyor Systems Inc.
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Version: 1.0

# config
$config = @{}
$config.TaskExecutionTimeout = 300 # 5 min

# default remote root for deployed applications; the value is in single quotes to be evaluated remotely
$config.ApplicationsPath = '$($env:SystemDrive)\applications'

# the maximum number of previous deployment versions to keep on remote hosts
$config.KeepPreviousVersions = 5

# if $true a connection to remote host will use SSL and port defaults to 5986
# if $false port defaults to 5985
$config.UseSSL = $true

# suppress certificate Certificate Authority (CA) check when connecting via SSL
$config.SkipCACheck = $true

# suppress certificate Canonical Name (CN) check when connecting via SSL
$config.SkipCNCheck = $true

# Azure settings
$config.UpdateAzureDeployment = $true

# context
$script:context = @{}
$currentContext = $script:context
$currentContext.applications = @{}
$currentContext.environments = @{}
$currentContext.azureEnvironments = @{}
$currentContext.tasks = @{}
$currentContext.remoteSessions = @{}
$currentContext.azureSubscription = $null

#region Configuration cmdlets
function Set-DeploymentConfiguration
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position=0, Mandatory=$true)]
        $Name,

        [Parameter(Position=1, Mandatory=$false)]
        $Value = $null
    )

    $config[$Name] = $Value
}

function Get-DeploymentConfiguration
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position=0, Mandatory=$false)]
        $Name
    )

    if($Name)
    {
        return $config[$Name]
    }
    else
    {
        return $config
    }
}
#endregion

#region Application cmdlets
function New-Application
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position=0, Mandatory=$true)]
        [string]$Name,

        [Parameter(Mandatory=$false)]
        [string]$BasePath,

        [Parameter(Mandatory=$false)]
        $Configuration = @{}
    )

    Write-Verbose "New-Application $Name"

    # verify if application already exists
    if($currentContext.applications[$Name] -ne $null)
    {
        throw "Application $Name already exists. Choose a different name."
    }

    # add new application
    $app = @{
        Type = "AppRolla"
        Name = $Name
        BasePath = $BasePath
        Configuration = $Configuration
        Roles = @{}
    }

    $currentContext.applications[$Name] = $app
}

function Get-Application
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position=0, Mandatory=$false)]
        $Name
    )

    if($Name)
    {
        # return specific application
        $app = $currentContext.applications[$Name]
        if($app -eq $null)
        {
            throw "Application $Name not found."
        }
        return $app
    }
    else
    {
        # return all applications
        return $currentContext.applications.values
    }
}

function Set-Application
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position=0, Mandatory=$true)]
        [string]$Name,

        [Parameter(Mandatory=$false)]
        [string]$BasePath,

        [Parameter(Mandatory=$false)]
        $Configuration = @{}
    )

    Write-Verbose "Set-Application $Name"

    $app = Get-Application $Name

    # update app details
    if($BasePath) { $app.BasePath = $BasePath }
    if($Configuration) { $app.Configuration = $Configuration }
}


function Add-WebSiteRole
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position=0, Mandatory=$true)]
        $ApplicationName,

        [Parameter(Position=1, Mandatory=$true)]
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
        $Configuration = @{}
    )

    Write-Verbose "Add-WebsiteRole"

    # get application
    $application = Get-Application $ApplicationName

    # verify if the role with such name exists
    $role = $Application.Roles[$Name]
    if($role -ne $null)
    {
        throw "Application $($Application.Name) has already $Name role configured. Choose a different role name."
    }

    # add role info to the application config
    $role = @{
        Type = "website"
        Name = $Name
        DeploymentGroup = ValueOrDefault $DeploymentGroup "web"
        PackageUrl = $PackageUrl
        BasePath = $BasePath
        WebsiteName = ValueOrDefault $WebsiteName "Default Web Site"
        WebsiteProtocol = ValueOrDefault $WebsiteProtocol "http"
        WebsiteIP = ValueOrDefault $WebsiteIP "*"
        WebsitePort = ValueOrDefault $WebsitePort 80
        WebsiteHost = $WebsiteHost
        Configuration = $Configuration
    }
    $Application.Roles[$Name] = $role
}

function Set-WebSiteRole
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position=0, Mandatory=$true)]
        $ApplicationName,

        [Parameter(Position=1, Mandatory=$true)]
        [string]$Name,

        [Parameter(Mandatory=$false)]
        [string]$DeploymentGroup,

        [Parameter(Mandatory=$false)]
        [string]$PackageUrl,

        [Parameter(Mandatory=$false)]
        [string]$BasePath,

        [Parameter(Mandatory=$false)]
        [string]$WebsiteName,

        [Parameter(Mandatory=$false)]
        [string]$WebsiteProtocol = $null,

        [Parameter(Mandatory=$false)]
        [string]$WebsiteIP,

        [Parameter(Mandatory=$false)]
        [int]$WebsitePort,

        [Parameter(Mandatory=$false)]
        [string]$WebsiteHost,

        [Parameter(Mandatory=$false)]
        $Configuration
    )

    Write-Verbose "Set-WebsiteRole"

    # get role
    $role = Get-ApplicationRole $ApplicationName $Name

    # update role details
    if($DeploymentGroup) { $role.DeploymentGroup = $DeploymentGroup }
    if($PackageUrl) { $role.PackageUrl = $PackageUrl }
    if($BasePath) { $role.BasePath = $BasePath }
    if($WebsiteName) { $role.WebsiteName = $WebsiteName }
    if($WebsiteProtocol) { $role.WebsiteProtocol = $WebsiteProtocol }
    if($WebsiteIP) { $role.WebsiteIP = $WebsiteIP }
    if($WebsitePort) { $role.WebsitePort = $WebsitePort }
    if($WebsiteHost) { $role.WebsiteHost = $WebsiteHost }
    if($Configuration) { $role.Configuration = $Configuration }
}

function Add-ServiceRole
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position=0, Mandatory=$true)]
        $ApplicationName,

        [Parameter(Position=1, Mandatory=$true)]
        [string]$Name,

        [Parameter(Mandatory=$false)]
        [string]$DeploymentGroup,

        [Parameter(Mandatory=$true)]
        [string]$PackageUrl,

        [Parameter(Mandatory=$false)]
        [string]$BasePath,

        [Parameter(Mandatory=$false)]
        [string]$ServiceExecutable = $null,

        [Parameter(Mandatory=$false)]
        [string]$ServiceName = $null,

        [Parameter(Mandatory=$false)]
        [string]$ServiceDisplayName = $null,

        [Parameter(Mandatory=$false)]
        [string]$ServiceDescription = $null,

        [Parameter(Mandatory=$false)]
        $Configuration = @{}
    )

    Write-Verbose "Add-ServiceRole"

    # get application
    $application = Get-Application $ApplicationName

    # verify if the role with such name exists
    $role = $Application.Roles[$Name]
    if($role -ne $null)
    {
        throw "Application $($Application.Name) has already $Name role configured. Choose a different role name."
    }

    # add role info to the application config
    $role = @{
        Type = "service"
        Name = $Name
        DeploymentGroup = ValueOrDefault $DeploymentGroup "app"
        PackageUrl = $PackageUrl
        BasePath = $BasePath
        Configuration = $Configuration
    }

    $role.ServiceExecutable = $ServiceExecutable
    $role.ServiceName = ValueOrDefault $ServiceName $Name
    $role.ServiceDisplayName = ValueOrDefault $ServiceDisplayName $role.ServiceName
    $role.ServiceDescription = ValueOrDefault $ServiceDescription "Deployed by AppRoller"

    $Application.Roles[$Name] = $role
}

function Set-ServiceRole
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position=0, Mandatory=$true)]
        $ApplicationName,

        [Parameter(Position=1, Mandatory=$true)]
        [string]$Name,

        [Parameter(Mandatory=$false)]
        [string]$DeploymentGroup,

        [Parameter(Mandatory=$false)]
        [string]$PackageUrl,

        [Parameter(Mandatory=$false)]
        [string]$BasePath,

        [Parameter(Mandatory=$false)]
        [string]$ServiceExecutable,

        [Parameter(Mandatory=$false)]
        [string]$ServiceName,

        [Parameter(Mandatory=$false)]
        [string]$ServiceDisplayName,

        [Parameter(Mandatory=$false)]
        [string]$ServiceDescription,

        [Parameter(Mandatory=$false)]
        $Configuration
    )

    Write-Verbose "Set-ServiceRole"

    # get role
    $role = Get-ApplicationRole $ApplicationName $Name

    # update role details
    if($DeploymentGroup) { $role.DeploymentGroup = $DeploymentGroup }
    if($PackageUrl) { $role.PackageUrl = $PackageUrl }
    if($BasePath) { $role.BasePath = $BasePath }
    if($ServiceExecutable) { $role.ServiceExecutable = $ServiceExecutable }
    if($ServiceName) { $role.ServiceName = $ServiceName }
    if($ServiceDisplayName) { $role.ServiceDisplayName = $ServiceDisplayName }
    if($ServiceDescription) { $role.ServiceDescription = $ServiceDescription }
    if($Configuration) { $role.Configuration = $Configuration }
}

function Get-ApplicationRole
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position=0, Mandatory=$true)]
        $ApplicationName,

        [Parameter(Position=1, Mandatory=$true)]
        $RoleName
    )

    # get application
    $application = Get-Application $ApplicationName

    # verify if the role with such name exists
    $role = $Application.Roles[$RoleName]
    if($role -eq $null)
    {
        throw "Application role $RoleName does not exist."
    }

    return $role
}
#endregion

#region Azure Application cmdlets
function New-AzureApplication
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position=0, Mandatory=$true)]
        [string]$Name,

        [Parameter(Mandatory=$true)]
        [string]$PackageUrl,

        [Parameter(Mandatory=$true)]
        [string]$ConfigUrl,

        [Parameter(Mandatory=$false)]
        $Configuration = @{}
    )

    Write-Verbose "New-AzureApplication $Name"

    # verify if application already exists
    if($currentContext.applications[$Name] -ne $null)
    {
        throw "Application $Name already exists. Choose a different name."
    }

    # add new application
    $app = @{
        Type = "Azure"
        Name = $Name
        PackageUrl = $PackageUrl
        ConfigUrl = $ConfigUrl
        Configuration = $Configuration
    }

    $currentContext.applications[$Name] = $app
}

function Set-AzureApplication
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position=0, Mandatory=$true)]
        [string]$Name,

        [Parameter(Mandatory=$false)]
        [string]$PackageUrl,

        [Parameter(Mandatory=$false)]
        [string]$ConfigUrl,

        [Parameter(Mandatory=$false)]
        $Configuration = @{}
    )

    Write-Verbose "Set-AzureApplication $Name"

    # get application details
    $app = Get-Application $Name

    # update details
    if($PackageUrl) { $app.PackageUrl = $PackageUrl }
    if($ConfigUrl) { $app.ConfigUrl = $ConfigUrl }
    if($Configuration) { $app.Configuration = $Configuration }
}
#endregion

#region Environment cmdlets
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
        $Configuration = @{}
    )

    Write-Verbose "New-Environment $Name"

    # create new environment
    $environment = @{
        Name = $Name
        Credential = $Credential
        Servers = @{}
        Configuration = $Configuration
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
}

function Get-Environment
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position=0, Mandatory=$false)]
        $Name
    )

    if($Name)
    {
        # get specific environment
        $environment = $currentContext.environments[$Name]
        if($environment -eq $null)
        {
            throw "Environment $Name not found."
        }
        return $environment
    }
    else
    {
        # return all environments
        return $currentContext.environments.values
    }
}

function Set-Environment
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position=0, Mandatory=$true)]
        $Name,

        [Parameter(Mandatory=$false)]
        [PSCredential]$Credential,

        [Parameter(Mandatory=$false)]
        $Configuration
    )

    Write-Verbose "Set-Environment $Name"

    # find environment
    $environment = Get-Environment $Name

    # update details
    if($Credential) { $environment.Credential = $Credential }
    if($Configuration) { $environment.Configuration = $Configuration }
}

function Add-EnvironmentServer
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position=0, Mandatory=$true)]
        $EnvironmentName,

        [Parameter(Position=1, Mandatory=$true)]
        [string]$ServerAddress,

        [Parameter(Mandatory=$false)]
        [int]$Port = 0,

        [Parameter(Mandatory=$false)]
        [string[]]$DeploymentGroup = $null,

        [Parameter(Mandatory=$false)]
        [PSCredential]$Credential = $null
    )

    Write-Verbose "Add-EnvironmentServer $ServerAddress"

    # find environment
    $environment = Get-Environment $EnvironmentName

    # verify if the server with specified address exists
    $server = $Environment.Servers[$ServerAddress]
    if($server -ne $null)
    {
        throw "Environment $($Environment.Name) has already $ServerAddress server added."
    }

    # add role info to the application config
    $server = @{
        ServerAddress = $ServerAddress
        Port = $Port
        DeploymentGroup = $DeploymentGroup
        Credential = ValueOrDefault $Credential $Environment.Credential
    }
    $Environment.Servers[$ServerAddress] = $server
}
#endregion

#region Azure Environment cmdlets
function New-AzureEnvironment
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position=0, Mandatory=$true)]
        $Name,

        [Parameter(Mandatory=$true)]
        [string]$CloudService,

        [Parameter(Mandatory=$true)]
        [string]$Slot
    )

    Write-Verbose "New-AzureEnvironment $Name"

    # create new environment
    $environment = @{
        Name = $Name
        CloudService = $CloudService
        Slot = $Slot
    }

    # verify if environment already exists
    if($currentContext.azureEnvironments[$environment.Name] -eq $null)
    {
        $currentContext.azureEnvironments[$environment.Name] = $environment
    }
    else
    {
        throw "Azure environment $Name already exists. Choose a different name."
    }
}

function Get-AzureEnvironment
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position=0, Mandatory=$false)]
        $Name
    )

    if($Name)
    {
        # get specific environment
        $environment = $currentContext.azureEnvironments[$Name]
        if($environment -eq $null)
        {
            throw "Azure environment $Name not found."
        }
        return $environment
    }
    else
    {
        # return all environments
        return $currentContext.azureEnvironments.values
    }
}

function Set-AzureEnvironment
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position=0, Mandatory=$true)]
        $Name,

        [Parameter(Mandatory=$false)]
        [PSCredential]$Credential,

        [Parameter(Mandatory=$false)]
        $Configuration
    )

    Write-Verbose "Set-Environment $Name"

    # find environment
    $environment = Get-Environment $Name

    # update details
    if($Credential) { $environment.Credential = $Credential }
    if($Configuration) { $environment.Configuration = $Configuration }
}
#endregion

#region Task cmdlets
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
        [string[]]$Before = @(),
        
        [Parameter(Mandatory=$false)][Alias("On")]
        [string[]]$After = @(),

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
    if($Before)
    {
        foreach($beforeTaskName in $Before)
        {
            $beforeTask = $currentContext.tasks[$beforeTaskName]
            if($beforeTask -ne $null)
            {
                $beforeTask.BeforeTasks.Add($task.Name) > $null
            }
            else
            {
                throw "Wrong before task: $Before"
            }
        }
    }

    if($After)
    {
        foreach($afterTaskName in $After)
        {
            $afterTask = $currentContext.tasks[$afterTaskName]
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
        [switch]$Serial = $false
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
        # server sequence to run
        $serverTasks = $taskContext.ServerTasks[$serverAddress]

        $server = $environment.Servers[$serverAddress]

        $scriptContext = @{
            Configuration = $config
            TaskName = $taskContext.TaskName
            Application = $taskContext.Application
            Version = $taskContext.Version
            Server = @{
                ServerAddress = $server.ServerAddress
                DeploymentGroup = $server.DeploymentGroup                
            }
            Environment = @{
                Name = $environment.Name
                Configuration = $environment.Configuration
            }
            Tasks = $serverTasks.Tasks
        }

        $script = $serverTasks.Script

        $deployScript = {
            param (
                $context,
                $script
            )

            $callStack = New-Object System.Collections.Generic.Stack[string]

            function Write-Log($message)
            {
                $stack = $callStack.ToArray()
                [array]::Reverse($stack)
                $taskName = $stack -join ":"
                Write-Host "[$($context.Server.ServerAddress)][$taskName] $(Get-Date -f g) - $message"
            }

            function Invoke-DeploymentTask($taskName)
            {
                Write-Verbose "Invoke task $taskName"
                $task = $context.Tasks[$taskName]
                if($task -ne $null)
                {
                    # push task name to call stack
                    $callStack.Push($taskName) > $null

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
                    $callStack.Pop() > $null
                }
            }

            # run script parts one-by-one
            foreach($taskName in $script)
            {
                Invoke-DeploymentTask $taskName
            }
        }

        if(IsLocalhost $server.ServerAddress)
        {
            # run script locally
            if($taskContext.Serial)
            {
                # run script synchronously
                Write-Verbose "Running script synchronously on localhost"
                Invoke-Command -ScriptBlock $deployScript -ArgumentList $scriptContext,$script 
            }
            else
            {
                # run script as a job
                Write-Verbose "Run script in parallel on localhost"
                $jobs[$jobCount++] = Start-Job -ScriptBlock $deployScript -ArgumentList $scriptContext,$script
            }
        }
        else
        {
            # get server remote session
            $server = $taskContext.Environment.Servers[$serverAddress]
            $credential = $server.Credential
            if(-not $credential)
            {
                $credential = $taskContext.Environment.Credential
            }

            $session = Get-RemoteSession -serverAddress $server.ServerAddress -port $server.Port -credential $credential

            # run script on remote machine
            if($taskContext.Serial)
            {
                # run script on remote server synchronously
                Write-Verbose "Running script synchronously on $($server.ServerAddress)"
                Invoke-Command -Session $session -ScriptBlock $deployScript -ArgumentList $scriptContext,$script
            }
            else
            {
                # run script on remote server as a job
                Write-Verbose "Run script in parallel on $($server.ServerAddress)"
                $jobs[$jobCount++] = Invoke-Command -Session $session -ScriptBlock $deployScript -AsJob -ArgumentList $scriptContext,$script
            }
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
        $useSSL = $config.UseSSL
        $skipCACheck = $config.SkipCACheck
        $skipCNCheck = $config.SkipCNCheck

        if($port -eq 0 -and $useSSL)
        {
            $port = 5986
        }
        elseif($port -eq 0)
        {
            $port = 5985
        }

        Write-Verbose "Connecting to $($serverAddress) port $port"

        $options = New-PSSessionOption -SkipCACheck:$skipCACheck -SkipCNCheck:$skipCNCheck

        # start new session
        if($credential)
        {
            # connect with credentials
            $session = New-PSSession -ComputerName $serverAddress -Port $port -Credential $credential `
                -UseSSL:$useSSL -SessionOption $options
        }
        else
        {
            # connect without credentials
            $session = New-PSSession -ComputerName $serverAddress -Port $port `
                -UseSSL:$useSSL -SessionOption $options
        }

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
        
        if($session)
        {
            Remove-PSSession -Session $session
        }
    }

    $currentContext.remoteSessions.Clear()
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
            # add required tasks recursively
            Add-RequiredTasks $tasks $task.RequiredTasks $filter

            Add-ApplicableTasks $tasks $task $filter
        
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
#endregion

#region Deployment cmdlets
function New-Deployment
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
        $Application,

        [Parameter(Position=1, Mandatory=$true)]
        $Version,

        [Parameter(Position=2, Mandatory=$true)][alias("To")]
        $Environment,

        [Parameter(Mandatory=$false)]
        [switch]$Serial = $false
    )

    $app = Get-Application $Application

    if($app.Type -eq "Azure")
    {
        # Azure deployment
        DeployAzureApplication $app $Version $Environment
    }
    else
    {
        # AppRolla deployment
        Invoke-DeploymentTask deploy $environment $app $version -Serial:$serial
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

        [Parameter(Mandatory=$true)][alias("From")]
        $Environment,

        [Parameter(Mandatory=$false)]
        [switch]$Serial = $false
    )

    $app = Get-Application $Application

    if($app.Type -eq "Azure")
    {
        # Azure deployment
        DeleteAzureDeployment $Environment
    }
    else
    {
        # AppRolla deployment
        Invoke-DeploymentTask remove $environment $application $version -Serial:$serial
    }
}

function Restore-Deployment
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
        $Application,

        [Parameter(Position=1, Mandatory=$false)]
        $Version,

        [Parameter(Mandatory=$true)][alias("On")]
        $Environment,

        [Parameter(Mandatory=$false)]
        [switch]$Serial = $false
    )

    Invoke-DeploymentTask rollback $environment $application $version -Serial:$serial
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

    Invoke-DeploymentTask restart $environment $application -Serial:$serial
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

    Invoke-DeploymentTask stop $environment $application -Serial:$serial
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

    Invoke-DeploymentTask start $environment $application -Serial:$serial
}
#endregion

#region Helper functions
function Write-Log($message)
{
    Write-Host "$(Get-Date -f g) - $message"
}

function IsLocalhost
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position=0, Mandatory=$true)]
        [string]$serverAddress
    )

    return ($serverAddress -eq "localhost" -or $serverAddress -eq "127.0.0.1")
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
#endregion

#region AppRolla tasks
Set-DeploymentTask init {
    
    $m = New-Module -Name "CommonFunctions" -ScriptBlock {

        function Expand-Zip
        {
            param(
                [Parameter(Position=0,Mandatory=1)]$zipFile,
                [Parameter(Position=1,Mandatory=1)]$destination
            )

            $shellApp = New-Object -com Shell.Application
            $objZip = $shellApp.Namespace($zipFile)
            $objDestination = $shellApp.Namespace($destination)
            $objDestination.CopyHere($objZip.Items(), 16)
        }

        function Update-ApplicationConfig
        {
            param (
                $configPath,
                $variables
            )

            [xml]$xml = New-Object XML
            $xml.Load($configPath)

            # appSettings section
            foreach($appSettings in $xml.selectnodes("//*[local-name() = 'appSettings']"))
            {
                foreach($setting in $appSettings.ChildNodes)
                {
                    if($setting.key)
                    {
                        $value = $variables["appSettings.$($setting.key)"]
                        if($value -ne $null)
                        {
                            Write-Log "Updating <appSettings> entry `"$($setting.key)`" to `"$value`""
                            $setting.value = $value
                        }
                    }
                }
            }

            # connectionStrings
            foreach($connectionStrings in $xml.selectnodes("//*[local-name() = 'connectionStrings']"))
            {
                foreach($entry in $connectionStrings.ChildNodes)
                {
                    if($entry.name)
                    {
                        $connectionString = $variables["connectionStrings.$($entry.name)"]
                        if($connectionString -ne $null)
                        {
                            Write-Log "Updating <connectionStrings> entry `"$($entry.name)`" to `"$connectionString`""
                            $entry.connectionString = $connectionString
                        }
                    }
                }
            }

            $xml.Save($configPath)
        }

        function Test-RoleApplicableToServer
        {
            param (
                $role
            )

            # find intersection of two arrays of DeploymentGroup
            $commonGroups = $role.DeploymentGroup | ?{$context.Server.DeploymentGroup -contains $_}
            return (-not $context.Server.DeploymentGroup -or $commonGroups.length -gt 0)
        }

        function Get-TempFileName
        {
            param (
                [Parameter(Position=0,Mandatory=$false)]
                $extension
            )

            $tempPath = [System.IO.Path]::GetTempPath()
            $fileName = [System.IO.Path]::GetRandomFileName()
            if($extension)
            {
                # change extension
                $fileName = [System.IO.Path]::GetFileNameWithoutExtension($fileName) + $extension
            }
            return [System.IO.Path]::Combine($tempPath, $fileName)
        }

        function Get-WindowsService
        {
            param (
                [Parameter(Position=0,Mandatory=$true)]
                $serviceName
            )

            Get-WmiObject -Class Win32_Service -Filter "Name='$serviceName'"
        }

        function Get-VersionFromFileName($fileName)
        {
            return Get-VersionFromDirectory (Split-Path $fileName)
        }

        function Get-VersionFromDirectory($directory)
        {
            return $directory.Substring($directory.LastIndexOf("\") + 1)
        }

        function ConvertFrom-StringTemplate
        {
            param (
                [Parameter(Position=0,Mandatory=$true)]
                $str
            )
            & ([scriptblock]::Create("`"$str`""))
        }

        Export-ModuleMember -Function Push-TaskCallStack, Pop-TaskCallStack, Write-Log, Expand-Zip, Test-RoleApplicableToServer, `
            Update-ApplicationConfig, Get-TempFileName, Get-WindowsService, Get-VersionFromFileName, Get-VersionFromDirectory, `
            ConvertFrom-StringTemplate
    }
}

Set-DeploymentTask download-package -Requires authenticate-download-client {
    Write-Log "Downloading package $($role.PackageUrl)"

    # expects parameters:
    #    $role - application role
    #    $packageFile - local package file
    
    $webClient = New-Object System.Net.WebClient

    # call custom method to authenticate web client
    Invoke-DeploymentTask authenticate-download-client

    # download
    $webClient.DownloadFile($role.PackageUrl, $packageFile)
}

Set-DeploymentTask authenticate-download-client {
    # expects parameters:
    #    $webClient - WebClient instance to download package
    #    $context.Configuration["appveyorApiKey"] - AppVeyor API access key
    #    $context.Configuration["appveyorApiSecret"] - AppVeyor API secret key
    #    $context.Configuration["accountId"] - AppVeyor API account ID to login

    if(-not $role.PackageUrl.StartsWith("https://ci.appveyor.com/api/"))
    {
        return
    }

    $apiAccessKey = $context.Configuration["appveyorApiKey"]
    $apiSecretKey = $context.Configuration["appveyorApiSecret"]
    $accountId = $context.Configuration["appveyorAccountId"]

    # verify parameters
    if(-not $apiAccessKey -or -not $apiSecretKey)
    {
        $msg = @"
"Unable to download package from AppVeyor repository.
To authenticate request set AppVeyor API keys in global deployment configuration:
- Set-DeploymentConfiguration appveyorApiKey <api-access-key>
- Set-DeploymentConfiguration appveyorApiSecret <api-secret-key>"
"@
        throw $msg
    }

    $timestamp = [DateTime]::UtcNow.ToString("r")

    # generate signature
    $stringToSign = $timestamp
	$secretKeyBytes = [byte[]]([System.Text.Encoding]::ASCII.GetBytes($apiSecretKey))
	$stringToSignBytes = [byte[]]([System.Text.Encoding]::ASCII.GetBytes($stringToSign))
	
	[System.Security.Cryptography.HMACSHA1] $signer = New-Object System.Security.Cryptography.HMACSHA1(,$secretKeyBytes)
	$signatureHash = $signer.ComputeHash($stringToSignBytes)
	$signature = [System.Convert]::ToBase64String($signatureHash)

    $headerValue = "HMAC-SHA1 accessKey=`"$apiAccessKey`", timestamp=`"$timestamp`", signature=`"$signature`""
    if($accountId)
    {
        $headerValue = $headerValue + ", accountId=`"$accountId`""
    }
    
    # set web client header
    $webClient.Headers.Add("Authorization", $headerValue)
}

Set-DeploymentTask setup-role-folder {
    
    $rootPath = $null
    $basePath = $null

    if($role.BasePath)
    {
        $basePath = ConvertFrom-StringTemplate $role.BasePath
    }
    elseif($context.Application.BasePath)
    {
        $basePath = ConvertFrom-StringTemplate $context.Application.BasePath
        $basePath = Join-Path $basePath $role.Name
    }
    elseif($context.Configuration.applicationsPath)
    {
        $basePath = ConvertFrom-StringTemplate $context.Configuration.applicationsPath
        $basePath = Join-Path $basePath $context.Application.Name
        $basePath = Join-Path $basePath $role.Name
    }

    if(-not $basePath)
    {
        throw "Cannot determine role base path"
    }
    else
    {
        $role.BasePath = $basePath
    }

    # append version
    if($context.Version)
    {
        $role.RootPath = Join-Path $role.BasePath $context.Version
    }

    Write-Log "Role base path: $($role.BasePath)"
    Write-Log "Role deployment path: $($role.RootPath)"

    # read all installed role versions
    if(Test-Path $role.BasePath)
    {
        $versionFolders = Get-ChildItem -Path $role.BasePath | Sort-Object -Property CreationTime -Descending
        $role.Versions = @(0) * $versionFolders.Count
        for($i = 0; $i -lt $role.Versions.Length; $i++)
        {
            $role.Versions[$i] = $versionFolders[$i].Name
        }

        if($role.Versions.length -gt 0)
        {
            Write-Log "Role installed version: $($role.Versions[0])"
        }
    }
}

Set-DeploymentTask deploy -Requires setup-role-folder,download-package,deploy-website,deploy-service,deploy-console {
    Write-Log "Deploying application"

    # deploy each role separately
    foreach($role in $context.Application.Roles.values)
    {
        if(Test-RoleApplicableToServer $role)
        {
            # determine the location of application folder
            Invoke-DeploymentTask setup-role-folder

            # $role.BasePath - base path for role versions
            # $role.RootPath - role version installation root (application root)
            # $role.Versions - the list of installed versions (latest first)

            # invoke role specific deployment code
            Invoke-DeploymentTask "deploy-$($role.Type)"

            # delete previous versions
            if($role.Versions.length -gt $context.Configuration.KeepPreviousVersions)
            {
                for($i = $context.Configuration.KeepPreviousVersions; $i -lt $role.Versions.length; $i++)
                {
                    $version = $role.Versions[$i]
                    Write-Log "Deleting old version $version"
                    Remove-Item (Join-Path $role.BasePath $version) -Force -Recurse
                }
            }
        }
    }
}

Set-DeploymentTask deploy-website {
    Write-Log "Deploying website $($role.Name)"

    Import-Module WebAdministration

    # ... and make sure the folder does not exists
    if(Test-Path $role.RootPath)
    {
        throw "$($context.Application.Name) $($context.Version) role $($role.Name) deployment already exists."
    }

    try
    {
        # create application folder (with version info)
        Write-Log "Create website folder: $($role.RootPath)"
        New-Item -ItemType Directory -Force -Path $role.RootPath > $null

        # download service package to temp location
        $packageFile = Get-TempFileName ".zip"
        Invoke-DeploymentTask download-package

        # unzip service package to application folder
        Expand-Zip $packageFile $role.RootPath

        # update web.config
        $webConfigPath = Join-Path $role.RootPath "web.config"
        if(Test-Path $webConfigPath)
        {
            Write-Log "Updating web.config in $appConfigPath"
            Update-ApplicationConfig -configPath $webConfigPath -variables $role.Configuration
        }

        $appPoolName = $role.WebsiteName
        $appPoolIdentityName = "IIS APPPOOL\$appPoolName"

        $website = Get-Item "IIS:\Sites\$($role.WebsiteName)" -EA 0
        if ($website -ne $null)
        {
            Write-Log "Website `"$($role.WebsiteName)`" already exists"

            $appPoolName = $website.applicationPool

            # get app pool details
            $appPool = Get-Item "IIS:\AppPools\$appPoolName" -EA 0

            # determine pool identity
            switch($appPool.processModel.identityType)
            {
                ApplicationPoolIdentity { $appPoolIdentityName = "IIS APPPOOL\$appPoolName" }
                NetworkService { $appPoolIdentityName = "NETWORK SERVICE" }
                SpecificUser { $appPoolIdentityName = $appPool.processModel.userName }
            }

            # stop application pool
            Write-Log "Stopping website application pool..."
            Stop-WebAppPool $website.applicationPool

	        # wait 2 sec before continue
	        Start-Sleep -s 2
        }

        Write-Log "Application pool name: $appPoolName"
        Write-Log "Application pool identity: $appPoolIdentityName"

        # create website if required
        if(-not $website)
        {
            # create application pool
            Write-Log "Creating IIS application pool `"$appPoolName`""
            $webAppPool = New-WebAppPool -Name $appPoolName -Force
            $WebAppPool.processModel.identityType = "ApplicationPoolIdentity"
            $WebAppPool | Set-Item

            Write-Log "Granting `"Read`" permissions to application pool identity on application folder"
            icacls $role.RootPath /grant "IIS APPPOOL\$($appPoolName):(OI)(CI)(R)" > $null

            # create website
            New-Item "IIS:\Sites\$($role.WebsiteName)" -Bindings @{protocol="$($role.WebsiteProtocol)";bindingInformation="$($role.WebsiteIP):$($role.WebsitePort):$($role.WebsiteHost)"} `
                -PhysicalPath $role.RootPath -ApplicationPool $appPoolName > $null
        }
        else
        {
            Write-Log "Granting `"Read`" permissions to application pool identity on application folder"
            icacls $role.RootPath /grant "IIS APPPOOL\$($appPoolName):(OI)(CI)(R)" > $null

            # update website root folder
            Set-ItemProperty "IIS:\Sites\$($role.WebsiteName)" -Name physicalPath -Value $role.RootPath

            # start application pool
            Write-Log "Starting application pool..."
            Start-WebAppPool $appPoolName
        }
    }
    catch
    {
        # delete new application folder
        if(Test-Path $role.RootPath)
        {
            Remove-Item $role.RootPath -Force -Recurse
        }
        throw
    }
    finally
    {
        # cleanup
        Write-Log "Cleanup..."
        Remove-Item $packageFile -Force
    }
}

Set-DeploymentTask deploy-service {
    Write-Log "Deploying Windows service $($role.Name)"

    # ... and make sure the folder does not exists
    if(Test-Path $role.RootPath)
    {
        throw "$($context.Application.Name) $($context.Version) role $($role.Name) deployment already exists."
    }

    $currentServiceExecutablePath = $null
    try
    {
        # create application folder (with version info)
        Write-Log "Create application folder: $($role.RootPath)"
        New-Item -ItemType Directory -Force -Path $role.RootPath > $null

        # download service package to temp location
        $packageFile = Get-TempFileName ".zip"
        Invoke-DeploymentTask download-package

        # unzip service package to application folder
        Expand-Zip $packageFile $role.RootPath

        # find windows service executable
        $serviceExecutablePath = $null
        if($role.ServiceExecutable)
        {
            $serviceExecutablePath = Join-Path $role.RootPath $role.ServiceExecutable
        }
        else
        {
            $serviceExecutablePath = Get-ChildItem "$($role.RootPath)\*.exe" | Select-Object -First 1
        }
        Write-Log "Service executable path: $serviceExecutablePath"

        # update app.config
        $appConfigPath = "$serviceExecutablePath.config"
        if(Test-Path $appConfigPath)
        {
            Write-Log "Updating service configuration in $appConfigPath"
            Update-ApplicationConfig -configPath $appConfigPath -variables $role.Configuration
        }

        # check if the service already exists
        $existingService = Get-WindowsService $role.ServiceName
        if ($existingService -ne $null)
        {
            Write-Log "Service already exists, stopping..."

            # remember path to restore in case of disaster
            $currentServiceExecutablePath = $existingService.PathName

            # stop the service
            Stop-Service -Name $role.ServiceName -Force

	        # wait 2 sec before continue
	        Start-Sleep -s 2

            # uninstall service
            $existingService.Delete() > $null
        }
        else
        {
            Write-Log "Service does not exists."
        }

        # install service
        Write-Log "Installing service $($role.ServiceName)"
        New-Service -Name $role.ServiceName -BinaryPathName $serviceExecutablePath `
            -DisplayName $role.ServiceDisplayName -StartupType Automatic -Description $role.ServiceDescription > $null

        # start service
        Write-Log "Starting service..."
        Start-Service -Name $role.ServiceName
    }
    catch
    {
        # delete new application folder
        if(Test-Path $role.RootPath)
        {
            Remove-Item $role.RootPath -Force -Recurse
        }
        throw
    }
    finally
    {
        # cleanup
        Write-Log "Cleanup..."
        Remove-Item $packageFile -Force
    }
}

Set-DeploymentTask remove -Requires setup-role-folder,remove-website,remove-service {
    Write-Log "Removing deployment"

    # remove role-by-role
    foreach($role in $context.Application.Roles.values)
    {
        if(Test-RoleApplicableToServer $role)
        {
            Invoke-DeploymentTask "remove-$($role.Type)"
        }
    }
}

Set-DeploymentTask remove-website {
    Write-Log "Removing website $($role.Name)"

    Import-Module WebAdministration

    # determine the location of application folder
    Invoke-DeploymentTask setup-role-folder

    # get website details
    $website = Get-Item "IIS:\Sites\$($role.WebsiteName)" -EA 0
    if ($website -ne $null)
    {
        Write-Log "Website `"$($role.WebsiteName)`" found"

        $siteRoot = $website.physicalPath

        # make sure we are not trying to delete active version
        $currentVersion = Get-VersionFromDirectory $siteRoot

        if($currentVersion -eq $context.Version)
        {
            throw "Active version $version cannot be removed. Specify previous version to remove or ommit -Version parameter to completely delete application."
        }
    }

    if(-not $context.Version)
    {
        # delete entire deployment
        Write-Log "Deleting all website deployments"

        if($website -ne $null)
        {
            $appPoolName = $website.applicationPool

            # stop application pool
            Write-Log "Stopping application pool $appPoolName..."
            Stop-WebAppPool $appPoolName

	        # wait 2 sec before continue
	        Start-Sleep -s 2

            # delete website
            Write-Log "Deleting website $($role.WebsiteName)"
            Remove-Website $role.WebsiteName

            # delete application pool
            Write-Log "Deleting application pool $appPoolName"
            Remove-WebAppPool $appPoolName
        }

        # delete role folder recursively
        Write-Log "Deleting application directory $($role.BasePath)"
        if(Test-Path $role.BasePath)
        {
            Remove-Item $role.BasePath -Force -Recurse
        }
    }
    else
    {
        # delete specific version
        if(Test-Path $role.RootPath)
        {
            Write-Log "Deleting deployment directory $($role.RootPath)"
            Remove-Item $role.RootPath -Force -Recurse
        }
    }

}

Set-DeploymentTask remove-service {
    Write-Log "Removing Windows service $($role.Name)"

    # determine the location of application folder
    Invoke-DeploymentTask setup-role-folder

    # get service details
    $service = Get-WindowsService $role.ServiceName
    if ($service -ne $null)
    {
        $serviceExecutable = $service.PathName

        # make sure we are not trying to delete active version
        $currentVersion = Get-VersionFromFileName $serviceExecutable

        if($currentVersion -eq $context.Version)
        {
            throw "Active version $version cannot be removed. Specify previous version to remove or ommit -Version parameter to completely delete application."
        }
    }

    if(-not $context.Version)
    {
        # delete entire deployment
        Write-Log "Deleting all service deployments"

        # delete service
        if ($service -ne $null)
        {
            # stop the service
            Write-Log "Stopping service $($role.ServiceName)..."
            Stop-Service -Name $role.ServiceName -Force

	        # wait 2 sec before continue
	        Start-Sleep -s 2

            # uninstall service
            Write-Log "Deleting service $($role.ServiceName)"
            $service.Delete() > $null
        }

        # delete role folder recursively
        Write-Log "Deleting application directory $($role.BasePath)"
        if(Test-Path $role.BasePath)
        {
            Remove-Item $role.BasePath -Force -Recurse
        }
    }
    else
    {
        # delete specific version
        if(Test-Path $role.RootPath)
        {
            Write-Log "Deleting deployment directory $($role.RootPath)"
            Remove-Item $role.RootPath -Force -Recurse
        }
    }
}

Set-DeploymentTask rollback -Requires setup-role-folder,rollback-website,rollback-service {
    Write-Log "Rollback deployment"

    # rollback role-by-role
    foreach($role in $context.Application.Roles.values)
    {
        if(Test-RoleApplicableToServer $role)
        {
            Invoke-DeploymentTask "rollback-$($role.Type)"
        }
    }
}

Set-DeploymentTask rollback-website {
    Import-Module WebAdministration

    # determine the location of application folder
    Invoke-DeploymentTask setup-role-folder

    # check if rollback is possible
    if($role.Versions.length -lt 2)
    {
        throw "There are no previous versions to rollback to."
    }

    # current version
    $currentVersion = $role.Versions[0]
    $currentPath = Join-Path $role.BasePath $currentVersion

    # get website details to determine actual current version
    $website = Get-Item "IIS:\Sites\$($role.WebsiteName)" -EA 0
    if ($website -ne $null)
    {
        $currentPath = $website.physicalPath
        $currentVersion = Get-VersionFromDirectory $currentPath
    }

    # rollback version
    $rollbackVersion = $null
    $rollbackPath = $null

    # is that a specific version we want to rollback to?
    if($context.Version)
    {
        # make sure we don't rollback to active version
        if($context.Version -eq $currentVersion)
        {
            throw "Cannot rollback to the currently deployed version $currentVersion"
        }

        if(Test-Path $role.RootPath)
        {
            $rollbackVersion = $context.Version
            $rollbackPath = $role.RootPath
        }
        else
        {
            throw "Version $($context.Version) not found."
        }
    }
    else
    {
        # determine rollback version
        # rollback version must be next after the current one
        for($i = 0; $i -lt $role.Versions.length; $i++)
        {
            # find current version and make sure it's not the last one in the list
            if($role.Versions[$i] -eq $currentVersion -and $i -ne ($role.Versions.length - 1))
            {
                $rollbackVersion = $role.Versions[$i+1]
                $rollbackPath = Join-Path $role.BasePath $rollbackVersion
                break
            }
        }

        if(-not $rollbackVersion)
        {
            throw "Cannot rollback to the previous version because the active $currentVersion is the last one."
        }
    }

    # start rollback
    Write-Log "Rollback website $($role.Name) to version $rollbackVersion"

    # stop website if it exists
    if ($website -ne $null)
    {
        # stop application pool
        Write-Log "Stopping application pool..."
        Stop-WebAppPool $website.applicationPool

	    # wait 2 sec before continue
	    Start-Sleep -s 2

        # change website root folder
        Write-Log "Update website root folder to $rollbackPath"
        Set-ItemProperty "IIS:\Sites\$($role.WebsiteName)" -Name physicalPath -Value $rollbackPath

        # start application pool
        Write-Log "Starting application pool..."
        Start-WebAppPool $website.applicationPool
    }

    # delete current version
    Write-Log "Deleting current version $currentVersion at $currentPath"
    Remove-Item (Join-Path $role.BasePath $currentVersion) -Force -Recurse
}

Set-DeploymentTask rollback-service {
    
    # determine the location of application folder
    Invoke-DeploymentTask setup-role-folder

    # check if rollback is possible
    if($role.Versions.length -lt 2)
    {
        throw "There are no previous versions to rollback to."
    }

    # current version
    $currentVersion = $role.Versions[0]
    $currentPath = Join-Path $role.BasePath $currentVersion

    # get service details to determine actual current version
    $service = Get-WindowsService $role.ServiceName
    if ($service -ne $null)
    {
        $currentPath = Split-Path $service.PathName
        $currentVersion = Get-VersionFromDirectory $currentPath
    }

    # rollback version
    $rollbackVersion = $null
    $rollbackPath = $null

    # is that a specific version we want to rollback to?
    if($context.Version)
    {
        # make sure we don't rollback to active version
        if($context.Version -eq $currentVersion)
        {
            throw "Cannot rollback to the currently deployed version $currentVersion"
        }

        if(Test-Path $role.RootPath)
        {
            $rollbackVersion = $context.Version
            $rollbackPath = $role.RootPath
        }
        else
        {
            throw "Version $($context.Version) not found."
        }
    }
    else
    {
        # determine rollback version
        # rollback version must be next after the current one
        for($i = 0; $i -lt $role.Versions.length; $i++)
        {
            # find current version and make sure it's not the last one in the list
            if($role.Versions[$i] -eq $currentVersion -and $i -ne ($role.Versions.length - 1))
            {
                $rollbackVersion = $role.Versions[$i+1]
                $rollbackPath = Join-Path $role.BasePath $rollbackVersion
                break
            }
        }

        if(-not $rollbackVersion)
        {
            throw "Cannot rollback to the previous version because the active $currentVersion is the last one."
        }
    }

    # start rollback
    Write-Log "Rollback Windows service $($role.Name) to version $rollbackVersion"

    # stop service if exists
    if ($service -ne $null)
    {
        Write-Log "Service already exists, stopping..."

        # stop the service
        Stop-Service -Name $role.ServiceName -Force

	    # wait 2 sec before continue
	    Start-Sleep -s 2

        # uninstall service
        $service.Delete() > $null
    }
    else
    {
        Write-Log "Service does not exists."
    }

    # find windows service executable
    $serviceExecutablePath = $null
    if($role.ServiceExecutable)
    {
        $serviceExecutablePath = Join-Path $rollbackPath $role.ServiceExecutable
    }
    else
    {
        $serviceExecutablePath = Get-ChildItem "$rollbackPath\*.exe" | Select-Object -First 1
    }
    Write-Log "Service executable path: $serviceExecutablePath"

    # install service
    Write-Log "Installing service $($role.ServiceName)"
    New-Service -Name $role.ServiceName -BinaryPathName $serviceExecutablePath `
        -DisplayName $role.ServiceDisplayName -StartupType Automatic -Description $role.ServiceDescription > $null

    # start service
    Write-Log "Starting service..."
    Start-Service -Name $role.ServiceName

    # delete current version
    Write-Log "Deleting current version $currentVersion at $currentPath"
    Remove-Item (Join-Path $role.BasePath $currentVersion) -Force -Recurse
}

Set-DeploymentTask start -Requires setup-role-folder,start-website,start-service {
    Write-Log "Start deployment"

    # start role-by-role
    foreach($role in $context.Application.Roles.values)
    {
        if(Test-RoleApplicableToServer $role)
        {
            Invoke-DeploymentTask "start-$($role.Type)"
        }
    }
}

Set-DeploymentTask stop -Requires setup-role-folder,stop-website,stop-service {
    Write-Log "Stop deployment"

    # stop role-by-role
    foreach($role in $context.Application.Roles.values)
    {
        if(Test-RoleApplicableToServer $role)
        {
            Invoke-DeploymentTask "stop-$($role.Type)"
        }
    }
}

Set-DeploymentTask start-website {
    Write-Log "Start website $($role.Name)"

    Import-Module WebAdministration

    $website = Get-Item "IIS:\Sites\$($role.WebsiteName)" -EA 0
    if ($website -ne $null)
    {
        $appPoolName = $website.applicationPool
        Write-Log "Starting application pool $appPoolName..."
        Start-WebAppPool $appPoolName
        Write-Log "Application pool started"
    }
}

Set-DeploymentTask stop-website {
    Write-Log "Stop website $($role.Name)"

    Import-Module WebAdministration

    $website = Get-Item "IIS:\Sites\$($role.WebsiteName)" -EA 0
    if ($website -ne $null)
    {
        $appPoolName = $website.applicationPool
        if((Get-WebAppPoolState $appPoolName).Value -ne "Stopped")
        {
            Write-Log "Stopping application pool $appPoolName..."
            Stop-WebAppPool $appPoolName
            Write-Log "Application pool stopped"
        }
        else
        {
            Write-Log "Application pool `"$appPoolName`" is already stopped"
        }
    }
}

Set-DeploymentTask start-service {
    # get service details
    $service = Get-WindowsService $role.ServiceName
    if ($service -ne $null)
    {
        Write-Log "Starting Windows service $($role.ServiceName)..."
        Start-Service -Name $role.ServiceName
        Write-Log "Service started"
    }
}

Set-DeploymentTask stop-service {
    # get service details
    $service = Get-WindowsService $role.ServiceName
    if ($service -ne $null)
    {
        Write-Log "Stopping Windows service $($role.ServiceName)..."
        Stop-Service -Name $role.ServiceName -Force
        Write-Log "Service stopped"
    }
}

Set-DeploymentTask restart -Requires start,stop {
    Write-Log "Restart deployment"
    Invoke-DeploymentTask stop
    Invoke-DeploymentTask start
}
#endregion

#region Azure tasks
function SetupAzureSubscription()
{
    if($currentContext.azureSubscription)
    {
        # subscription is already set
        return
    }

    # import modules
    Import-Module Azure

    # variables
    $subscriptionId = $config.AzureSubscriptionID
    $subscriptionCertificate = $config.AzureSubscriptionCertificate
    $subscriptionName = "DeploySubscription"

    if($subscriptionId -and $subscriptionCertificate)
    {
        # setup
        $tempFolder = [IO.Path]::GetTempPath()
        $publishSettingsFile = [System.IO.Path]::Combine($tempFolder, "azure-subscription.publishsettings")
        $publishSettingsXml = @"
<?xml version="1.0" encoding="utf-8"?>
<PublishData>
    <PublishProfile
    PublishMethod="AzureServiceManagementAPI"
    Url="https://management.core.windows.net/"
    ManagementCertificate="$subscriptionCertificate">
    <Subscription
        Id="$subscriptionId"
        Name="$subscriptionName" />
    </PublishProfile>
</PublishData>
"@

        # create publish settings file
        Write-Log "Create Azure subscription settings file"
        $sf = New-Item $publishSettingsFile -type file -force -value $publishSettingsXml

        # import subscription
        Write-Log "Import publishing settings profile"
        Import-AzurePublishSettingsFile $publishSettingsFile
        Select-AzureSubscription -SubscriptionName $subscriptionName
    }

    # do not import next time
    $currentContext.azureSubscription = $subscriptionName
}

function UpdateAzureCloudServiceConfig($configPath, $configuration)
{
    [xml]$xml = New-Object XML
    $xml.Load($configPath)

    # iterate through Roles
    foreach($role in $xml.selectnodes("//*[local-name() = 'Role']"))
    {
        $roleName = $role.Attributes["name"].Value

        # check if the number of instances configured
        if($configuration[$roleName] -ne $null)
        {
            # update the number of role instances
            $instances = $role.SelectSingleNode("*[local-name() = 'Instances']");
            $instances.Attributes["count"].Value = $configuration[$roleName]
        }

        # update role settings
        foreach($setting in $role.SelectSingleNode("*[local-name() = 'ConfigurationSettings']").SelectNodes("*[local-name() = 'Setting']"))
        {
            # common setting
            $value = $configuration[$setting.name]

            # role-specific setting
            $specificValue = $configuration["$($roleName).$($setting.name)"]
            if($specificValue -ne $null)
            {
                $value = $specificValue
            }

            if($value -ne $null)
            {
                Write-Log "Updating <ConfigurationSettings> entry `"$($setting.name)`" to `"$value`""
                $setting.value = $value
            }
        }
    }

    # save config
    $xml.Save($configPath)
}

function CreateAzureDeployment
{
    param (
        $serviceName,
        $slot,
        $label,
        $packageUrl,
        $configPath
    )

    Write-Log "Creating new $slot deployment in $serviceName"

    # create and wait
    $deployment = New-AzureDeployment -ServiceName $serviceName -Slot $slot -Label $label -Package $packageUrl -Configuration $configPath
    WaitForAllCloudServiceInstancesRunning $serviceName $slot

    # get URL
    $deployment = Get-AzureDeployment -ServiceName $serviceName -Slot $slot
    Write-Log "Deployment created, URL: $($deployment.url)"
}

function UpdateAzureDeployment
{
    param (
        $serviceName,
        $slot,
        $label,
        $packageUrl,
        $configPath
    )

    Write-Log "Upgrading $slot deployment in $serviceName"

    $deployment = Set-AzureDeployment -Upgrade -ServiceName $serviceName -Slot $slot -Label $label -Package $packageUrl -Configuration $configPath -Force
    WaitForAllCloudServiceInstancesRunning $serviceName $slot

    # get URL
    $deployment = Get-AzureDeployment -ServiceName $serviceName -Slot $slot
    Write-Log "Deployment upgraded, URL: $($deployment.url)"
}

function DeleteAzureDeployment
{
    param (
        $environment
    )

    if($environment -is [string])
    {
        $environment = Get-AzureEnvironment $environment
    }

    # setup subscription
    SetupAzureSubscription

    Write-Log "Deleting $($environment.Slot) deployment in $($environment.CloudService)"

    $deployment = Remove-AzureDeployment -Slot $environment.Slot -ServiceName $environment.CloudService -Force

    Write-Log "Deployment deleted"
}

function WaitForAllCloudServiceInstancesRunning
{
    param (
        $serviceName,
        $slot
    )

    $deployment = Get-AzureDeployment -ServiceName $serviceName -Slot $slot
    $instanceStatuses = @("") * $deployment.RoleInstanceList.Count
    do
    {
        $deployment = Get-AzureDeployment -ServiceName $serviceName -Slot $slot

        for($i = 0; $i -lt $deployment.RoleInstanceList.Count; $i++)
        {
            $instanceName = $deployment.RoleInstanceList[$i].InstanceName
            $instanceStatus = $deployment.RoleInstanceList[$i].InstanceStatus
            if ($instanceStatuses[$i] -ne $instanceStatus)
            {
                $instanceStatuses[$i] = $instanceStatus
                Write-Log "Starting Instance '$instanceName': $instanceStatus"
            }
        }
    }
    until(AllCloudServiceInstancesRunning($deployment.RoleInstanceList))
}

function AllCloudServiceInstancesRunning($roleInstanceList)
{
    foreach ($roleInstance in $roleInstanceList)
    {
        if ($roleInstance.InstanceStatus -ne "ReadyRole")
        {
            return $false
        }
    }

    return $true
}

function DownloadAzureApplicationConfiguration
{
    param (
        $configUrl,
        $configuration
    )

    $storageAccountName = $config.AzureStorageAccountName
    $storageAccountKey = $config.AzureStorageAccountKey

    if(-not $storageAccountName -or -not $storageAccountKey)
    {
        $msg = @"
"Unable to download Azure application configuration file.
Set Azure cloud storage account details in the global deployment configuration:
- Set-DeploymentConfiguration AzureStorageAccountName <storage-account-name>
- Set-DeploymentConfiguration AzureStorageAccountKey <storage-account-key>"
"@
        throw $msg
    }

    # download .cscfg file
    $configPath = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), [System.IO.Path]::GetRandomFileName())
    Write-Log "Downloading .cscfg from $configUrl to $configPath"

    # parse URL
    $blobHost = ".blob.core.windows.net/"
    $hostIdx = $configUrl.indexOf($blobHost)

    if($hostIdx -eq -1)
    {
        throw "Azure Cloud Service package must be uploaded to Azure storage blob and has URL of the form http://<account>.blob.core.windows.net/../package.zip. If you use AppVeyor CI configure custom Azure storage for your account."
    }

    $relativeUrl = $configUrl.substring($hostIdx + $blobHost.length)

    # get container and blob name
    $idx = $relativeUrl.indexOf("/")
    $containerName = $relativeUrl.substring(0, $idx)
    $blobName = $relativeUrl.substring($idx + 1)

    # download config from blob
    $blobContext = New-AzureStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey
    Get-AzureStorageBlobContent -Container $containerName -Blob $blobName -Destination $configPath -Context $blobContext | Out-Null
    
    # update .cscfg file
    if($configuration -ne $null)
    {
        UpdateAzureCloudServiceConfig $configPath $configuration
    }

    return $configPath
}

function DeployAzureApplication
{
    param (
        [Parameter(Position=0, Mandatory=$true)]
        $application,

        [Parameter(Position=1, Mandatory=$true)]
        [string]$version,

        [Parameter(Position=2, Mandatory=$true)]
        $environment
    )

    if($environment -is [string])
    {
        $environment = Get-AzureEnvironment $environment
    }

    # setup subscription
    SetupAzureSubscription

    # download configuration file
    $configPath = (DownloadAzureApplicationConfiguration $application.ConfigUrl $application.Configuration)

    # deploy
    Write-Log "Check if $($environment.Slot) deployment already exists"
    $deployment = Get-AzureDeployment -ServiceName $environment.CloudService -Slot $environment.Slot -ErrorAction SilentlyContinue
    if ($deployment.Name -ne $null)
    {
        Write-Log "$slot deployment exists"

        # should we delete or upgrade existing deployment?
        if($config.UpdateAzureDeployment)
        {
            UpdateAzureDeployment $environment.CloudService $environment.Slot $version $application.PackageUrl $configPath
        }
        else
        {
            Write-Log "Upgrade is not enabled. Re-creating $($environment.Slot) deployment."

            DeleteAzureDeployment $environment
            CreateAzureDeployment $environment.CloudService $environment.Slot $version $application.PackageUrl $configPath
        }
    }
    else
    {
        Write-Log "$($environment.Slot) deployment does not exist"

        CreateAzureDeployment $environment.CloudService $environment.Slot $version $application.PackageUrl $configPath
    }
}
#endregion

# add local environment
New-Environment local
Add-EnvironmentServer local "localhost"

# export module members
Export-ModuleMember -Function `
    Set-DeploymentConfiguration, Get-DeploymentConfiguration, `
    New-Application, Get-Application, Set-Application, Add-WebSiteRole, Add-ServiceRole, Set-WebSiteRole, Set-ServiceRole, `
    New-AzureApplication, Set-AzureApplication, `
    New-Environment, Get-Environment, Set-Environment, Add-EnvironmentServer, `
    New-AzureEnvironment, Get-AzureEnvironment, Set-AzureEnvironment, `
    Set-DeploymentTask, `
    Invoke-DeploymentTask, New-Deployment, Remove-Deployment, Restore-Deployment, Restart-Deployment, Stop-Deployment, Start-Deployment