param (
    [string]$sheetsName = "sheets",
    [string]$githubUsername = "",
    [string]$ghToken = ""
)

function Refresh-Session-Path {
    # Retrieve the current session's PATH environment variable
    $currentSessionPath = $env:PATH -split ';'

    # Retrieve the machine-level PATH environment variable
    $machinePath = [System.Environment]::GetEnvironmentVariable("PATH", [System.EnvironmentVariableTarget]::Machine) -split ';'

    # Merge both PATH values, ensuring no duplicates
    $mergedPath = $currentSessionPath + $machinePath | Sort-Object -Unique

    # Update the current session's PATH environment variable
    $env:PATH = [string]::Join(';', $mergedPath)
}
function Add-PATH {
    param (
        [string]$addpath
    )
    $machinePath = [System.Environment]::GetEnvironmentVariable("PATH", [System.EnvironmentVariableTarget]::Machine)

    if ($machinePath -notlike "*$addpath*") {
        $machinePath += ";$addpath"
        [System.Environment]::SetEnvironmentVariable("PATH", $machinePath, [System.EnvironmentVariableTarget]::Machine)
        Write-Host "Added $addpath to the system PATH environment variable." -ForegroundColor Magenta
    }
    else {
        Write-Host "$addpath is already in the system PATH environment variable." -ForegroundColor Green
    }
    Refresh-Session-Path
}

function Find-GitHubCLI {
    # Check if gh CLI is installed
    $ghPath = (Get-Command gh -ErrorAction SilentlyContinue).Path

    if (-not $ghPath) {
        Write-Host "GitHub CLI (gh) is not installed. Installing..." -ForegroundColor Magenta
        Invoke-Expression "winget install --id GitHub.cli -e --accept-package-agreements --accept-source-agreements "
        $ghPath = (Get-Command gh -ErrorAction SilentlyContinue).Path
        if (-not $ghPath) {
            Write-Error "Failed to install GitHub CLI (gh)."
            return $false
        }
        Write-Host "Finished installing GitHub CLI (gh)." -ForegroundColor Yellow
    }

    Write-Host "GitHub CLI (gh) is installed." -ForegroundColor Green
    return $true
}

function Check-Admin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Check-GH-Scopes {
    Write-Host "Checking GitHub CLI (gh) authentication scopes..." -ForegroundColor Magenta
    $authCheck = gh auth status 2>&1
    return ($authCheck -match "repo" -and $authCheck -match "read:packages")
}

function Check-GH-Auth {
    if (Check-GH-Scopes) {
        Write-Host "GitHub CLI (gh) is already authenticated with the required scopes." -ForegroundColor Green
    }
    else {
        Write-Host "GitHub CLI (gh) is not authenticated with the required scopes. Authenticating..." -ForegroundColor Magenta
        
        # Use Start-Process to run the gh auth login command
        Start-Process -FilePath "gh" -ArgumentList "auth login -h github.com -s repo,read:packages" -NoNewWindow -Wait
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to authenticate with the required scopes."
            return $false
        }
        Write-Host "Finished authenticating GitHub CLI (gh)." -ForegroundColor Yellow
    }
    Write-Host "GitHub CLI (gh) is authenticated." -ForegroundColor Green
    return $true
}

function Check-XAMPP-Version {
    param (
        [string]$phpVersionFile
    )
    $allowedVersions = @("8.1.*")
    $phpVersion = & "$phpVersionFile" -v | Select-String -Pattern "PHP (\d+\.\d+\.\d+)"
    $phpVersion = $phpVersion.Matches.Groups[1].Value
    Write-Host "Checking for XAMPP version... Found version $phpVersion" -ForegroundColor Magenta
    foreach ($version in $allowedVersions) {
        if ($phpVersion -match $version) {
            Write-Host "XAMPP version $version is installed." -ForegroundColor Green
            return $true
        }
    }

    Write-Host "None of the expected XAMPP versions is installed." -ForegroundColor Red
    return $false
}

function Add-PHP-Mysql-To-Path {
    $phpPath = "C:\xampp\php\"
    $mysqlPath = "C:\xampp\mysql\bin\"
    Add-PATH -addpath $phpPath
    Add-PATH -addpath $mysqlPath

}

function Enable-PHP-Extension {
    param (
        [string]$extensionName
    )
    $phpIniPath = "C:\xampp\php\php.ini"
    $extension = "extension=$extensionName"
    # Read the content of the php.ini file
    $phpIniContent = Get-Content -Path $phpIniPath

    # Uncomment the extension line if it exists
    $phpIniContent = $phpIniContent -replace ";$extension", $extension

    # Write the updated content back to the php.ini file
    Set-Content -Path $phpIniPath -Value $phpIniContent

    Write-Host "Extension '$extension' has been enabled in php.ini." -ForegroundColor Green
}

function Configure-Npmrc {
    param (
        [string]$ghToken
    )

    $npmrcPath = "$env:USERPROFILE\.npmrc"
    $registryLine = "@CoderhubSpA:registry=https://npm.pkg.github.com"
    $authTokenLine = "//npm.pkg.github.com/:_authToken=$ghToken"


    # Check if .npmrc file exists
    if (-not (Test-Path $npmrcPath)) {
        Write-Host ".npmrc file does not exist. Creating..." -ForegroundColor Magenta
        New-Item -ItemType File -Path $npmrcPath | Out-Null
    }

    
    $npmrcFileContent = Get-Content -Path $npmrcPath
    
    $registryPattern = [regex]::Escape($registryLine)
    $foundRegistry = $npmrcFileContent | Select-String -Pattern $registryPattern



    # Add registry and authentication token to .npmrc if not already present
    if (-not $foundRegistry) {
        Add-Content -Path $npmrcPath -Value "`n$registryLine"
        Write-Host "Registry line added to .npmrc." -ForegroundColor Yellow
    }
    else {
        Write-Host "Registry line already exists in .npmrc." -ForegroundColor Green
    }

    $authTokenPattern = [regex]::Escape($registryLine)
    $foundAuthToken = $npmrcFileContent | Select-String -Pattern $authTokenPattern

    if (-not $foundAuthToken) {
        Add-Content -Path $npmrcPath -Value "`n$authTokenLine"
        Write-Host "Authentication token line added to .npmrc." -ForegroundColor Yellow
    }
    else {
        Write-Host "Authentication token line already exists in .npmrc." -ForegroundColor Green
    }

    Write-Host "Registry and authentication token added to .npmrc." -ForegroundColor Yellow
}

function Add-HostsEntry {
    param (
        [string]$sheetsName
    )

    # Define the path to the hosts file
    $hostsFilePath = "C:\Windows\System32\drivers\etc\hosts"

    # Define the line to add
    $lineToAdd = "127.0.0.1 $sheetsName.local"
    # Read the content of the hosts file into a variable
    $hostsFileContent = Get-Content -Path $hostsFilePath

    # Escape the pattern to ensure it is correctly interpreted
    $pattern = [regex]::Escape($lineToAdd.Trim())

    # Search for the pattern in the hosts file content
    $foundHost = $hostsFileContent | Select-String -Pattern $pattern

    # Add the line to the hosts file if it doesn't already exist
    if (-not $foundHost) {
        Add-Content -Path $hostsFilePath -Value "`n$lineToAdd"
        Write-Host "Line added to hosts file." -ForegroundColor Yellow
    }
    else {
        Write-Host "Line already exists in hosts file." -ForegroundColor Green
    }
}


function Find-XAMPP-And-Add-To-Path {
    param (
        [string]$xamppPath
    )

    $phpVersionFile = "$xamppPath\php\php.exe"

    if (-not (Test-Path $phpVersionFile)) {
        Write-Host "XAMPP is not installed at $xamppPath." -ForegroundColor Red
        return $false
    }

    if (-not (Check-XAMPP-Version -phpVersionFile $phpVersionFile)) {
        return $false
    }
    Add-PHP-Mysql-To-Path

    return $true
}

function Get-GitHubCredentials {
    param (
        [string]$githubUsername,
        [string]$ghToken
    )

    $manualGithub = $githubUsername -and $ghToken

    if (-not $manualGithub) {
        # Check if gh CLI is installed
        if (-not (Find-GitHubCLI)) {
            return 1
        }
        # Check if gh CLI is authenticated
        if (-not (Check-GH-Auth)) {
            return 1
        }
        # Get GitHub username using gh CLI
        $githubUsername = gh api user --jq '.login'

        if (-not $githubUsername) {
            Write-Error "Failed to retrieve GitHub username."
            return 1
        }

        Write-Host "GitHub username: $githubUsername"

        # Retrieve the current authentication token
        $ghToken = gh auth token

        if (-not $ghToken) {
            Write-Error "Failed to retrieve GitHub personal access token."
            return 1
        }

        Write-Host "GitHub personal access token generated." -ForegroundColor Yellow
    }

    return @{
        "githubUsername" = $githubUsername
        "ghToken"        = $ghToken
    }
}

function Configure-ComposerAuthJson {
    param (
        [string]$githubUsername,
        [string]$ghToken
    )

    $authJsonPath = "$env:APPDATA\Composer\auth.json"

    $authJsonContent = @{
        "http-basic" = @{
            "github.com" = @{
                "username" = $githubUsername
                "password" = $ghToken
            }
        }
    } | ConvertTo-Json -Depth 3

    # Ensure the directory exists
    $authJsonDirectory = [System.IO.Path]::GetDirectoryName($authJsonPath)
    if (-not (Test-Path -Path $authJsonDirectory)) {
        New-Item -ItemType Directory -Path $authJsonDirectory -Force
    }

    Set-Content -Path $authJsonPath -Value $authJsonContent

    Write-Host "Composer auth.json configured with GitHub personal access token." -ForegroundColor Yellow
}

function Clone-And-Cd-Into-Repository {
    param (
        [string]$repositoryUrl,
        [string]$destinationPath
    )

    git clone $repositoryUrl $destinationPath

    if ($LASTEXITCODE -eq 0) {
        Write-Host "Repository cloned successfully." -ForegroundColor Yellow
    }
    else {
        Write-Error "Failed to clone the repository."
        return 1
    }

    Set-Location $destinationPath
}

function Copy-EnvFile {
    param (
        [string]$envExamplePath,
        [string]$envPath
    )

    if (-not (Test-Path $envPath)) {
        Copy-Item -Path $envExamplePath -Destination $envPath
        Write-Host ".env file created." -ForegroundColor Yellow
    }
    else {
        Write-Host ".env file already exists." -ForegroundColor Green
    }
    # Ensure SESSION_SECURE_COOKIE is set to false in the .env file
    # Read the content of the .env file
    $envContent = Get-Content -Path $envPath

    # Replace SESSION_SECURE_COOKIE=true with SESSION_SECURE_COOKIE=false
    $updatedEnvContent = $envContent -replace "SESSION_SECURE_COOKIE=true", "SESSION_SECURE_COOKIE=false"

    # Write the updated content back to the .env file
    Set-Content -Path $envPath -Value $updatedEnvContent

    Write-Host "SESSION_SECURE_COOKIE has been set to false in the .env file." -ForegroundColor Green

}

function Configure-ApacheVirtualHost {
    param (
        [string]$sheetsName
    )

    # Define the path to the httpd.conf file
    $httpdConfPath = "C:\xampp\apache\conf\httpd.conf"

    # Check if the file exists
    if (-Not (Test-Path $httpdConfPath)) {
        Write-Host "The httpd.conf file does not exist at the specified path: $httpdConfPath. Please configure it manually." -ForegroundColor Cyan
        return 1
    }

    # Read the content of the httpd.conf file
    $httpdConfContent = Get-Content -Path $httpdConfPath

    # Replace User and Group settings
    $myUser = whoami
    $httpdConfContent = $httpdConfContent -replace 'User daemon', "User $myUser"
    $httpdConfContent = $httpdConfContent -replace 'Group daemon', "Group staff"

    # Uncomment the Include line for virtual hosts
    $httpdConfContent = $httpdConfContent -replace '# Include etc/extra/httpd-vhosts.conf', 'Include etc/extra/httpd-vhosts.conf'


    # Define the virtual host configurations
    $virtualHostConfig = @"
<VirtualHost *:80>
    ServerName $sheetsName.local
    DocumentRoot "$PWD\public"
    <Directory "$PWD\public">
        Options Indexes FollowSymLinks Includes ExecCGI
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog "logs/$sheetsName.local-error_log"
</VirtualHost>
"@

    # Check if the virtual host configurations already exist
    if ($httpdConfContent -match "ServerName $sheetsName.local") {
        # Update the DocumentRoot and Directory paths
        Write-Host "Virtual host configurations already exist. You may need to manually update it." -ForegroundColor Cyan
        return 1
    }
    else {
        # Append the virtual host configurations to the httpd.conf content
        $httpdConfContent += $virtualHostConfig
    }

    # Write the updated content back to the httpd.conf file
    Set-Content -Path $httpdConfPath -Value $httpdConfContent
    Write-Host "Apache configuration updated successfully. Please restart Apache for the changes to take effect." -ForegroundColor Cyan
}


function Composer-Is-Installed {
    $composerPath = (Get-Command composer -ErrorAction SilentlyContinue).Path
    return $composerPath
}

function Find-Composer {
    $composerPath = (Get-Command composer -ErrorAction SilentlyContinue).Path
    Write-Host "Search for composer: $composerPath"
    return $composerPath
}

function Find-NPM {
    $npmPath = (Get-Command npm -ErrorAction SilentlyContinue).Path
    return $npmPath
}

function Install-Composer {
    $composerPath = "C:\composer"
    Write-Host "Installing Composer..." -ForegroundColor Magenta
    php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
    php -r "if (hash_file('sha384', 'composer-setup.php') === 'dac665fdc30fdd8ec78b38b9800061b4150413ff2e3b6f88543c636f7cd84f6db9189d43a81e5503cda447da73c7e5b6') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
    php composer-setup.php
    php -r "unlink('composer-setup.php');"

    if (-not (Test-Path -Path $composerPath)) {
        New-Item -ItemType Directory -Path $composerPath -Force
    }
    Move-Item composer.phar "$composerPath\composer.phar" -Force
    
    # Create composer.bat file with the specified content
    $composerBatContent = @"
@echo OFF
:: in case DelayedExpansion is on and a path contains ! 
setlocal DISABLEDELAYEDEXPANSION
php "%~dp0composer.phar" %*
"@
    $composerBatPath = "$composerPath\composer.bat"
    Set-Content -Path $composerBatPath -Value $composerBatContent
    
    
    Add-PATH -addpath $composerPath

    
    Write-Host "Composer installed." -ForegroundColor Yellow
    return $true
}

function Install-XAMPP {
    Write-Host "Installing XAMPP..." -ForegroundColor Magenta
    Invoke-Expression "winget install -e --id ApacheFriends.Xampp.8.1 --accept-package-agreements --accept-source-agreements "
    Write-Host "Finished installing XAMPP." -ForegroundColor Yellow
    Find-XAMPP-And-Add-To-Path -xamppPath "C:\xampp"
    Refresh-Session-Path
    return $true
}

function Install-NPM {
    Write-Host "Installing npm..." -ForegroundColor Magenta
    Invoke-Expression "winget install -e --id=OpenJS.NodeJS -v "20.7.0" --accept-package-agreements --accept-source-agreements "
    Write-Host "Finished installing npm." -ForegroundColor Yellow
    if (-not (Find-NPM-And-Add_to_path -npmPath "C:\Program Files\nodejs")) {
        return $false
    }
    Refresh-Session-Path
    return $true
}
function Find-NPM-And-Add_to_path {
    param (
        [string]$npmPath
    )

    if (-not (Test-Path $npmPath)) {
        Write-Host "npm is not installed at $npmPath." -ForegroundColor Red
        return $false
    }

    Add-PATH -addpath $npmPath
    return $true
}

##################################################################################
#                                    Main script                                 #
##################################################################################


try {
    if (-not (Check-Admin)) {
        Write-Error "Script is not running as administrator. Open the terminal as administrator and run the script again."
        return 1    
    }

    $credentials = Get-GitHubCredentials -githubUsername $githubUsername -ghToken $ghToken
    $githubUsername = $credentials["githubUsername"]
    $ghToken = $credentials["ghToken"]
    # Check if XAMPP is installed
    if (-not (Find-XAMPP-And-Add-To-Path -xamppPath "C:\xampp")) {
        Write-Host "XAMPP is not installed. Installing..." -ForegroundColor Magenta
        if (-not (Install-XAMPP)) {
            Write-Host "Failed to install XAMPP." -ForegroundColor Red
            return 1
        }
    }

    Enable-PHP-Extension -extensionName "ldap"
    Enable-PHP-Extension -extensionName "gd"
    Enable-PHP-Extension -extensionName "sodium"


    # update PATH
    Refresh-Session-Path
    # Check if Composer is installed
    if (-not (Find-Composer)) {
        Write-Host "Composer is not installed. Installing..." -ForegroundColor Magenta
        if (-not (Install-Composer)) {
            Write-Host "Failed to install Composer." -ForegroundColor Red
            return 1
        }
    }

    # Configure Composer auth.json
    Configure-ComposerAuthJson -githubUsername $githubUsername -ghToken $ghToken
    # check if npm is installed
    if (-not (Find-NPM)) {
        if (-not (Install-NPM)) {
            Write-Host "npm could not be installed. Please install it manually." -ForegroundColor Red
            return 1
        }
    }


    # Add registry and authentication token to .npmrc if not already present
    Configure-Npmrc -ghToken $ghToken

    # Clone the repository and cd into it
    $repositoryUrl = "https://github.com/CoderhubSpA/sheets.git"
    $destinationPath = $sheetsName
    Clone-And-Cd-Into-Repository -repositoryUrl $repositoryUrl -destinationPath $destinationPath

    # Configure Apache virtual hosts file (httpd.conf)
    Configure-ApacheVirtualHost -sheetsName $sheetsName

    # Add an entry to the hosts file
    Add-HostsEntry -sheetsName $sheetsName

    # Copy .env.example to .env
    $envExamplePath = "$PWD\.env.example"
    $envPath = "$PWD\.env"

    Copy-EnvFile -envExamplePath $envExamplePath -envPath $envPath

    composer install
    npm i
    
    Write-Host "Installation completed successfully. Now configure .env manually and create the database before running the application." -ForegroundColor Cyan

}
catch {
    Write-Host $_ -ForegroundColor Red
}
##### TODO
# instalar xampp con winget
# instalar composer?
# actualizar PATH luego de ponerle cosas con $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", [System.EnvironmentVariableTarget]::Machine)