# Configuration des paramètres
$ocsServer = "http://10.29.126.31/" # Adresse du serveur OCS Inventory
$apiEndpoint = "https://10.29.126.31/track-it/index.php/Pull"
$apiKey = "CLE_API"  # Si requis

# Récupération des informations système
$hostname = $env:COMPUTERNAME
$osInfo = Get-WmiObject Win32_OperatingSystem
$os = $osInfo.Caption
$osVersion = $osInfo.Version
$architecture = $osInfo.OSArchitecture
$user = $env:USERNAME
$ram = [math]::Round(((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1GB), 2)
$cpu = (Get-WmiObject Win32_Processor).Name -join ", "
$serial = ((Get-WmiObject Win32_BIOS).SerialNumber) -as [string]
$macAddress = (Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true }).MACAddress
$ipAddress = (Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true }).IPAddress[0]
$domaine = (Get-WmiObject Win32_ComputerSystem).Domain

# Récupération de la clé Windows
$windowsKey = (Get-WmiObject SoftwareLicensingService).OA3xOriginalProductKey
$windowsKey = if ($windowsKey) { $windowsKey } else { "null" }
$serial = if ($serial) { $serial } else { "null" }

# Récupération du statut de licence et traduction en français
$rawLicenseStatus = (Get-WmiObject SoftwareLicensingProduct | Where-Object { $_.PartialProductKey } | Select-Object -First 1 -ExpandProperty LicenseStatus)

switch ($rawLicenseStatus) {
    0 { $licenseStatus = "0 - Non licencié" }
    1 { $licenseStatus = "1 - Activé (licencié)" }
    2 { $licenseStatus = "2 - Période de grâce initiale" }
    3 { $licenseStatus = "3 - Période de grâce supplémentaire" }
    4 { $licenseStatus = "4 - Période de grâce pour copie non authentique" }
    5 { $licenseStatus = "5 - Notification (activation requise)" }
    6 { $licenseStatus = "6 - Période de grâce étendue" }
    default { $licenseStatus = "$rawLicenseStatus - État inconnu" }
}

# Création du corps de la requête JSON
$body = @{
    "name"            = $hostname
    "os"              = $os
    "os_version"      = $osVersion
    "architecture"    = $architecture
    "user"            = $user
    "ram"             = $ram
    "cpu"             = $cpu
    "serial"          = $serial
    "mac"             = $macAddress
    "ip"              = $ipAddress
    "domaine"         = $domaine
    "windows_key"     = $windowsKey
    "license_status"  = $licenseStatus
}

$jsonData = $body | ConvertTo-Json -Depth 3
Write-Host "Données JSON envoyées : $jsonData"

[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

# Envoi de la requête à l'API d'OCS Inventory
try {
    $headers = @{
        "Content-Type" = "application/json"
        "Accept"       = "application/json"
    }
    if ($apiKey) { $headers["Authorization"] = "Bearer $apiKey" }

    $response = Invoke-RestMethod -Uri $apiEndpoint -Method Post -Headers $headers -Body $jsonData

    Write-Host "Données envoyées avec succès !"
    Write-Host "Réponse du serveur : $response"
} catch {
    Write-Host "Erreur lors de l'envoi des données : $_"
}
