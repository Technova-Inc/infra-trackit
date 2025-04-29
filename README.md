# Script PowerShell - Envoi des Informations Machine à OCS Inventory

## 📌 Description

Ce script PowerShell a pour but de collecter automatiquement les informations système d’un poste Windows (nom, OS, CPU, RAM, licence, etc.) et de les envoyer sous forme de requête JSON à une API compatible.

---

## 📋 Informations collectées

Le script récupère les éléments suivants :
- Nom de l’ordinateur
- Système d’exploitation et sa version
- Architecture (32/64 bits)
- Nom d'utilisateur connecté
- Quantité de mémoire vive (RAM)
- Modèle du processeur (CPU)
- Numéro de série de la machine (BIOS)
- Adresse MAC
- Adresse IP
- Nom de domaine (ou Workgroup)
- Clé de licence Windows (si disponible)
- Statut de la licence Windows

---

## ⚙️ Prérequis

- PowerShell 5.1 ou supérieur
- Exécution autorisée (`Set-ExecutionPolicy`)
- Accès réseau vers le serveur OCS/API
- API compatible avec l’envoi en POST de JSON
- Facultatif : certificat SSL valide ou désactivé (`ServicePointManager` est configuré pour ignorer les erreurs SSL dans ce script)

---

## 🛠️ Utilisation

1. Modifie les variables en haut du script si nécessaire :
   ```powershell
   $ocsServer = "http://10.29.126.31/"
   $apiEndpoint = "https://10.29.126.31/track-it/index.php/Pull"
