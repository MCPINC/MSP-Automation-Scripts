#---Parameters
param(
    [string]$SetupDownloader=''
)
#---Variables [General]
$Info = {
<*************************************************************************************************************************
*  Synopsis: Deploy Bitdefender GravityZone
*  Description:

    > Uses parameter string to pass filename with square brackets (define parameter in Ninja)
    > Checks for temporary directory and if missing, creates one in C:\Temp
    > Adds regkey to disable IE first run setup (prevents downloads if it was never run before)
    > Checks PowerShell version and executes correct cmdlet for downloading app installer
    > Downloads app installer and outputs a temporary filename without square brackets
    > Renames app installer to correct filename using parameter
    > Runs app installer with arguments defined
    > Deletes temporary folder after installation is complete

*  Created: 23-06-01 by Tawhid Chowdhury [NOC Manager]
*  Updated: 23-06-26 by Tawhid Chowdhury [NOC Manager]
*  Version: 3.0
*  Log

    > 23-06-04  Added Test-Path for temp directory
    > 23-06-24  Added if/else for PowerShell version to execute correct cmdlet to download app installer
    > 23-06-26  Added function Confirm-Service to check if BDGZ or S1 service is installed and terminate if true
                Added function Confirm-AppInstall to check if BDGZ service exists after attempted install
*************************************************************************************************************************
}
$VerbosePreference = "Continue"
$TempDirectory = "C:\Temp\BDGZ"
$PowerShellVersion = $PSVersionTable.PSVersion
#---Varilables [App Specific]
$App = "Bitdefender GravityZone"
$DownloadApp = "https://cloud.gravityzone.bitdefender.com/Packages/BSTWIN/0/$SetupDownloader"
$Installer = "$SetupDownloader"
$TempFileName = "bdgz_temp.exe"
$TempFilePath = Join-Path -Path $TempDirectory -ChildPath $TempFileName
$RenamedFilePath = Join-Path -Path $TempDirectory -ChildPath $Installer
$ServiceName_BDGZ = “EPProtectedService”
$ServiceName_S1 = "SentinelAgent"
$Arg = "/bdparams /silent"

###---Writes script informational text to console---###
function Write-Info {
    Write-Host $Info
}

###---Checks if Bitdefender or S1 service exists---###
function Confirm-Service {
    Write-Verbose "Checking if $ServiceName_BDGZ or $ServiceName_S1 exists."
    if (Get-Service $ServiceName_BDGZ -ErrorAction SilentlyContinue) {
        Write-Verbose "$ServiceName_BDGZ exists, $App is already installed. Terminating script."
        exit
    } elseif (Get-Service $ServiceName_S1 -ErrorAction SilentlyContinue) {
        Write-Verbose "$ServiceName_S1 exists, $App will not be installed. Terminating script."
        exit
    }
    else {
        Write-Verbose "$ServiceName_BDGZ does not exists, continuing script."
    }
}

###---Creates temporary directory---###
function Set-TempPath {
    Write-Verbose "Checking if $TempDirectory exists."
    if(Test-Path -Path $TempDirectory) {
        Write-Verbose "$TempDirectory exists."
    } else {
        Write-Verbose "Creating $TempDirectory."
        New-Item -Path $TempDirectory -ItemType "directory"
        Write-Verbose "$TempDirectory created."
    }
}

###---Downloads and Installs BDGZ---###
function Install-App {
    Write-Verbose "Downloading $App installer to $TempDirectory."
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Internet Explorer\Main" -Name "DisableFirstRunCustomize" -Value 2
    if($PowerShellVersion -lt "3.0") {
        Import-Module BitsTransfer
        Start-BitsTransfer -Source $DownloadApp -Destination $TempFilePath
        Move-Item -LiteralPath $TempFilePath $RenamedFilePath
    } else {
        [Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
        Invoke-WebRequest -Uri $DownloadApp -UseBasicParsing -OutFile $TempFilePath
        Rename-Item -LiteralPath $TempFilePath -NewName $RenamedFilePath
    }
    Write-Verbose "$App has finished downloading."
    Write-Verbose "Installing $App."
    Start-Process -FilePath $RenamedFilePath -ArgumentList $Arg -wait
}

###---Checks if Bitdefender service exists after attempted install---###
function Confirm-AppInstall {
    if (Get-Service $ServiceName_BDGZ -ErrorAction SilentlyContinue) {
        Write-Verbose "$ServiceName_BDGZ exists, $App has been installed."
        Remove-TempPath
    } else {
        Write-Verbose "$App has not been installed due to an error. Please attempt manual installation."
    }
}

###---Removes temporary directory---###
function Remove-TempPath {
    Write-Verbose "Deleting temporary directory folder."
    Remove-Item $TempDirectory -recurse -force
    Write-Verbose "Temporary directory has been deleted."
}

Write-Info
Confirm-Service
Set-TempPath
Install-App
Confirm-AppInstall