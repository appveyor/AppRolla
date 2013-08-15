# config
$config = @{}
$config.TaskExecutionTimeout = 300 # 5 min
$config.ApplicationsPath = "c:\applications"
$config.KeepPreviousVersions = 5

# connection defaults
$config.UseSSL = $true
$config.SkipCACheck = $true
$config.SkipCNCheck = $true

# context
$script:context = @{}
$currentContext = $script:context
$currentContext.applications = @{}
$currentContext.environments = @{}
$currentContext.tasks = @{}
$currentContext.remoteSessions = @{}

function Set-DeploymentConfiguration
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
        Name = $Name
        BasePath = $BasePath
        Configuration = $Configuration
        Roles = @{}
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
        $Configuration = @{}
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

function Add-ServiceRole
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
                Write-Output "[$($context.Server.ServerAddress)][$taskName] $(Get-Date -f g) - $message"
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

        [Parameter(Mandatory=$true)][alias("From")]
        $Environment,

        [Parameter(Mandatory=$false)]
        [switch]$Serial = $false
    )

    Invoke-DeploymentTask remove $environment $application $version -serial $serial
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

    Invoke-DeploymentTask rollback $environment $application $version -serial $serial
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

    Invoke-DeploymentTask restart $environment $application -serial $serial
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

    Invoke-DeploymentTask stop $environment $application -serial $serial
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

    Invoke-DeploymentTask start $environment $application -serial $serial
}

# --------------------------------------------
#
#   Helper functions
#
# --------------------------------------------
function Get-AppVeyorPackageUrl
{
    param (
        $applicationName,
        $applicationVersion,
        $artifactName
    )

    return "https://ci.appveyor.com/api/projects/artifact?projectName=$applicationName`&versionName=$applicationVersion`&artifactName=$artifactName"
}


# --------------------------------------------
#
#   Private functions
#
# --------------------------------------------
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

        $useSSL = $config.UseSSL
        $skipCACheck = $config.SkipCACheck
        $skipCNCheck = $config.SkipCNCheck

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

        Export-ModuleMember -Function Push-TaskCallStack, Pop-TaskCallStack, Write-Log, Expand-Zip, Test-RoleApplicableToServer, `
            Update-ApplicationConfig, Get-TempFileName, Get-WindowsService, Get-VersionFromFileName, Get-VersionFromDirectory
    }
}

# --------------------------------------------
#
#   "Deploy" tasks
#
# --------------------------------------------

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
        $basePath = $role.BasePath
    }
    elseif($context.Application.BasePath)
    {
        $basePath = Join-Path $context.Application.BasePath $role.Name
    }
    elseif($context.Configuration.applicationsPath)
    {
        $basePath = $context.Configuration.applicationsPath
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

    # determine the location of application folder
    Invoke-DeploymentTask setup-role-folder

    # $role.BasePath - base path for role versions
    # $role.RootPath - role version installation root (application root)
    # $role.Versions - the list of installed versions (latest first)

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

    # determine the location of application folder
    Invoke-DeploymentTask setup-role-folder

    # $role.BasePath - base path for role versions
    # $role.RootPath - role version installation root (application root)
    # $role.Versions - the list of installed versions (latest first)

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


# --------------------------------------------
#
#   "Remove" tasks
#
# --------------------------------------------

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


# --------------------------------------------
#
#   "Rollback" tasks
#
# --------------------------------------------

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


# --------------------------------------------
#
#   "Start", "Stop", "Restart" tasks
#
# --------------------------------------------

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

Export-ModuleMember -Function `
    Set-DeploymentConfiguration, `
    New-Application, Add-WebSiteRole, Add-ServiceRole, Set-DeploymentTask, `
    New-Environment, Add-EnvironmentServer, `
    Invoke-DeploymentTask, New-Deployment, Remove-Deployment, Restore-Deployment, Restart-Deployment, Stop-Deployment, Start-Deployment, `
    Get-AppVeyorPackageUrl