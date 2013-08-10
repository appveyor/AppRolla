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
        $Name
    )

    Write-Output "New-Application $Name"

    $app = @{ "name" = $Name }

    # output to pipeline
    $app
}


function Add-WebsiteRole
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
        $Application,

        [Parameter(Mandatory=$true)]
        $Name,

        [Parameter(Mandatory=$true)]
        $PackageUrl
    )

    Write-Output "Add-WebsiteRole"

    # add role info to the application config
    # ...
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

        [Parameter(Mandatory=$true)]
        $PackageUrl
    )

    Write-Output "Add-ServiceRole"

    # add role info to the application config
    # ...
}


function Add-DeploymentTask
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
        $Application,

        [Parameter(Position=1, Mandatory=$false)]
        [scriptblock]$Action = $null,

        [Parameter(Mandatory=$false)]
        [switch]$BeforeDeploy = $false,
        
        [Parameter(Mandatory=$false)]
        [switch]$AfterRollback = $false,
        
        [Parameter(Mandatory=$false)]
        $Version,

        [Parameter(Mandatory=$false)]
        $ApplicationName,

        [Parameter(Mandatory=$false)]
        $Role,

        [Parameter(Mandatory=$false)]
        $Node
    )

    Write-Output "New-DeploymentTask"

    $Application
    $Action
}


function New-Environment
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position=0, Mandatory=$true)]
        $Name,

        [Parameter(Mandatory=$false)]
        [switch]$Default = $false
    )

    Write-Output "New-Environment $Name"

    $environment = @{ "name" = $Name }

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
        $ServerAddress,

        [Parameter(Mandatory=$false)]
        [array]$Roles,
        
        [Parameter(Mandatory=$false)]
        [switch]$Primary = $false
    )

    Write-Output "Add-EnvironmentServer $ServerAddress"
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