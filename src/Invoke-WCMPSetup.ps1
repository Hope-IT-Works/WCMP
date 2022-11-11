<#
    WCMP Setup
    https://github.com/Hope-IT-Works/WCMP/
#>

param (
    [Parameter()][string]$Path,
    [Parameter()][switch]$Headless
)

class WCMP {
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
        "caddy",
        "mariadb",
        "php",
        "www"
    )

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

    [void] Warn ($Message) {
        if($null -ne $Message){
            Write-Host -ForegroundColor Yellow ("[WARN]: " + $Message)
        }
    }

    [void] Error ($Message) {
        if($null -ne $Message){
            Write-Host -ForegroundColor Red ("[ERROR]: " + $Message)
            if(!($this.ReadUserInputBoolean("Do you want to continue?"))){
                exit
            }
        }
    }

    [void] Fatal ($Message) {
        if($null -eq $Message){
            Write-Host -ForegroundColor Red ("[FATAL]: " + "Reason unknown.")
        } else {
            Write-Host -ForegroundColor Red ("[FATAL]: " + $Message)
        }
        exit
    }
}

$WCMP = [WCMP]::new()

# Stop setup if OS is not supported
if(!([System.Environment]::Is64BitOperatingSystem) -or !(([System.Environment]::OSVersion).Platform -eq "Win32NT")){
    $WCMP.Fatal("OS is not supported (only 64-Bit Windows is supported)")
}

# Set root path for setup with fallback to the default path
if(!(Test-Path -PathType Container -Path $WCMP.Config.Path)){
    $WCMP.Config.Path = $WCMP.DefaultConfig.Path
}

$WCMP.DirectoryTree | ForEach-Object {
    $WCMP_SubDirectory = $WCMP.Config.Path + "\" + $_
    if(Test-Path -Path $WCMP_SubDirectory){
        Write-Host -ForegroundColor Yellow 'The subdirectory "'+$_+'" already exists!'
        if(!($WCMP.ReadUserInputBoolean("Do you want to proceed anyway?"))){
            exit
        }
    } else {
        try {
            New-Item -Path $WCMP_SubDirectory -ItemType Directory
        } catch {
            $WCMP.Fatal("Root-Directory could not be created.")
        }
    }
}