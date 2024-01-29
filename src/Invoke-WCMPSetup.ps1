<#
    WCMP Setup
    https://github.com/Hope-IT-Works/WCMP/
#>

param (
    [Parameter()][string]$Path,
    [Parameter()][switch]$Headless,
    [Parameter()][switch]$Force,
    [Parameter()][switch]$SkipPHP,
    [Parameter()][switch]$SkipMariaDB,
    [Parameter()][switch]$SkipWinSW
)

class WCMP {
    [bool]$IsHeadless
    [bool]$IsForced
    [bool]$IncludePHP
    [bool]$IncludeMariaDB
    [bool]$IncludeWinSW
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
        "winsw",
        "www"
    )

    WCMP ($Headless, $Force, $SkipPHP, $SkipMariaDB, $SkipWinSW) {
        $this.IsHeadless = $Headless
        $this.IsForced = $Force
        $this.IncludePHP = !$SkipPHP
        $this.IncludeMariaDB = !$SkipMariaDB
        $this.IncludeWinSW = !$SkipWinSW
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
        $Result = ''
        $ReadUserState = $true
        if($null -eq $Prompt){
            $Prompt = "(y/n)"
        } else {
            $Prompt = $Prompt + " (y/n)"
        }
        do {
            $Result = Read-Host -Prompt $Prompt
            if($Result -ne "y" -or $Result -ne "n"){
                Write-Host -ForegroundColor Yellow 'Please enter "y" for yes or "n" for no.'
            }

            if($Result -eq "y" -or $Result -eq "n"){
                if($Result -eq "y"){
                    $Result = $true
                    $ReadUserState = $false
                }
                if($Result -eq "n"){
                    $Result = $false
                    $ReadUserState = $false
                }
            } else {
                Write-Host -ForegroundColor Yellow 'Please enter "y" for yes or "n" for no.'
            }
        } while ($ReadUserState)
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
            Write-Host -ForegroundColor Red ('[ERRO]: ' + $Message)
            if(!($this.ReadUserInputBoolean('Do you want to continue?'))){
                exit
            }
        }
    }

    [void] Fatal ($Message) {
        if($null -eq $Message){
            $Message = 'Reason unknown.'
        }
        Write-Host -ForegroundColor Red ("[FATA]: " + $Message)
        exit
    }

    [void] ReadContinue () {
        if($this.IsHeadless){
            if($this.IsForced){
                Write-Host -ForegroundColor Yellow ('[FORCED] Ignoring prior warning due to forced execution.')
            } else {
                $this.Fatal('Terminating due to prior warning. Execute again with "-Force" parameter to keep running.')
            }
        } else {
            if($this.ReadUserInputBoolean('Do you want to proceed anyway?')){
                $this.Info('Proceeding anyway...')
            } else {
                $this.Info('Terminating...')
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
                    $ProgressPreferenceCache = $ProgressPreference
                    $ProgressPreference = 'SilentlyContinue'
                    Invoke-WebRequest -UseBasicParsing -Uri $URL -OutFile $FilePath
                    $ProgressPreference = $ProgressPreferenceCache
                    Remove-Variable -Name ProgressPreferenceCache
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

$WCMP = [WCMP]::new($Headless, $Force, $SkipPHP, $SkipMariaDB, $SkipWinSW)

$WCMP.Info('   _      __  _____  __  ___  ___   ')
$WCMP.Info('  | | /| / / / ___/ /  |/  / / _ \  ')
$WCMP.Info('  | |/ |/ / / /__  / /|_/ / / ___/  ')
$WCMP.Info('  |__/|__/  \___/ /_/  /_/ /_/      ')
$WCMP.Info('====================================')

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
            $WCMP.Info('Creating directory "'+$_+'"')
            New-Item -Path $WCMP_SubDirectory -ItemType Directory | Out-Null
        } catch {
            $WCMP.Fatal('The subdirectory "'+$_+'" could not be created.')
        }
    }
}

# Caddy
$WCMP.Info('---------------------------')
$WCMP.Info('           CADDY           ')
$WCMP.Info('---------------------------')
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
$Caddy_CaddyfileResource   = 'https://raw.githubusercontent.com/Hope-IT-Works/WCMP/main/src/caddy/Caddyfile'
$Caddy_CaddyfileFilePath   = $Caddy_DestinationPath + '\Caddyfile'
$WCMP.Info('Caddy requested.')
$WCMP.Info('Downloading Caddy '+$Caddy_Version+'...')
if($WCMP.DownloadFile($Caddy_Resource, $Caddy_FilePath)){
    try {
        $WCMP.Info('Caddy '+$Caddy_Version+' download complete.')
        $WCMP.Info('Extracting Caddy '+$Caddy_Version+'...')
        Expand-Archive -Path $Caddy_FilePath -DestinationPath $Caddy_CachePath
        $WCMP.Info('Caddy '+$Caddy_Version+' extracted.')
    } catch {
        $this.Error('Caddy '+$Caddy_Version+' could not be extracted.')
    }
} else {
    $WCMP.Fatal('Caddy '+$Caddy_Version+' download failed ('+$Caddy_Resource+')')
}
if(Test-Path -Path $Caddy_CacheFilePath){
    try {
        Move-Item -Path $Caddy_CacheFilePath -Destination $Caddy_DestinationFilePath
        $WCMP.Info('Caddy '+$Caddy_Version+' is available at: "'+$Caddy_DestinationFilePath+'"')
    } catch {
        $WCMP.Error('Caddy '+$Caddy_Version+' could not be moved from "'+$Caddy_CacheFilePath+'" to "'+$Caddy_DestinationFilePath+'"')
    }
} else {
    $WCMP.Error('Caddy '+$Caddy_Version+' binary could not be found. (looking for "'+$Caddy_CacheFilePath+'")')
}
$WCMP.Info('Downloading Caddyfile...')
if($WCMP.DownloadFile($Caddy_CaddyfileResource, $Caddy_CaddyfileFilePath)){
    $WCMP.Info('Caddyfile download complete.')
} else {
    $WCMP.Fatal('Caddyfile download failed ('+$Caddy_CaddyfileResource+')')
}
if(Test-Path -Path $Caddy_CaddyfileFilePath){
    $WCMP.Info('Caddyfile is available at: "'+$Caddy_CaddyfileFilePath+'"')
} else {
    $WCMP.Error('Caddyfile could not be found. (looking for "'+$Caddy_CaddyfileFilePath+'")')
}

# PHP
if($WCMP.IncludePHP){
    $WCMP.Info('---------------------------')
    $WCMP.Info('            PHP            ')
    $WCMP.Info('---------------------------')
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
        $WCMP.Info([string]$PHP_Versions.Count+' PHP-Versions available:')
        $PHP_Versions | Format-Table -Property 'ID','Name'
        $PHP_Version = $PHP_Versions[$WCMP.ReadUserInputMenu($PHP_Versions)]
        $WCMP.Info('PHP-Version "'+$PHP_Version.Name.Split('-')[0]+'" was selected.')
        $PHP_Resource            = $PHP_Version.URL
        $PHP_Path                = $WCMP.Config.Path + '\cache'
        $PHP_FilePath            = $PHP_Path + '\php-'+$PHP_Version.Name+'.zip'
        $PHP_DestinationPath     = $WCMP.Config.Path + '\php'
        $WCMP.Info('Downloading PHP...')
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
            $WCMP.Fatal('PHP download failed ('+$PHP_Resource+')')
        }
        $PHP_Version = $PHP_Version.Name.Split('-')[0]
    }
} else {
    $WCMP.Info('Skipped PHP installation.')
}

# MariaDB
if($WCMP.IncludeMariaDB){
    $WCMP.Info('---------------------------')
    $WCMP.Info('          MariaDB          ')
    $WCMP.Info('---------------------------')
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
    try {
        $MariaDB_Resource = $MariaDB_Resource.releases.PSObject.Properties.Value.files
    } catch {
        $WCMP.Fatal('No files for latest release of MariaDB found! A')
    }
    try {
        $MariaDB_Resource = $MariaDB_Resource | Where-Object -FilterScript {$_.OS -eq "Windows" -and $_.package_type -eq "ZIP file" -and $_.file_name -notmatch "debug"}
    } catch {
        $WCMP.Fatal('No file for latest release of MariaDB found! B')
    }
    $MariaDB_Resource = @($MariaDB_Resource)
    if($MariaDB_Resource.Count -eq 1){
        $MariaDB_Resource        = $MariaDB_Resource.file_download_url
        $MariaDB_Path            = $WCMP.Config.Path + '\cache'
        $MariaDB_FilePath        = $MariaDB_Path + '\' + $MariaDB_Resource.Split('/')[-1]
        $MariaDB_CachePath       = $WCMP.Config.Path + '\cache\mariadb'
        $MariaDB_DestinationPath = $WCMP.Config.Path + '\mariadb'
        $MariaDB_InstallDBPath   = $MariaDB_DestinationPath + '\bin\mysql_install_db.exe'
        $MariaDB_
        $WCMP.Info('Downloading MariaDB...')
        if($WCMP.DownloadFile($MariaDB_Resource, $MariaDB_FilePath)){
            try {
                $WCMP.Info('MariaDB download complete.')
                $WCMP.Info('Extracting MariaDB...')
                Expand-Archive -Path $MariaDB_FilePath -DestinationPath $MariaDB_CachePath -Force
                $WCMP.Info('MariaDB extracted.')
            } catch {
                $WCMP.Fatal('MariaDB could not be extracted.')
            }
            try {
                $WCMP.Info('Moving MariaDB to destination...')
                Move-Item -Path ($MariaDB_CachePath+'\'+$MariaDB_Resource.Split('/')[-1].Replace('.zip','')+'\*') -Destination $MariaDB_DestinationPath -Force
                $WCMP.Info('MariaDB was moved.')
            } catch {
                $WCMP.Fatal('MariaDB could not be moved to destination.')
            }
        } else {
            $WCMP.Fatal('MariaDB download failed ('+$MariaDB_Resource+')')
        }
    } else {
        $WCMP.Fatal('No file for latest release of MariaDB found!')
    }
    if(Test-Path -Path $MariaDB_InstallDBPath){
        $WCMP.Info('Initializing MariaDB...')
        cmd /c $MariaDB_InstallDBPath
        $WCMP.Info('MariaDB was initialized.')
    } else {
        $WCMP.Fatal('MariaDB could not be initialized.')
    }
} else {
    $WCMP.Info('Skipped MariaDB installation.')
}

# WinSW
if($WCMP.IncludeWinSW){
    $WCMP.Info('---------------------------')
    $WCMP.Info('           WinSW           ')
    $WCMP.Info('---------------------------')
    $WCMP.Info('Requesting WinSW...')
    $WinSW_Resource = New-Object -TypeName System.Collections.ArrayList
    try {
        $WinSW_Resources = $WCMP.DownloadRequest('https://api.github.com/repos/winsw/winsw/releases/latest') | ConvertFrom-Json
    } catch {
        $WCMP.Fatal('GitHub API returned invalid JSON!')
    }
    $WinSW_Version = $WinSW_Resources.name
    $WinSW_Resources.assets | Where-Object -FilterScript {$_.content_type -eq "application/x-msdownload" -and $_.name -match "NET461"} | ForEach-Object {
        $WinSW_Resource.Add($_) | Out-Null
    }
    if($WinSW_Resource.Count -le 0){
        $WCMP.Fatal('No compatible variant of WinSW found!')
    }
    $WinSW_Resource                = $WinSW_Resource[0].browser_download_url
    $WinSW_DestinationPath         = $WCMP.Config.Path + '\winsw'
    $WinSW_DestinationFilePath     = $WinSW_DestinationPath + '\winsw.exe'
    $WinSW_Service_CaddyResource   = 'https://raw.githubusercontent.com/Hope-IT-Works/WCMP/main/src/winsw/caddy.xml'
    $WinSW_Service_CaddyFilePath   = $Caddy_DestinationPath + '\winsw_caddy.xml'
    $WinSW_Service_PHPResource     = 'https://raw.githubusercontent.com/Hope-IT-Works/WCMP/main/src/winsw/php.xml'
    $WinSW_Service_PHPFilePath     = $PHP_DestinationPath + '\winsw_php.xml'
    $WinSW_Service_MariaDBResource = 'https://raw.githubusercontent.com/Hope-IT-Works/WCMP/main/src/winsw/mariadb.xml'
    $WinSW_Service_MariaDBFilePath = $MariaDB_DestinationPath + '\bin\winsw_mariadb.xml'
    $WCMP.Info('WinSW requested.')
    $WCMP.Info('Downloading WinSW '+$WinSW_Version+'...')
    if($WCMP.DownloadFile($WinSW_Resource, $WinSW_DestinationFilePath)){
        $WCMP.Info('WinSW '+$WinSW_Version+' download complete.')
    } else {
        $WCMP.Fatal('WinSW '+$WinSW_Version+' download failed ('+$WinSW_Resource+')')
    }
    if(Test-Path -Path $WinSW_DestinationFilePath){
        $WCMP.Info('WinSW '+$WinSW_Version+' is available at: "'+$WinSW_DestinationFilePath+'"')
    } else {
        $WCMP.Fatal('WinSW '+$WinSW_Version+' binary could not be found. (looking for "'+$WinSW_DestinationFilePath+'")')
    }

    $WCMP.Info('Downloading Caddy service config...')
    if($WCMP.DownloadFile($WinSW_Service_CaddyResource, $WinSW_Service_CaddyFilePath)){
        $WCMP.Info('Caddy service config download complete.')
    } else {
        $WCMP.Fatal('Caddy service config download failed ('+$WinSW_Service_CaddyResource+')')
    }
    if(Test-Path -Path $Caddy_CaddyfileFilePath){
        try {
            $WCMP.Info('Setting Caddy service working directory...')
            $WinSW_Service_CaddyConfig = Get-Content -Path $WinSW_Service_CaddyFilePath -Encoding utf8
            $WinSW_Service_CaddyConfig = $WinSW_Service_CaddyConfig -replace '##WORKINGDIRECTORY##', ($WCMP.Config.Path+'\caddy')
            $WinSW_Service_CaddyConfig | Set-Content -Path $WinSW_Service_CaddyFilePath -Encoding utf8
            $WCMP.Info('Caddy service working directory set.')
        } catch {
            $WCMP.Fatal('Caddy service working directory could not be set.')
        }
        $WCMP.Info('Caddy service config is available at: "'+$WinSW_Service_CaddyFilePath+'"')
    } else {
        $WCMP.Fatal('Caddy service config could not be found. (looking for "'+$WinSW_Service_CaddyFilePath+'")')
    }
    try {
        $WCMP.Info('Installing Caddy service (this may trigger a UAC prompt, please accept)...')
        cmd /c $WinSW_DestinationFilePath install $WinSW_Service_CaddyFilePath
        $WCMP.Info('Caddy service installed.')
    } catch {
        $WCMP.Fatal('Caddy service could not be installed. (have you accepted the UAC prompt? try running the script as administrator)')
    }

    if($WCMP.IncludePHP){
        $WCMP.Info('Downloading PHP service config...')
        if($WCMP.DownloadFile($WinSW_Service_PHPResource, $WinSW_Service_PHPFilePath)){
            $WCMP.Info('PHP service config download complete.')
        } else {
            $WCMP.Fatal('PHP service config download failed ('+$WinSW_Service_PHPResource+')')
        }
        if(Test-Path -Path $Caddy_CaddyfileFilePath){
            try {
                $WCMP.Info('Setting PHP service working directory...')
                $WinSW_Service_PHPConfig = Get-Content -Path $WinSW_Service_PHPFilePath -Encoding utf8
                $WinSW_Service_PHPConfig = $WinSW_Service_PHPConfig -replace '##WORKINGDIRECTORY##', ($WCMP.Config.Path+'\php')
                $WinSW_Service_PHPConfig | Set-Content -Path $WinSW_Service_PHPFilePath -Encoding utf8
                $WCMP.Info('PHP service working directory set.')
            } catch {
                $WCMP.Fatal('PHP service working directory could not be set.')
            }
            $WCMP.Info('PHP service config is available at: "'+$WinSW_Service_PHPFilePath+'"')
        } else {
            $WCMP.Fatal('PHP service config could not be found. (looking for "'+$WinSW_Service_PHPFilePath+'")')
        }
        try {
            $WCMP.Info('Installing PHP service (this may trigger a UAC prompt, please accept)...')
            cmd /c $WinSW_DestinationFilePath install $WinSW_Service_PHPFilePath
            $WCMP.Info('PHP service installed.')
        } catch {
            $WCMP.Fatal('PHP service could not be installed. (have you accepted the UAC prompt? try running the script as administrator)')
        }
    }

    if($WCMP.IncludeMariaDB){
        $WCMP.Info('Downloading MariaDB service config...')
        if($WCMP.DownloadFile($WinSW_Service_MariaDBResource, $WinSW_Service_MariaDBFilePath)){
            $WCMP.Info('MariaDB service config download complete.')
        } else {
            $WCMP.Fatal('MariaDB service config download failed ('+$WinSW_Service_MariaDBResource+')')
        }
        if(Test-Path -Path $Caddy_CaddyfileFilePath){
            try {
                $WCMP.Info('Setting MariaDB service working directory...')
                $WinSW_Service_MariaDBConfig = Get-Content -Path $WinSW_Service_MariaDBFilePath -Encoding utf8
                $WinSW_Service_MariaDBConfig = $WinSW_Service_MariaDBConfig -replace '##WORKINGDIRECTORY##', ($WCMP.Config.Path+'\mariadb\bin')
                $WinSW_Service_MariaDBConfig | Set-Content -Path $WinSW_Service_MariaDBFilePath -Encoding utf8
                $WCMP.Info('MariaDB service working directory set.')
            } catch {
                $WCMP.Fatal('MariaDB service working directory could not be set.')
            }
            $WCMP.Info('MariaDB service config is available at: "'+$WinSW_Service_MariaDBFilePath+'"')
        } else {
            $WCMP.Fatal('MariaDB service config could not be found. (looking for "'+$WinSW_Service_MariaDBFilePath+'")')
        }
        try {
            $WCMP.Info('Installing MariaDB service (this may trigger a UAC prompt, please accept)...')
            cmd /c $WinSW_DestinationFilePath install $WinSW_Service_MariaDBFilePath
            $WCMP.Info('MariaDB service installed.')
        } catch {
            $WCMP.Fatal('MariaDB service could not be installed. (have you accepted the UAC prompt? try running the script as administrator)')
        }
    }
} else {
    $WCMP.Info('Skipped WinSW installation.')
}

try {
    $WCMP.Info('Removing WCMP download cache directory...')
    Remove-Item -Path ($WCMP.Config.Path + '\cache') -Force -Recurse
    $WCMP.Info('WCMP download cache directory removed.')
} catch {
    $WCMP.Error('WCMP download cache directory could not be removed.')
}

$WCMP.Info('---------------------------')
$WCMP.Info('WCMP installation finished!')
$WCMP.Info('---------------------------')
