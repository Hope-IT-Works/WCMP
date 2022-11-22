<#
    WCMP Setup
    https://github.com/Hope-IT-Works/WCMP/
#>

param (
    [Parameter()][string]$Path,
    [Parameter()][switch]$Headless,
    [Parameter()][switch]$Force,
    [Parameter()][switch]$SkipPHP,
    [Parameter()][switch]$SkipMariaDB
)

class WCMP {
    [bool]$IsHeadless
    [bool]$IsForced
    [bool]$IncludePHP
    [bool]$IncludeMariaDB
    # Default config with default values (used when specified values are not available or incorrect)
    $DefaultConfig = @{
        Path = (Get-Location).Path
    }

    # Config that will be used to configure the setup
    $Config = @{
        Path = $Path
    }

    # Every folder in this array will be created
    $DirectoryTree = @(
        "cache",
        "caddy",
        "mariadb",
        "php",
        "www"
    )

    WCMP ($Headless, $Force, $SkipPHP, $SkipMariaDB) {
        $this.IsHeadless = $Headless
        $this.IsForced = $Force
        $this.IncludePHP = !$SkipPHP
        $this.IncludeMariaDB = !$SkipMariaDB
    }

    [Int] ReadUserInputMenu ($OptionsArray) {
        $Result = $null
        do {
            $Result = Read-Host -Prompt "Please enter an ID"
            if($Result -ge 0 -and $Result -lt $OptionsArray.Count){
                break
            }
            Write-Host -ForegroundColor Red "Please enter an valid ID."
        } while ($Result -lt 0 -and $Result -ge $OptionsArray.Count)
        return $Result
    }

    [Boolean] ReadUserInputBoolean ($Prompt) {
        $Result = $null
        if($null -eq $Prompt){
            $Prompt = "(y/n)"
        } else {
            $Prompt += $Prompt + " (y/n)"
        }
        do {
            $Result = Read-Host -Prompt $Prompt
            if($Result -ne "y" -or $Result -ne "n"){
                Write-Host -ForegroundColor Yellow 'Please enter "y" for yes or "n" for no.'
            }
        } while ($Result -eq "y" -or $Result -eq "n")
        if($Result -eq "y"){
            $Result = $true
        }
        if($Result -eq "n"){
            $Result = $false
        }
        return $Result
    }

    [void] Info ($Message) {
        if($null -ne $Message){
            Write-Host -ForegroundColor Cyan ('[INFO]: ' + $Message)
        }
    }

    [void] Warn ($Message) {
        if($null -ne $Message){
            Write-Host -ForegroundColor Yellow ('[WARN]: ' + $Message)
        }
    }

    [void] Error ($Message) {
        if($null -ne $Message){
            Write-Host -ForegroundColor Red ('[ERROR]: ' + $Message)
            if(!($this.ReadUserInputBoolean('Do you want to continue?'))){
                exit
            }
        }
    }

    [void] Fatal ($Message) {
        if($null -eq $Message){
            $Message = 'Reason unknown.'
        }
        Write-Host -ForegroundColor Red ("[FATAL]: " + $Message)
        exit
    }

    [void] ReadContinue () {
        if($this.IsHeadless()){
            if($this.IsForced()){
                Write-Host -ForegroundColor Yellow ('[FORCED] Ignoring prior warning due to forced execution.')
            } else {
                $this.Fatal('Terminating due to prior warning. Execute again with "-Force" parameter to keep running.')
            }
        } else {
            if(!($this.ReadUserInputBoolean('Do you want to proceed anyway?'))){
                exit
            }
        }
    }

    [string] DownloadRequest ($URL) {
        $URL = $URL -as [System.Uri]
        $Result = ''
        if($null -ne $URL.AbsoluteUri -and $URL.Scheme -match '[http|https]'){
            $URL = $URL.AbsoluteUri
            try {
                $Result = (Invoke-WebRequest -UseBasicParsing -Uri $URL).Content
            } catch {
                $this.Error('(DownloadRequest) failed: Request failed, URL: "'+$URL+'"')
            }
        } else {
            $this.Error('(DownloadRequest) failed: URL not valid, URL: "'+$URL+'"')
        }
        return $Result
    }

    [bool] DownloadFile ($URL,$FilePath) {
        $URL = $URL -as [System.Uri]
        $Path = Split-Path -Path $FilePath -Parent
        $Result = $false
        if($null -ne $URL.AbsoluteUri -and $URL.Scheme -match '[http|https]'){
            $URL = $URL.AbsoluteUri
            if(Test-Path -Path $Path){
                try {
                    Invoke-WebRequest -UseBasicParsing -Uri $URL -OutFile $FilePath
                    if(Test-Path -Path $FilePath){
                        $Result = $true
                    } else {
                        $this.Error('(DownloadFile) failed: File does not exist, URL: "'+$URL+'", Path: "'+$FilePath+'"')
                    }
                } catch {
                    $this.Error('(DownloadFile) failed: Request failed, URL: "'+$URL+'", Path: "'+$FilePath+'"')
                }
            } else {
                $this.Error('(DownloadFile) failed: Parent directory of file path does not exist, URL: "'+$URL+'", Path: "'+$FilePath+'"')
            }
        } else {
            $this.Error('(DownloadFile) failed: URL not valid, URL: "'+$URL+'", Path: "'+$FilePath+'"')
        }
        return $Result
    }
}

$WCMP = [WCMP]::new($Headless, $Force, $SkipPHP, $SkipMariaDB)

# Stop setup if OS is not supported
if(!([System.Environment]::Is64BitOperatingSystem) -or !(([System.Environment]::OSVersion).Platform -eq "Win32NT")){
    $WCMP.Fatal("OS is not supported (only 64-Bit Windows is supported)")
}

# Set root path for setup with fallback to the default path
if(!(Test-Path -PathType Container -Path $WCMP.Config.Path)){
    $WCMP.Config.Path = $WCMP.DefaultConfig.Path
}

# Checks if root directory contains no other directories
if((Get-ChildItem -Path $WCMP.Config.Path -Directory).Count -gt 0){
    $WCMP.Warn('The root directory contains already other directories!')
    $WCMP.ReadContinue()
}

# Generate directory tree in root directory
$WCMP.DirectoryTree | ForEach-Object {
    $WCMP_SubDirectory = $WCMP.Config.Path + "\" + $_
    if(Test-Path -Path $WCMP_SubDirectory){
        $WCMP.Warn('The subdirectory "'+$_+'" already exists!')
        $WCMP.ReadContinue()
    } else {
        try {
            New-Item -Path $WCMP_SubDirectory -ItemType Directory
        } catch {
            $WCMP.Fatal('The subdirectory "'+$_+'" could not be created.')
        }
    }
}

# Caddy
$WCMP.Info('Requesting Caddy...')
$Caddy_Resource = New-Object -TypeName System.Collections.ArrayList
try {
    $Caddy_Resources = $WCMP.DownloadRequest('https://api.github.com/repos/caddyserver/caddy/releases/latest') | ConvertFrom-Json
} catch {
    $WCMP.Fatal('GitHub API returned invalid JSON!')
}
$Caddy_Version = $Caddy_Resources.name
$Caddy_Resources.assets | Where-Object -FilterScript {$_.content_type -eq "application/zip" -and $_.name -match "windows" -and $_.name -match "amd64"} | ForEach-Object {
    $Caddy_Resource.Add($_) | Out-Null
}
if($Caddy_Resource.Count -le 0){
    $this.Fatal('No compatible variant of Caddy found!')
}
$Caddy_Resource            = $Caddy_Resource[0].browser_download_url
$Caddy_Path                = $WCMP.Config.Path + '\cache'
$Caddy_FilePath            = $Caddy_Path + '\caddy.zip'
$Caddy_CachePath           = $WCMP.Config.Path + '\cache\caddy'
$Caddy_CacheFilePath       = $Caddy_CachePath + '\caddy.exe'
$Caddy_DestinationPath     = $WCMP.Config.Path + '\caddy'
$Caddy_DestinationFilePath = $Caddy_DestinationPath + '\caddy.exe'
$WCMP.Info('Caddy requested.')
$WCMP.Info('Downloading Caddy...')
if($WCMP.DownloadFile($Caddy_Resource, $Caddy_FilePath)){
    try {
        $WCMP.Info('Caddy download complete.')
        $WCMP.Info('Extracting Caddy...')
        Expand-Archive -Path $Caddy_FilePath -DestinationPath $Caddy_CachePath
        $WCMP.Info('Caddy extracted.')
    } catch {
        $this.Error('Caddy could not be extracted.')
    }
} else {
    $WCMP.Fatal('Caddy download failed.')
}
if(Test-Path -Path $Caddy_CacheFilePath){
    try {
        Move-Item -Path $Caddy_CacheFilePath -Destination $Caddy_DestinationFilePath
        $WCMP.Info('Caddy is available at: "'+$Caddy_DestinationFilePath+'"')
    } catch {
        $WCMP.Error('Caddy could not be moved from "'+$Caddy_CacheFilePath+'" to "'+$Caddy_DestinationFilePath+'"')
    }
} else {
    $WCMP.Error('Caddy binary could not be found. (looking for "'+$Caddy_CacheFilePath+'")')
}

# PHP
if($WCMP.IncludePHP){
    try {
        $PHP_Resources_URL = 'https://windows.php.net/downloads/releases/'
        $PHP_Resources = (Invoke-WebRequest -UseBasicParsing -Uri $PHP_Resources_URL).Links.href | Where-Object -FilterScript {$_ -match ("/downloads/releases/php-")}
    } catch {
        $WCMP.Error('(PHPRequest) failed: Request failed, URL "'+$PHP_Resources_URL+'"')
    }
    $PHP_Versions = New-Object -TypeName System.Collections.ArrayList
    foreach($Resource in $PHP_Resources){
        if($Resource -notmatch 'x64' -or $Resource -match 'src' -or $Resource -match 'test' -or $Resource -match 'debug' -or $Resource -match 'nts' -or $Resource -match 'devel'){
            continue
        } else {
            $PHP_Version = New-Object -TypeName PSCustomObject
            $PHP_Version | Add-Member -MemberType NoteProperty -Name 'ID' -Value $PHP_Versions.Count
            $PHP_Version | Add-Member -MemberType NoteProperty -Name 'Name' -Value ($Resource.Split("/")[3].Split("-")[1]+"-"+$Resource.Split("/")[3].Split("-")[4].Split(".")[0])
            $PHP_Version | Add-Member -MemberType NoteProperty -Name 'URL' -Value ("https://windows.php.net"+$Resource)
            $PHP_Versions.Add($PHP_Version) | Out-Null
        }
    }
    if($PHP_Versions.Count -le 0){
        $WCMP.Fatal('No PHP-Versions available, please create a issue at https://github.com/Hope-IT-Works/WCMP')
    } else {
        $WCMP.Info($PHP_Versions.Count+' PHP-Versions available:')
        $PHP_Versions | Format-Table -Property 'ID','Name'
        $PHP_Version = $PHP_Versions[$WCMP.ReadUserInputMenu($PHP_Versions)]
        $WCMP.Info('PHP-Version "'+$PHP_Version.Name.Split('-')[0]+'" was selected.')
        $PHP_Resource            = $PHP_Version.URL
        $PHP_Path                = $WCMP.Config.Path + '\cache'
        $PHP_FilePath            = $PHP_Path + '\php-'+$PHP_Version.Name+'.zip'
        $PHP_DestinationPath     = $WCMP.Config.Path + '\php'
        if($WCMP.DownloadFile($PHP_Resource, $PHP_FilePath)){
            try {
                $WCMP.Info('PHP download complete.')
                $WCMP.Info('Extracting PHP...')
                Expand-Archive -Path $PHP_FilePath -DestinationPath $PHP_DestinationPath
                $WCMP.Info('PHP extracted.')
            } catch {
                $this.Error('PHP could not be extracted.')
            }
        } else {
            $WCMP.Fatal('PHP download failed.')
        }
        $PHP_Version = $PHP_Version.Name.Split('-')[0]
    }
} else {
    $WCMP.Info('Skipped PHP installation.')
}

# MariaDB
if($WCMP.IncludeMariaDB){
    try {
        $MariaDB_Resources = $WCMP.DownloadRequest('https://downloads.mariadb.org/rest-api/mariadb/') | ConvertFrom-Json
    } catch {
        $WCMP.Fatal('MariaDB API returned invalid JSON!')
    }
    $MariaDB_Resources = $MariaDB_Resources.major_releases | Where-Object -FilterScript { $_.release_status -eq 'Stable' }
    if($MariaDB_Resources.Count -le 0){
        $WCMP.Fatal('No stable release for MariaDB found!')
    }
    $MariaDB_Resource = $MariaDB_Resources[0]
    try {
        $MariaDB_Resource = $WCMP.DownloadRequest('https://downloads.mariadb.org/rest-api/mariadb/'+$MariaDB_Resource.release_id+'/latest') | ConvertFrom-Json
    } catch {
        $WCMP.Fatal('MariaDB API returned invalid JSON!')
    }
    # https://downloads.mariadb.org/rest-api/mariadb/10.10/latest
    # https://downloads.mariadb.org/rest-api/cpu
    # https://downloads.mariadb.org/rest-api/os
} else {
    $WCMP.Info('Skipped MariaDB installation.')
}