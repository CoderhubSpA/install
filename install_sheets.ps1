param (
    [string]$sheetsName = "sheets",
    [string]$githubUsername = "",
    [string]$ghToken = ""
)

function Check-GitHubCLI {
    # Check if gh CLI is installed
    $ghPath = (Get-Command gh -ErrorAction SilentlyContinue).Path

    if (-not $ghPath) {
        Write-Host "GitHub CLI (gh) is not installed. Installing..." -ForegroundColor Magenta
        winget install --id GitHub.cli -e
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
    $allowedVersions = @("7.4.*", "8.1.*")
    $phpVersion = & "$phpVersionFile" -v | Select-String -Pattern "PHP (\d+\.\d+\.\d+)"
    $phpVersion = $phpVersion.Matches.Groups[1].Value
    Write-Host "Checking for XAMPP version... Found version $phpVersion" -ForegroundColor Magenta
    foreach ($version in $allowedVersions) {
        if ($phpVersion -match $version) {
            Write-Host "XAMPP version $version is installed." -ForegroundColor Green
            return $true
        }
    }

    Write-Error "None of the expected XAMPP versions is installed."
    return $false
}

function Add-PHP-Mysql-To-Path {
    $phpPath = "C:\xampp\php\"
    $mysqlPath = "C:\xampp\mysql\bin\"

    $currentPath = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine)

    if ($currentPath -notlike "*$phpPath*") {
        $currentPath += ";$phpPath"
        Write-Host "PHP path is added to the system PATH environment variable." -ForegroundColor Magenta
    }
    else {
        Write-Host "PHP path is already in the system PATH environment variable." -ForegroundColor Green
    }

    if ($currentPath -notlike "*$mysqlPath*") {
        $currentPath += ";$mysqlPath"
        Write-Host "MySQL path is added to the system PATH environment variable." -ForegroundColor Magenta
    }
    else {
        Write-Host "MySQL path is already in the system PATH environment variable." -ForegroundColor Green
    }

    [System.Environment]::SetEnvironmentVariable("Path", $currentPath, [System.EnvironmentVariableTarget]::Machine)
    Write-Host "XAMPP php and mysql paths are added to the system PATH environment variable." -ForegroundColor Yellow
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
    } else {
        Write-Host "Line already exists in hosts file." -ForegroundColor Green
    }
}


function Check-XAMPP-Installation {
    param (
        [string]$xamppPath
    )

    $phpVersionFile = "$xamppPath\php\php.exe"

    if (-not (Test-Path $phpVersionFile)) {
        Write-Error "XAMPP is not installed at $xamppPath."
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
        if (-not (Check-GitHubCLI)) {
            exit 1
        }
        # Check if gh CLI is authenticated
        if (-not (Check-GH-Auth)) {
            exit 1
        }
        # Get GitHub username using gh CLI
        $githubUsername = gh api user --jq '.login'

        if (-not $githubUsername) {
            Write-Error "Failed to retrieve GitHub username."
            exit 1
        }

        Write-Host "GitHub username: $githubUsername"

        # Retrieve the current authentication token
        $ghToken = gh auth token

        if (-not $ghToken) {
            Write-Error "Failed to retrieve GitHub personal access token."
            exit 1
        }

        Write-Host "GitHub personal access token generated." -ForegroundColor Yellow
    }

    return @{
        "githubUsername" = $githubUsername
        "ghToken" = $ghToken
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
        exit 1
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
        exit 1
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
        exit 1
    }
    else {
        # Append the virtual host configurations to the httpd.conf content
        $httpdConfContent += $virtualHostConfig
    }

    # Write the updated content back to the httpd.conf file
    Set-Content -Path $httpdConfPath -Value $httpdConfContent
    Write-Host "Apache configuration updated successfully. Please restart Apache for the changes to take effect." -ForegroundColor Cyan
}

function Install-ComposerDependencies {
    param (
        [string]$envPath
    )

    Write-Host "Installing Composer dependencies (form builder)..." -ForegroundColor Magenta
    if (Test-Path $envPath) {
        Write-Host "Cleaning old vendor for SheetsFormBuilderProvider (./resources/js/vendor/FormBuilder_js)" -ForegroundColor Magenta
        Remove-Item -Recurse -Force ./resources/js/vendor/FormBuilder_js
        Write-Host "Done" -ForegroundColor Yellow
        Write-Host "Publishing new SheetsFormBuilderProvider." -ForegroundColor Magenta
        php artisan vendor:publish --provider="paupololi\sheetsformbuilder\SheetsFormBuilderProvider"
    } else {
        Write-Host "Could not install Composer dependencies, please do it manually (publish_form_builder)" -ForegroundColor Red
    }
}

##################################################################################
#                                    Main script                                 #
##################################################################################


if (-not (Check-Admin)) {
    Write-Error "Script is not running as administrator. Open the terminal as administrator and run the script again."
    exit 1    
}

$credentials = Get-GitHubCredentials -githubUsername $githubUsername -ghToken $ghToken
$githubUsername = $credentials["githubUsername"]
$ghToken = $credentials["ghToken"]

# Check if XAMPP is installed
$xamppPath = "C:\xampp"
if (-not (Check-XAMPP-Installation -xamppPath $xamppPath)) {
    exit 0
}

# Configure Composer auth.json
Configure-ComposerAuthJson -githubUsername $githubUsername -ghToken $ghToken

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

# Install sheets form builder
Install-ComposerDependencies -envPath $envPath

Write-Host "Installation completed successfully. Now configure .env manually and create the database before running the application." -ForegroundColor Cyan
