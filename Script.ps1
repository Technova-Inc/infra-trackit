# Configuration des paramètres
$ocsServer = "http://10.29.126.31/" # Adresse du serveur OCS Inventory
$apiEndpoint = "https://10.29.126.31/track-it/index.php/Pull"
$apiKey = "CLE_API"  # Si requis

# Récupération des informations système
$hostname = $env:COMPUTERNAME
$osInfo = Get-WmiObject Win32_OperatingSystem
$os = $osInfo.Caption
$osVersion = $osInfo.Version
$architecture = (Get-WmiObject Win32_OperatingSystem).OSArchitecture
$user = $env:USERNAME
$ram = [math]::Round(((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1GB), 2)
$cpu = (Get-WmiObject Win32_Processor).Name -join ", "
$serial = ((Get-WmiObject Win32_BIOS).SerialNumber) -as [string]
$macAddress = (Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true }).MACAddress
$ipAddress = (Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true }).IPAddress[0]
$domaine = (Get-WmiObject Win32_ComputerSystem).Domain


# Récupération de la clé Windows et de l'état d'activation
$licenseStatus = (Get-WmiObject SoftwareLicensingProduct | Where-Object { $_.PartialProductKey } | Select-Object LicenseStatus).LicenseStatus
$windowsKey = (Get-WmiObject SoftwareLicensingService).OA3xOriginalProductKey



# Définition de l'état de la licence
$licenseState = switch ($licenseStatus) {
    0 { "Non activé" }
    1 { "Activé" }
    2 { "État inconnu" }
    3 { "Périmé" }
    4 { "État d'activation inconnu" }
    default { "Non défini" }
}

$WindowsKey = if ($windowsKey) { $windowsKey } else { "null" }
$serial = if ($serial) { $serial } else { "null" }

# Création du corps de la requête
$body = @{
    "name"         = $hostname
    "os"           = $os
    "os_version"   = $osVersion
    "architecture" = $architecture # Récupérer l'architecture du système d'exploitation Windows : "64-bit" → Windows 64 bits, "32-bit" → Windows 32 bits
    "user"         = $user
    "ram"          = $ram
    "cpu"          = $cpu
    "serial"       = $serial # Numéro de série du BIOS
    "mac"          = $macAddress
    "ip"           = $ipAddress
    "domaine"      = $domaine
    "windows_key"  = $windowsKey
    "license_status" = $licenseState # Numéro de 1 à 5 : 0 → Non activé, 1 → Activé, 2 → Clé de licence manquante, 3 → Expiré, 4 → Bloqué, 5 → Clé non valide
} #| ConvertTo-Json -Depth 3
$jsonData = $body | ConvertTo-Json
Write-Host "données JSON envoyée : $jsonData"

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
