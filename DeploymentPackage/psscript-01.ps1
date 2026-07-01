Param (
    [Parameter(Mandatory = $true)]
    [string]
    $AzureUserName,

    [string]
    $AzurePassword,

    [string]
    $AzureTenantID,

    [string]
    $AzureSubscriptionID,

    [string]
    $ODLID,

    [string]
    $InstallCloudLabsShadow,

    [string]
    $DeploymentID,

    [string]
    $vmAdminUsername,

    [string]
    $vmAdminPassword,

    [string]
    $trainerUserName,

    [string]
    $trainerUserPassword
)

Start-Transcript -Path C:\WindowsAzure\Logs\CloudLabsCustomScriptExtension.txt -Append
[Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls
[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls" 

Function CreateCredFile($AzureUserName, $AzurePassword, $AzureTenantID, $AzureSubscriptionID, $DeploymentID)
{
    $WebClient = New-Object System.Net.WebClient
    $WebClient.DownloadFile("https://experienceazure.blob.core.windows.net/templates/cloudlabs-common/AzureCreds.txt","C:\LabFiles\AzureCreds.txt")
    $WebClient.DownloadFile("https://experienceazure.blob.core.windows.net/templates/cloudlabs-common/AzureCreds.ps1","C:\LabFiles\AzureCreds.ps1")
    
    New-Item -ItemType directory -Path C:\LabFiles -force

    (Get-Content -Path "C:\LabFiles\AzureCreds.txt") | ForEach-Object {$_ -Replace "AzureUserNameValue", "$AzureUserName"} | Set-Content -Path "C:\LabFiles\AzureCreds.txt"
    (Get-Content -Path "C:\LabFiles\AzureCreds.txt") | ForEach-Object {$_ -Replace "AzurePasswordValue", "$AzurePassword"} | Set-Content -Path "C:\LabFiles\AzureCreds.txt"
    (Get-Content -Path "C:\LabFiles\AzureCreds.txt") | ForEach-Object {$_ -Replace "AzureTenantIDValue", "$AzureTenantID"} | Set-Content -Path "C:\LabFiles\AzureCreds.txt"
    (Get-Content -Path "C:\LabFiles\AzureCreds.txt") | ForEach-Object {$_ -Replace "AzureSubscriptionIDValue", "$AzureSubscriptionID"} | Set-Content -Path "C:\LabFiles\AzureCreds.txt"
    (Get-Content -Path "C:\LabFiles\AzureCreds.txt") | ForEach-Object {$_ -Replace "DeploymentIDValue", "$DeploymentID"} | Set-Content -Path "C:\LabFiles\AzureCreds.txt"
             
    (Get-Content -Path "C:\LabFiles\AzureCreds.ps1") | ForEach-Object {$_ -Replace "AzureUserNameValue", "$AzureUserName"} | Set-Content -Path "C:\LabFiles\AzureCreds.ps1"
    (Get-Content -Path "C:\LabFiles\AzureCreds.ps1") | ForEach-Object {$_ -Replace "AzurePasswordValue", "$AzurePassword"} | Set-Content -Path "C:\LabFiles\AzureCreds.ps1"
    (Get-Content -Path "C:\LabFiles\AzureCreds.ps1") | ForEach-Object {$_ -Replace "AzureTenantIDValue", "$AzureTenantID"} | Set-Content -Path "C:\LabFiles\AzureCreds.ps1"
    (Get-Content -Path "C:\LabFiles\AzureCreds.ps1") | ForEach-Object {$_ -Replace "AzureSubscriptionIDValue", "$AzureSubscriptionID"} | Set-Content -Path "C:\LabFiles\AzureCreds.ps1"
    (Get-Content -Path "C:\LabFiles\AzureCreds.ps1") | ForEach-Object {$_ -Replace "DeploymentIDValue", "$DeploymentID"} | Set-Content -Path "C:\LabFiles\AzureCreds.ps1"

    Copy-Item "C:\LabFiles\AzureCreds.txt" -Destination "C:\Users\Public\Desktop"
}

CreateCredFile $AzureUserName $AzurePassword $AzureTenantID $AzureSubscriptionID $DeploymentID

# Ensure base folder exists
if (!(Test-Path "C:\LabFiles")) {
    New-Item -ItemType Directory -Path "C:\LabFiles" | Out-Null
}

Function updateVMShadowFile
{
#Replace vmAdminUsernameValue with VM Admin UserName in script content 
$drivepath="C:\Users\Public\Documents"
(Get-Content -Path "$drivepath\Shadow.ps1") | ForEach-Object {$_ -Replace "vmAdminUsernameValue", "$vmAdminUsername"} | Set-Content -Path "$drivepath\Shadow.ps1"
#Update random password
net user $trainerUserName $trainerUserPassword
}
updateVMShadowFile

Function RunModernVmValidator
{
cmd.exe --% /c sc create "Spektra CloudLabs VM Agent" BinPath=C:\CloudLabs\Validator\VMAgent\Spektra.CloudLabs.VMAgent.exe start= auto
cmd.exe --% /c sc start "Spektra CloudLabs VM Agent"
}
RunModernVmValidator

Function Ensure-VSCodeInstalled
{
    $attempt = 0
    while ($attempt -lt 2) {
        $cmd = Get-Command code -ErrorAction SilentlyContinue
        if ($cmd) {
            Write-Output "VS Code already installed: $($cmd.Path)"
            return
        }
        Write-Output "Installing/upgrading VS Code (attempt $($attempt + 1))..."
        choco upgrade vscode -y -force
        Start-Sleep -Seconds 5
        $attempt++
    }
    $final = Get-Command code -ErrorAction SilentlyContinue
    if (-not $final) { Write-Output "VS Code installation failed after retries." }
}

Function Ensure-AzureCliInstalled
{
    $attempt = 0
    while ($attempt -lt 2) {
        $cmd = Get-Command az -ErrorAction SilentlyContinue
        if ($cmd) {
            Write-Output "Azure CLI already installed: $($cmd.Path)"
            return
        }
        Write-Output "Installing/upgrading Azure CLI (attempt $($attempt + 1))..."
        choco upgrade azure-cli -y -force
        Start-Sleep -Seconds 5
        $attempt++
    }
    $final = Get-Command az -ErrorAction SilentlyContinue
    if (-not $final) { Write-Output "Azure CLI installation failed after retries." }
}

Function Ensure-PipUpgraded
{
    $attempt = 0
    while ($attempt -lt 2) {
        Write-Output "Upgrading pip (attempt $($attempt + 1))..."
        python -m pip install --upgrade pip
        Start-Sleep -Seconds 5
        try { $pv = & python -m pip --version 2>$null } catch { $pv = $null }
        if ($pv) { Write-Output "pip present: $pv"; return }
        $attempt++
    }
    Write-Output "pip upgrade failed after retries."
}

Ensure-VSCodeInstalled
Ensure-AzureCliInstalled
Ensure-PipUpgraded

New-Item -ItemType Directory -Path "C:\AllFiles" | Out-Null

$WebClient = New-Object System.Net.WebClient
$WebClient.DownloadFile("https://github.com/MicrosoftLearning/mslearn-azure-ai/raw/main/downloads/python/postgresql-build-agent-python.zip","C:\LabFiles\postgresql-build-agent-python.zip")

function unzip($filepath) {
    $file = $filepath
    $destination = "C:\AllFiles\"
    $shell = new-object -com shell.application
    $zip = $shell.NameSpace($file)
    Write-Host "postgresql-build-agent-python folder is unzipped"
    foreach ($item in $zip.items()) {
        $shell.Namespace($destination).copyhere($item)
    }
}

unzip("C:\LabFiles\postgresql-build-agent-python.zip")

Stop-Transcript
Disable-ScheduledTask -TaskName "runuserdata"
Stop-ScheduledTask -TaskName "runuserdata"