function New-Application
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position=0, Mandatory=$true)]
        $Name
    )

    Write-Output "New-Application $Name"

    $app = @{ "test" = "app" }

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
        [scriptblock]$script = $null,

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
    $script
}