$modules = "$home\Documents\WindowsPowerShell\Modules"
Write-Host "Installing AppRolla module into your user profile: $modules"

New-Item "$modules\AppRolla" -ItemType Directory -Force | Out-Null
(New-Object Net.WebClient).DownloadFile("https://raw.github.com/AppVeyor/AppRolla/master/AppRolla.psm1", "$modules\AppRolla\AppRolla.psm1")