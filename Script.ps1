# Récupération de la clé Windows et de l'état d'activation
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

# Récupération de la clé produit
$windowsKey = (Get-WmiObject SoftwareLicensingService).OA3xOriginalProductKey
$windowsKey = if ($windowsKey) { $windowsKey } else { "null" }
$serial = if ($serial) { $serial } else { "null" }

# Création du corps de la requête
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

$jsonData = $body | ConvertTo-Json
Write-Host "Données JSON envoyées : $jsonData"
