# load configuration script
$path = Split-Path -Parent $MyInvocation.MyCommand.Definition
. (Join-Path $path config.ps1)

# deploy to Staging
New-Deployment MyApp 1.0.0 -To Staging