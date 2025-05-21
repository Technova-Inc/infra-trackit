# Configuration des paramètres

$apiEndpoint = "http://localhost/api-track-it/Pc/Pull.php"



# ============================
# SCRIPT D'AUDIT DE SÉCURITÉ WINDOWS AVEC DÉTAILS
# ============================


# Initialisation
$score = 100
$risques = @()
$details = @()

function Add-Check {
    param(
        [string]$Nom,
        [string]$Resultat,
        [string]$Gravite, # Ex: "Critique", "Important", "Info"
        [string]$Commentaire
    )
    $details += [pscustomobject]@{
        Check = $Nom
        Result = $Resultat
        Gravite = $Gravite
        Commentaire = $Commentaire
    }
    if ($Gravite -eq "Critique") { $script:score -= 20 }
    elseif ($Gravite -eq "Important") { $script:score -= 10 }
    elseif ($Gravite -eq "Moyen") { $script:score -= 5 }
}

# -------------------
# Informations système
# -------------------
$rapport = @{
    NomMachine = $env:COMPUTERNAME
    Utilisateur = $env:USERNAME
    Date = Get-Date
}
$os = Get-CimInstance Win32_OperatingSystem
$rapport.OS = $os.Caption
$rapport.Build = $os.BuildNumber
$rapport.Architecture = $os.OSArchitecture
$rapport.Uptime_H = [math]::Round(((Get-Date) - $os.LastBootUpTime).TotalHours, 1)

# -------------------
# Antivirus & Pare-feu
# -------------------
try {
    $def = Get-MpComputerStatus
    if (-not $def.AntivirusEnabled) {
        Add-Check -Nom "Antivirus activé" -Resultat "Non" -Gravite "Critique" -Commentaire "Antivirus désactivé, machine vulnérable."
        $risques += "Antivirus désactivé"
    } else {
        Add-Check -Nom "Antivirus activé" -Resultat "Oui" -Gravite "Info" -Commentaire "Antivirus activé."
    }
    if (-not $def.RealTimeProtectionEnabled) {
        Add-Check -Nom "Protection en temps réel" -Resultat "Non" -Gravite "Important" -Commentaire "Protection en temps réel désactivée."
        $risques += " Protection en temps réel désactivée"
    } else {
        Add-Check -Nom "Protection en temps réel" -Resultat "Oui" -Gravite "Info" -Commentaire "Protection en temps réel activée."
    }
    if (-not $def.SignatureUpToDate) {
        Add-Check -Nom "Signatures antivirus à jour" -Resultat "Non" -Gravite "Important" -Commentaire "Signatures antivirus obsolètes."
        $risques += "Signatures antivirus obsolètes"
    } else {
        Add-Check -Nom "Signatures antivirus à jour" -Resultat "Oui" -Gravite "Info" -Commentaire "Signatures antivirus à jour."
    }
} catch {
    Add-Check -Nom "Windows Defender" -Resultat "Erreur" -Gravite "Important" -Commentaire "Impossible de vérifier Windows Defender."
    $risques += "Impossible de vérifier Windows Defender"
}

foreach ($profile in Get-NetFirewallProfile) {
    if (-not $profile.Enabled) {
        Add-Check -Nom "Pare-feu $($profile.Name)" -Resultat "Désactivé" -Gravite "Critique" -Commentaire "Pare-feu désactivé pour ce profil."
        $risques += "Pare-feu désactivé pour le profil $($profile.Name)"
    } else {
        Add-Check -Nom "Pare-feu $($profile.Name)" -Resultat "Activé" -Gravite "Info" -Commentaire "Pare-feu activé pour ce profil."
    }
}

# -------------------
# Politique de mot de passe
# -------------------
$pwPolicy = net accounts
if ($pwPolicy -match "Durée maximum.*0") {
    Add-Check -Nom "Expiration mots de passe" -Resultat "Non" -Gravite "Important" -Commentaire "Aucune expiration des mots de passe."
    $risques += "Aucune expiration des mots de passe"
} else {
    Add-Check -Nom "Expiration mots de passe" -Resultat "Oui" -Gravite "Info" -Commentaire "Expiration des mots de passe configurée."
}
if ($pwPolicy -match "Longueur minimale.*(0|1|2|3|4)") {
    Add-Check -Nom "Longueur minimale mot de passe" -Resultat "Trop courte" -Gravite "Moyen" -Commentaire "Longueur minimale du mot de passe trop faible."
    $risques += "Mot de passe trop court"
} else {
    Add-Check -Nom "Longueur minimale mot de passe" -Resultat "OK" -Gravite "Info" -Commentaire "Longueur minimale suffisante."
}

# -------------------
# Comptes locaux & Admins
# -------------------
$users = Get-LocalUser
$admins = Get-LocalGroupMember -Group Administrateurs
$noPwd = $users | Where-Object { $_.PasswordRequired -eq $false }
$disabled = $users | Where-Object { $_.Enabled -eq $false }

if ($noPwd.Count -gt 0) {
    Add-Check -Nom "Comptes sans mot de passe" -Resultat "$($noPwd.Count)" -Gravite "Critique" -Commentaire "Comptes locaux sans mot de passe détectés."
    $risques += "$($noPwd.Count) comptes sans mot de passe"
} else {
    Add-Check -Nom "Comptes sans mot de passe" -Resultat "0" -Gravite "Info" -Commentaire "Tous les comptes ont un mot de passe."
}
if ($admins.Count -gt 3) {
    Add-Check -Nom "Nombre d'Admins locaux" -Resultat "$($admins.Count)" -Gravite "Important" -Commentaire "Nombre élevé d'utilisateurs dans le groupe Administrateurs."
    $risques += "Trop d'utilisateurs dans le groupe Administrateurs ($($admins.Count))"
} else {
    Add-Check -Nom "Nombre d'Admins locaux" -Resultat "$($admins.Count)" -Gravite "Info" -Commentaire "Nombre d'administrateurs local normal."
}

# -------------------
# Programmes au démarrage
# -------------------
$startup = Get-CimInstance Win32_StartupCommand
if ($startup.Count -gt 10) {
    Add-Check -Nom "Programmes au démarrage" -Resultat "$($startup.Count)" -Gravite "Moyen" -Commentaire "Nombre élevé de programmes lancés au démarrage."
    $risques += "Plus de 10 programmes démarrent avec Windows"
} else {
    Add-Check -Nom "Programmes au démarrage" -Resultat "$($startup.Count)" -Gravite "Info" -Commentaire "Nombre de programmes au démarrage normal."
}

# -------------------
# Services suspects
# -------------------
$suspectPattern = "remote|tool|hack|rat|spy|meterpreter|shadow|rev"
$suspects = Get-Service | Where-Object { $_.Status -eq "Running" -and $_.Name -match $suspectPattern }
if ($suspects.Count -gt 0) {
    Add-Check -Nom "Services suspects" -Resultat "$($suspects.Name -join ', ')" -Gravite "Critique" -Commentaire "Services potentiellement malveillants détectés."
    $risques += "Services suspects détectés : $($suspects.Name -join ', ')"
} else {
    Add-Check -Nom "Services suspects" -Resultat "Aucun" -Gravite "Info" -Commentaire "Aucun service suspect détecté."
}

# -------------------
# Ports TCP ouverts
# -------------------
$tcpPorts = Get-NetTCPConnection -State Listen
if ($tcpPorts.Count -gt 10) {
    Add-Check -Nom "Ports TCP ouverts" -Resultat "$($tcpPorts.Count)" -Gravite "Moyen" -Commentaire "Nombre élevé de ports TCP ouverts."
    $risques += "Plus de 10 ports ouverts (TCP)"
} else {
    Add-Check -Nom "Ports TCP ouverts" -Resultat "$($tcpPorts.Count)" -Gravite "Info" -Commentaire "Nombre de ports ouverts normal."
}

# -------------------
# Partages réseau
# -------------------
$shares = Get-SmbShare | Where-Object { $_.Name -notin @("ADMIN$", "IPC$") }
if ($shares.Count -gt 0) {
    Add-Check -Nom "Partages réseau" -Resultat "$($shares.Name -join ', ')" -Gravite "Moyen" -Commentaire "Partages réseau détectés."
    $risques += "Partages réseau détectés : $($shares.Name -join ', ')"
} else {
    Add-Check -Nom "Partages réseau" -Resultat "Aucun" -Gravite "Info" -Commentaire "Aucun partage réseau détecté."
}

# -------------------
# BitLocker & TPM
# -------------------
$bit = Get-BitLockerVolume -MountPoint "C:" -ErrorAction SilentlyContinue
if ($bit.ProtectionStatus -ne 1) {
    Add-Check -Nom "BitLocker activé" -Resultat "Non" -Gravite "Important" -Commentaire "BitLocker non activé sur C:."
    $risques += "BitLocker non activé"
} else {
    Add-Check -Nom "BitLocker activé" -Resultat "Oui" -Gravite "Info" -Commentaire "BitLocker activé sur C:."
}

$tpm = Get-CimInstance -Namespace "Root\CIMv2\Security\MicrosoftTpm" -ClassName Win32_Tpm -ErrorAction SilentlyContinue

if ($tpm -and $tpm.IsEnabled().IsEnabled) {
    Add-Check -Nom "TPM activé" -Resultat "Oui" -Gravite "Info" -Commentaire "TPM activé."
} else {
    Add-Check -Nom "TPM activé" -Resultat "Non" -Gravite "Important" -Commentaire "TPM désactivé ou absent."
    $risques += "TPM désactivé ou absent"
}

# -------------------
# Derniers correctifs Windows
# -------------------
$hotfix = Get-HotFix | Sort-Object -Property InstalledOn -Descending | Select-Object -First 1
$lastPatch = $hotfix.InstalledOn
if (((Get-Date) - $lastPatch).Days -gt 30) {
    Add-Check -Nom "Dernier patch Windows" -Resultat $lastPatch.ToString("yyyy-MM-dd") -Gravite "Important" -Commentaire "Plus de 30 jours depuis dernier patch."
    $risques += "Plus de 30 jours depuis le dernier patch ($lastPatch)"
} else {
    Add-Check -Nom "Dernier patch Windows" -Resultat $lastPatch.ToString("yyyy-MM-dd") -Gravite "Info" -Commentaire "Patch à jour."
}

# Résumé du rapport
$rapport["ScoreSécurité"] = "$score"
$rapport["Risques"] = $risques
$rapport["AuditDétaillé"] = $details

# Affichage console (inchangé)
Write-Host "`n🛡️ Rapport de Sécurité – $env:COMPUTERNAME" -ForegroundColor Cyan
Write-Host "Score : $score / 100" -ForegroundColor Green
Write-Host "`nRisques détectés :"
if ($risques.Count -eq 0) {
    Write-Host "Aucun risque détecté." -ForegroundColor Green
} else {
    $risques | ForEach-Object { Write-Host " - $_" -ForegroundColor Red }
}

# --- Préparation du corps JSON en incluant le rapport complet ---

$body = @{

    'rapport'         = @{
        "ScoreSécurité" = $rapport.ScoreSécurité
        "Risques"       = $risques
        "InfosSysteme"  = @{
            "NomMachine" = $rapport.NomMachine
            "Utilisateur"= $rapport.Utilisateur
            "Date"       = $rapport.Date.ToString("yyyy-MM-dd HH:mm:ss")
            "Build"      = $rapport.Build
            "Architecture" = $rapport.Architecture
            "Uptime_H"   = $rapport.Uptime_H
        }
    }
}

$jsonData = $body | ConvertTo-Json -Depth 4
Write-Host "Données JSON envoyées : $jsonData"

[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

# Forcer l'encodage UTF8 sans BOM
$utf8NoBomEncoding = New-Object System.Text.UTF8Encoding($false)

# Convertir la chaîne JSON en bytes UTF8 sans BOM
$bytes = $utf8NoBomEncoding.GetBytes($jsonData)

# Construire le corps HTTP comme MemoryStream
$stream = New-Object System.IO.MemoryStream
$stream.Write($bytes, 0, $bytes.Length)
$stream.Position = 0


# Envoi de la requête à l'API d'OCS Inventory
try {
    $headers = @{
        "Content-Type" = "application/json"
        "Accept"       = "application/json"
    }
    if ($apiKey) { $headers["Authorization"] = "Bearer $apiKey" }

    
    $response = Invoke-RestMethod -Uri $apiEndpoint -Method Post -Headers $headers -Body $stream
    Write-Host "Données envoyées avec succès !"
    Write-Host "Réponse du serveur : $response"
} catch {
    Write-Host "Erreur lors de l'envoi des données : $_"
}

