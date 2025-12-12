# Règles et Conventions du Projet Kubernetes AWS Lab

**Version:** 1.0
**Dernière mise à jour:** 2025-12-12
**Objectif:** Document de référence centralisé pour toutes les règles, conventions et standards du projet

---

## Table des Matières

1. [Vue d'Ensemble du Projet](#vue-densemble-du-projet)
2. [Structure des Répertoires](#structure-des-répertoires)
3. [Conventions de Nommage](#conventions-de-nommage)
4. [Organisation des Fichiers](#organisation-des-fichiers)
5. [Standards de Code](#standards-de-code)
6. [Règles Terraform](#règles-terraform)
7. [Gestion des Sessions](#gestion-des-sessions)
8. [Gestion des Participants](#gestion-des-participants)
9. [Architecture Réseau](#architecture-réseau)
10. [Sécurité](#sécurité)
11. [Déploiement](#déploiement)
12. [Gestion des Coûts](#gestion-des-coûts)
13. [Dashboard Web](#dashboard-web)
14. [Documentation](#documentation)
15. [Git et Versioning](#git-et-versioning)
16. [Bonnes Pratiques](#bonnes-pratiques)
17. [Stack Technologique](#stack-technologique)

---

## Vue d'Ensemble du Projet

### Objectif Principal
Fournir une solution Infrastructure-as-Code (IaC) automatisée pour déployer des environnements de lab Kubernetes isolés sur AWS, spécifiquement conçus pour des sessions de formation multi-participants.

### Principes de Conception
1. **Session-First Organization**: Tout est organisé par session de formation
2. **Infrastructure as Code**: Déploiement 100% Terraform, zéro étape manuelle
3. **Privacy by Default**: Anonymisation automatique des noms de participants
4. **Parallel-Ready**: Isolation via workspaces pour sessions simultanées
5. **Cost-Tracked**: Chaque ressource taguée pour le suivi des coûts AWS
6. **Automated Validation**: Validation des clés SSH avant déploiement
7. **Web-First Access**: Dashboard pour informations d'accès temps réel
8. **Documentation-Heavy**: Guides complets dans docs/ et README
9. **Script-Driven**: Opérations complexes encapsulées dans des scripts Bash
10. **Clean Separation**: Code, config et clés dans des répertoires dédiés

---

## Structure des Répertoires

### Organisation Obligatoire

```
kubernetes-aws-lab/
├── README.md                          # Documentation principale
├── QUICK-START-PARALLEL-SESSIONS.md   # Guide de démarrage rapide
├── .gitignore                         # Exclusions Git
├── docs/                              # Documentation complète
│   ├── SESSION-MANAGEMENT.md          # Gestion des sessions
│   ├── PARALLEL-SESSIONS.md           # Architecture sessions parallèles
│   ├── PARTICIPANT-NAMING.md          # Conventions de nommage
│   ├── PARTICIPANT-ACCESS-SOLUTIONS.md # Méthodes de distribution
│   └── PROJECT-RULES.md               # Ce document
├── terraform/                         # Code infrastructure
│   ├── main.tf                        # Configuration principale
│   ├── variables.tf                   # Variables d'entrée
│   ├── outputs.tf                     # Définitions des sorties
│   ├── backend.tf                     # Gestion de l'état
│   ├── terraform.tfvars.example       # Exemple de variables
│   └── modules/
│       ├── vpc/                       # Module VPC partagé
│       └── k8s-cluster/               # Module cluster Kubernetes
├── sessions/                          # Configurations de session
│   ├── README.md                      # Documentation sessions
│   ├── session-1.tfvars               # Config master uniquement
│   ├── session-2.tfvars               # Config standard (2 workers)
│   └── session-3.tfvars               # Config large (5 workers)
├── participants/                      # Clés SSH par session
│   ├── README.md                      # Guide participants
│   ├── {session-name}/                # Répertoire par session
│   │   └── {prenom.nom.pub}          # Clés SSH des participants
│   └── session-nov-2025/              # Exemple de session
└── scripts/                           # Scripts d'automatisation
    ├── manage-session.sh              # CLI gestion de session
    ├── validate-ssh-keys.sh           # Validation clés SSH
    ├── generate-access-info.sh        # Génération infos d'accès
    ├── start-dashboard.sh             # Lanceur dashboard
    └── web-dashboard/                 # Application dashboard web
        ├── app.py                     # Serveur Flask
        ├── requirements.txt           # Dépendances Python
        ├── README.md                  # Documentation dashboard
        └── templates/
            └── dashboard.html         # Interface web
```

### Répertoires Générés (Non versionnés)

```
kubernetes-aws-lab/
├── participant-access/                # Informations d'accès générées
│   └── {session-name}/
│       ├── all-participants.txt
│       ├── all-participants.csv
│       └── {participant}/
│           └── access-info.txt
├── archives/                          # Archives post-session
│   └── {session-name}/
│       ├── session-info.md
│       ├── terraform-outputs.json
│       └── participant-access/
└── terraform/
    ├── .terraform/                    # Providers et modules
    ├── .terraform.lock.hcl            # Verrouillage des versions
    ├── terraform.tfstate.d/           # États par workspace
    │   ├── session-1/
    │   ├── session-2/
    │   └── session-3/
    └── terraform.tfvars               # Variables personnalisées (NON versionné)
```

---

## Conventions de Nommage

### 1. Noms de Fichiers de Clés SSH

**Format Obligatoire:** `{prenom}.{nom}.pub`

**Règles:**
- Tout en minuscules
- Prénom complet
- Nom de famille complet
- Extension `.pub`
- **INTERDIT:** Adresses email dans les noms de fichiers

**Exemples Valides:**
```
john.doe.pub
marie.dupont.pub
ahmed.ben-ali.pub
```

**Exemples Invalides:**
```
john.doe@email.com.pub  # ❌ Email dans le nom
John.Doe.pub            # ❌ Majuscules
johndoe.pub             # ❌ Pas de séparation prénom/nom
john-doe.pub            # ❌ Tiret au lieu de point
```

### 2. Transformation des Noms de Participants

**Format Discret:** `{prenom}.{2-lettres-nom}`

**Logique de Transformation:**
```hcl
# Automatiquement appliquée dans terraform/main.tf
{prenom}.{nom}.pub → {prenom}.{no}
```

**Exemples:**
```
john.doe.pub      → john.do
marie.dupont.pub  → marie.du
ahmed.ben-ali.pub → ahmed.be
```

**Objectif:** Préserver la vie privée des participants dans les ressources AWS publiques

### 3. Noms de Sessions

**Format Recommandé:** `{contexte}-{mois}-{année}` ou identifiant descriptif

**Exemples Valides:**
```
session-nov-2025
training-dec-2025
session-winter-2025
bootcamp-k8s-jan-2025
```

**Règles:**
- Pas d'espaces (utiliser tirets)
- Tout en minuscules
- Doit correspondre au nom du répertoire `participants/{session-name}/`
- Doit correspondre au fichier `sessions/{session-name}.tfvars`
- Utilisé comme nom de workspace Terraform

### 4. Noms de Ressources AWS

**Format:** `{project_name}-{participant_name}-{resource_type}`

**Exemples:**
```
k8s-lab-john.do-master
k8s-lab-john.do-worker-1
k8s-lab-john.do-worker-2
k8s-lab-john.do-sg
k8s-lab-vpc
k8s-lab-igw
```

**Variables de Base:**
- `project_name`: Défini dans `terraform.tfvars` (défaut: `k8s-lab`)
- `participant_name`: Dérivé du nom de fichier de clé SSH
- `resource_type`: master, worker-N, sg, vpc, etc.

### 5. Noms de Branches Git

**Format pour Branches Automatisées:** `claude/{descriptif}-{id}`

**Exemples:**
```
claude/document-project-rules-018riKaqcocp54CPy9FsWyZL
claude/update-readme-11-participants-01BopX2cZKoGaGujiXDVn13H
claude/improve-dashboard-display-013vPXWRrAWJXgSumLBY9fFE
```

---

## Organisation des Fichiers

### Règles d'Organisation par Session

**Organisation Basée sur Sessions (RECOMMANDÉ):**
```
participants/
├── session-nov-2025/
│   ├── john.doe.pub
│   ├── marie.dupont.pub
│   └── ahmed.ali.pub
├── session-dec-2025/
│   ├── alice.martin.pub
│   └── bob.smith.pub
└── README.md

sessions/
├── session-nov-2025.tfvars
├── session-dec-2025.tfvars
└── README.md
```

**Règles:**
1. **Cohérence Obligatoire:** `participants/{session-name}/` doit correspondre à `sessions/{session-name}.tfvars`
2. **Fichier Session:** Toujours nommer le `.tfvars` exactement comme le répertoire de participants
3. **README par Session:** Chaque session doit avoir un README avec métadonnées

### Fichiers Terraform

**Localisation:** Tous dans `terraform/`

**Fichiers Principaux:**
- `main.tf`: Orchestration des modules, gestion des participants
- `variables.tf`: Définitions des 8 variables core
- `outputs.tf`: Sorties pour utilisateurs et dashboard
- `backend.tf`: Configuration état (S3/local)
- `terraform.tfvars.example`: Template de configuration
- `terraform.tfvars`: Configuration personnalisée (NON versionné)

**Modules:**
- `modules/vpc/`: VPC partagé avec subnets publics/privés
- `modules/k8s-cluster/`: Cluster par participant (master + workers)

### Fichiers de Configuration de Session

**Localisation:** `sessions/`

**Format:** `{session-name}.tfvars`

**Contenu Requis:**
```hcl
# Exemple: sessions/session-2.tfvars
session_name        = "session-2"
worker_count        = 2
master_instance_type = "t3.medium"
worker_instance_type = "t3.medium"
kubernetes_version   = "1.28"
```

**Sessions Pré-configurées:**
1. **session-1.tfvars**: Master seul (0 workers) - Tests rapides
2. **session-2.tfvars**: Master + 2 workers - Standard
3. **session-3.tfvars**: Master + 5 workers (t3.large) - Production-like

### Fichiers d'Accès Participants

**Localisation:** `participant-access/{session-name}/`

**Structure Générée:**
```
participant-access/
└── session-nov-2025/
    ├── all-participants.txt        # Toutes les infos
    ├── all-participants.csv        # Format tableur
    ├── john.do/
    │   └── access-info.txt         # Infos individuelles
    ├── marie.du/
    │   └── access-info.txt
    └── ahmed.al/
        └── access-info.txt
```

### Archives Post-Session

**Localisation:** `archives/{session-name}/`

**Contenu Recommandé:**
```
archives/
└── session-nov-2025/
    ├── session-info.md             # Métadonnées session
    ├── terraform-outputs.json      # Sorties Terraform
    ├── participant-access/         # Copie des accès
    ├── session-costs.txt           # Coûts AWS
    └── feedback.md                 # Retours participants
```

---

## Standards de Code

### Bash Scripts

**En-tête Standard:**
```bash
#!/bin/bash
set -e  # Arrêt immédiat en cas d'erreur

# Description du script
# Usage: ./script.sh [options]
```

**Règles:**
1. **Gestion d'Erreur:** Toujours `set -e` en début de script
2. **Aide:** Support flags `-h` et `--help`
3. **Validation:** Valider les entrées avant exécution
4. **Couleurs:** Utiliser des couleurs pour la clarté
5. **Emojis/Icônes:** Utiliser de manière cohérente (✓, ✗, ⚠, etc.)
6. **Chemins:** Utiliser des chemins relatifs au projet

**Exemple de Code de Couleur:**
```bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}✓${NC} Opération réussie"
echo -e "${RED}✗${NC} Échec de l'opération"
echo -e "${YELLOW}⚠${NC} Attention"
```

### Terraform

**Formatage:**
- Indentation: 2 espaces
- Format HCL standard (`terraform fmt`)
- Groupement logique des ressources

**Variables:**
```hcl
variable "example" {
  description = "Description détaillée de la variable"
  type        = string
  default     = "valeur-par-defaut"
}
```

**Règles:**
1. **Descriptions:** Obligatoires pour toutes les variables
2. **Types:** Toujours spécifier le type
3. **Defaults:** Fournir des valeurs par défaut quand approprié
4. **Commentaires:** Expliquer la logique complexe
5. **Tagging:** Tous les tags obligatoires sur toutes les ressources

**Tags Obligatoires:**
```hcl
tags = {
  Project    = var.project_name
  Session    = var.session_name
  ManagedBy  = "Terraform"
  Environment = "lab"
}
```

### Python (Dashboard)

**En-tête Standard:**
```python
#!/usr/bin/env python3
"""
Description du module
"""
```

**Règles:**
1. **Shebang:** `#!/usr/bin/env python3`
2. **Docstrings:** Obligatoires pour modules et fonctions
3. **Gestion d'Erreur:** Try/except pour subprocess et I/O
4. **Timeouts:** Toujours spécifier des timeouts pour commandes externes
5. **JSON:** Parser avec module json standard

**Exemple:**
```python
import subprocess
import json

def get_terraform_output(session=None):
    """Récupère les outputs Terraform pour une session."""
    try:
        result = subprocess.run(
            ["terraform", "output", "-json"],
            capture_output=True,
            text=True,
            timeout=30,
            cwd="/path/to/terraform"
        )
        return json.loads(result.stdout)
    except subprocess.TimeoutExpired:
        return {"error": "Timeout"}
    except json.JSONDecodeError:
        return {"error": "Invalid JSON"}
```

---

## Règles Terraform

### Variables Core (8 Variables)

**Définies dans `terraform/variables.tf`:**

1. **aws_region**
   - Type: `string`
   - Défaut: `"eu-west-1"`
   - Région AWS pour déploiement

2. **vpc_cidr**
   - Type: `string`
   - Défaut: `"10.0.0.0/16"`
   - CIDR du VPC partagé

3. **master_instance_type**
   - Type: `string`
   - Défaut: `"t3.medium"`
   - Type d'instance pour les masters

4. **worker_instance_type**
   - Type: `string`
   - Défaut: `"t3.medium"`
   - Type d'instance pour les workers

5. **worker_count**
   - Type: `number`
   - Défaut: `2`
   - Nombre de workers par participant

6. **kubernetes_version**
   - Type: `string`
   - Défaut: `"1.28"`
   - Version Kubernetes à installer

7. **project_name**
   - Type: `string`
   - Défaut: `"k8s-lab"`
   - Préfixe pour toutes les ressources

8. **session_name**
   - Type: `string`
   - Défaut: `""`
   - Nom de la session pour tagging

### Modules

**Module VPC (`modules/vpc/`):**
- **Responsabilité:** VPC partagé unique pour toutes les sessions
- **Ressources:**
  - VPC (10.0.0.0/16)
  - Internet Gateway
  - Subnets publics (un par AZ) pour NAT
  - Subnets privés (un par AZ) pour nodes
  - NAT Gateways (un par AZ) pour haute disponibilité
  - Route tables

**Module K8s-Cluster (`modules/k8s-cluster/`):**
- **Responsabilité:** Cluster par participant (master + N workers)
- **Ressources:**
  - Security Group
  - Master node (EC2)
  - Worker nodes (EC2, count variable)
  - Paire de clés SSH interne (master→workers)
  - User data scripts (kubeadm init/join)

### Patterns Terraform

**Pattern 1: For-Each sur Fichiers SSH**
```hcl
locals {
  ssh_keys_dir = "../participants/${var.session_name}"
  ssh_keys = {
    for file in fileset(local.ssh_keys_dir, "*.pub") :
    trimsuffix(file, ".pub") => file(local.ssh_keys_dir + "/" + file)
  }
}

module "k8s_cluster" {
  for_each = local.ssh_keys
  source   = "./modules/k8s-cluster"
  # ...
}
```

**Pattern 2: Transformation de Noms**
```hcl
locals {
  participant_names = {
    for key, value in local.ssh_keys :
    key => "${split(".", key)[0]}.${substr(split(".", key)[1], 0, 2)}"
  }
}
```

**Pattern 3: Outputs Structurés**
```hcl
output "participant_clusters" {
  value = {
    for name, cluster in module.k8s_cluster : name => {
      master_ip         = cluster.master_public_ip
      participant_name  = local.participant_names[name]
      ssh_key_file      = "${name}.pub"
      kubeconfig_command = "ssh ubuntu@${cluster.master_public_ip} 'sudo cat /etc/kubernetes/admin.conf'"
    }
  }
}
```

### Backend Configuration

**Local Backend (Défaut):**
```hcl
# Pas de configuration explicite
# État stocké dans terraform.tfstate.d/{workspace}/
```

**S3 Backend (Recommandé pour équipes):**
```hcl
terraform {
  backend "s3" {
    bucket         = "mon-bucket-tfstate"
    key            = "k8s-lab/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

---

## Gestion des Sessions

### Cycle de Vie d'une Session

**1. Création de la Configuration**
```bash
# Créer le répertoire de participants
mkdir -p participants/session-dec-2025

# Créer le fichier de configuration
cp sessions/session-2.tfvars sessions/session-dec-2025.tfvars
# Éditer le fichier avec les paramètres spécifiques
```

**2. Ajout des Clés SSH**
```bash
# Les participants envoient leurs clés publiques
# Les ajouter dans participants/session-dec-2025/
# Format: prenom.nom.pub
```

**3. Validation**
```bash
./scripts/validate-ssh-keys.sh session-dec-2025
```

**4. Initialisation**
```bash
./scripts/manage-session.sh init session-dec-2025
```

**5. Planification**
```bash
./scripts/manage-session.sh plan session-dec-2025
```

**6. Déploiement**
```bash
./scripts/manage-session.sh apply session-dec-2025
```

**7. Distribution des Accès**
```bash
./scripts/generate-access-info.sh session-dec-2025
```

**8. Session Active**
```bash
# Lancer le dashboard
./scripts/start-dashboard.sh

# Monitorer les ressources
./scripts/manage-session.sh status session-dec-2025
```

**9. Nettoyage**
```bash
# Archiver les informations importantes
mkdir -p archives/session-dec-2025
cp -r participant-access/session-dec-2025 archives/session-dec-2025/

# Détruire l'infrastructure
./scripts/manage-session.sh destroy session-dec-2025
```

### Règles de Session

1. **Unicité:** Une session = un workspace Terraform unique
2. **Isolation:** Les sessions ne partagent rien sauf le VPC
3. **Nommage:** Le nom doit être cohérent (répertoire, tfvars, workspace)
4. **Validation:** Toujours valider les clés SSH avant apply
5. **Documentation:** Chaque session doit avoir un README
6. **Archivage:** Archiver avant destruction
7. **Cleanup:** Toujours détruire après la formation

### Workspaces Terraform

**Commandes:**
```bash
# Lister les workspaces
terraform workspace list

# Créer un workspace
terraform workspace new session-dec-2025

# Basculer vers un workspace
terraform workspace select session-dec-2025

# Afficher le workspace actuel
terraform workspace show

# Supprimer un workspace (après destroy)
terraform workspace delete session-dec-2025
```

**Règles:**
- Un workspace = une session
- Nom du workspace = nom de la session
- Ne jamais supprimer un workspace avec ressources actives
- État isolé par workspace dans `terraform.tfstate.d/{workspace}/`

### Sessions Parallèles

**Support:** Oui, via workspaces

**Exemple:**
```bash
# Terminal 1 - Session A
./scripts/manage-session.sh apply session-nov-2025

# Terminal 2 - Session B (simultané)
./scripts/manage-session.sh apply session-dec-2025
```

**Règles:**
- Chaque session dans son propre workspace
- Partage du VPC (10.0.0.0/16 suffisant)
- Pod CIDRs uniques par participant (10.100-255.0.0/16)
- Aucune collision de ressources

---

## Gestion des Participants

### Format de Clé SSH

**Type Obligatoire:** `ed25519`

**Génération:**
```bash
ssh-keygen -t ed25519 -C "prenom.nom" -f ~/.ssh/k8s-lab-prenom.nom
```

**Validation:**
- Type: ed25519 (RSA interdit)
- Nom de fichier: `prenom.nom.pub`
- Format: OpenSSH public key
- Taille: ~68-100 caractères

### Script de Validation

**Commande:**
```bash
./scripts/validate-ssh-keys.sh [session|fichier|répertoire]
```

**Vérifications:**
1. Format de fichier (prenom.nom.pub)
2. Type de clé (ed25519)
3. Syntaxe OpenSSH
4. Fingerprint valide (via ssh-keygen)

**Exemple:**
```bash
# Valider toute une session
./scripts/validate-ssh-keys.sh session-nov-2025

# Valider un fichier
./scripts/validate-ssh-keys.sh participants/session-nov-2025/john.doe.pub

# Valider un répertoire
./scripts/validate-ssh-keys.sh participants/session-nov-2025/
```

### Transformation des Noms

**Logique:**
```
Fichier: john.doe.pub
  → Extraction: prenom="john", nom="doe"
  → Transformation: "john" + "." + substr("doe", 0, 2)
  → Résultat: "john.do"
```

**Objectif:**
- Préserver la vie privée
- Éviter affichage complet des noms dans AWS Console
- Maintenir l'unicité des identifiants

**Implémentation:** Automatique dans `terraform/main.tf` via `locals`

### Informations d'Accès

**Générées par:** `scripts/generate-access-info.sh`

**Formats Disponibles:**
1. **Texte individuel:** `participant-access/{session}/{participant}/access-info.txt`
2. **Texte global:** `participant-access/{session}/all-participants.txt`
3. **CSV:** `participant-access/{session}/all-participants.csv`

**Contenu d'un Fichier d'Accès:**
```
Informations d'Accès Kubernetes - Participant: john.do
Session: session-nov-2025

Master IP: 54.123.45.67
SSH Username: ubuntu
SSH Command: ssh ubuntu@54.123.45.67

Récupération kubeconfig:
ssh ubuntu@54.123.45.67 'sudo cat /etc/kubernetes/admin.conf' > kubeconfig
export KUBECONFIG=./kubeconfig

Vérification:
kubectl get nodes
kubectl get pods --all-namespaces
```

---

## Architecture Réseau

### VPC Partagé

**CIDR:** `10.0.0.0/16`

**Caractéristiques:**
- Un seul VPC pour toutes les sessions
- Déployé par le module `modules/vpc/`
- Suffisamment large pour tous les participants

### Subnets

**Subnets Publics:**
- **Objectif:** NAT Gateways uniquement
- **CIDR:** `10.0.{1,2,3,...}.0/24` (un par AZ)
- **Route:** Internet Gateway

**Subnets Privés:**
- **Objectif:** Nodes Kubernetes (master + workers)
- **CIDR:** `10.0.{101,102,103,...}.0/24` (un par AZ)
- **Route:** NAT Gateway de l'AZ

### Availability Zones

**Configuration:**
- Multi-AZ pour haute disponibilité
- NAT Gateway par AZ (éviter SPOF)
- Distribution automatique des nodes

**Exemple:**
```
eu-west-1a:
  - Subnet public: 10.0.1.0/24 (NAT GW)
  - Subnet privé: 10.0.101.0/24 (Nodes)

eu-west-1b:
  - Subnet public: 10.0.2.0/24 (NAT GW)
  - Subnet privé: 10.0.102.0/24 (Nodes)

eu-west-1c:
  - Subnet public: 10.0.3.0/24 (NAT GW)
  - Subnet privé: 10.0.103.0/24 (Nodes)
```

### Réseau Kubernetes

**Pod Network CIDR:**
- **Range:** `10.100.0.0/16` à `10.255.0.0/16`
- **Allocation:** Un `/16` par participant
- **Exemple:**
  ```
  john.do  → 10.100.0.0/16
  marie.du → 10.101.0.0/16
  ahmed.al → 10.102.0.0/16
  ```

**CNI:** Calico (installé automatiquement sur master)

**Service CIDR:** Défini par défaut Kubernetes (10.96.0.0/12)

---

## Sécurité

### Security Groups

**Par Participant:**
- Un Security Group par cluster
- Isolation entre participants
- Nommage: `{project}-{participant}-sg`

### Règles Entrantes

**SSH (Port 22):**
- **Source:** `var.allowed_cidrs` (configurable)
- **Défaut:** `0.0.0.0/0` (ouvert au monde)
- **Production:** Restreindre à IPs connues
- **Exemple:**
  ```hcl
  allowed_cidrs = ["203.0.113.0/24", "198.51.100.0/24"]
  ```

**Kubernetes API (Port 6443):**
- **Source:** `var.allowed_cidrs` (configurable)
- **Défaut:** `0.0.0.0/0`
- **Production:** Restreindre strictement

**Inter-Nodes:**
- **Source:** VPC CIDR (10.0.0.0/16)
- **Protocole:** All traffic
- **Objectif:** Communication master↔workers

### Règles Sortantes

**Défaut:** `0.0.0.0/0` (tout autorisé)

**Objectif:**
- Téléchargement packages (apt)
- Accès registres Docker (docker.io, gcr.io, etc.)
- Accès APIs Kubernetes

### Gestion des Clés SSH

**Clé Publique Participant:**
- Fournie par le participant
- Ajoutée au master uniquement
- Nom de fichier: `prenom.nom.pub`

**Clé Interne (Master→Workers):**
- Générée automatiquement par Terraform
- Ressource: `tls_private_key`
- Utilisation: Communication master→workers pour kubeadm
- **Jamais** exposée aux participants

### Bonnes Pratiques Sécurité

1. **Restreindre allowed_cidrs:** Ne jamais utiliser 0.0.0.0/0 en production
2. **Rotation des Clés:** Nouvelle clé SSH par session
3. **Nettoyage:** Détruire les ressources après formation
4. **Pas de Secrets dans Git:** .gitignore strict
5. **HTTPS Uniquement:** Pour tout téléchargement (apt, Docker, etc.)
6. **IAM Minimum:** Utiliser des rôles IAM avec privilèges minimums

---

## Déploiement

### Pré-requis

**Outils:**
- Terraform >= 1.0
- AWS CLI configuré
- jq (pour scripts)
- Python 3 + Flask (pour dashboard)

**Permissions AWS:**
- EC2: Full access
- VPC: Full access
- IAM: PassRole (si utilisation de rôles)

### Workflow de Déploiement

**1. Vérification Pré-déploiement**
```bash
# Vérifier la configuration AWS
aws sts get-caller-identity

# Vérifier les clés SSH
./scripts/validate-ssh-keys.sh {session-name}

# Vérifier la configuration Terraform
cd terraform && terraform fmt -check
```

**2. Initialisation**
```bash
# Option 1: Via script
./scripts/manage-session.sh init {session-name}

# Option 2: Manuel
cd terraform
terraform init
terraform workspace new {session-name}
```

**3. Planification**
```bash
# Via script
./scripts/manage-session.sh plan {session-name}

# Manuel
cd terraform
terraform workspace select {session-name}
terraform plan -var-file=../sessions/{session-name}.tfvars
```

**4. Déploiement**
```bash
# Via script (avec confirmation)
./scripts/manage-session.sh apply {session-name}

# Via script (auto-approve)
./scripts/manage-session.sh apply {session-name} -y

# Manuel
cd terraform
terraform workspace select {session-name}
terraform apply -var-file=../sessions/{session-name}.tfvars
```

**5. Vérification**
```bash
# Status des ressources
./scripts/manage-session.sh status {session-name}

# Outputs
./scripts/manage-session.sh output {session-name}

# Test SSH sur un master
ssh ubuntu@{master-ip} 'kubectl get nodes'
```

### Règles de Déploiement

1. **Validation Obligatoire:** Toujours valider les clés SSH avant apply
2. **Plan First:** Toujours exécuter `plan` avant `apply`
3. **Session Isolée:** Déployer dans le bon workspace
4. **Fichier tfvars:** Utiliser `-var-file` avec le bon fichier de session
5. **Logs:** Conserver les logs de déploiement pour debug
6. **Timeouts:** Les nodes prennent 3-5 min pour être prêts
7. **Worker Join:** Les workers rejoignent automatiquement le master

### Test Rapide (Worker Count = 0)

**Objectif:** Valider rapidement sans déployer de workers

**Configuration:**
```hcl
# sessions/session-1.tfvars
worker_count = 0
master_instance_type = "t3.medium"
```

**Avantages:**
- Déploiement rapide (~3 min)
- Coût minimal
- Validation des clés SSH
- Test de connectivité

### Temps de Déploiement Typiques

- **Master seul:** 3-5 minutes
- **Master + 2 workers:** 5-7 minutes
- **Master + 5 workers:** 7-10 minutes

---

## Gestion des Coûts

### Tagging pour Suivi des Coûts

**Tags Automatiques:**
```hcl
default_tags {
  tags = {
    Project     = var.project_name        # "k8s-lab"
    Session     = var.session_name        # "session-nov-2025"
    ManagedBy   = "Terraform"
    Environment = "lab"
  }
}
```

**Utilisation dans AWS Cost Explorer:**
- Filtrer par `Session` pour voir les coûts par formation
- Filtrer par `Project` pour coûts globaux
- Grouper par `Environment` pour séparer lab/prod

### Calcul de Coût dans le Dashboard

**Implémenté dans:** `scripts/web-dashboard/app.py`

**Tarification AWS (eu-west-1):**
```python
AWS_PRICING = {
    't3.medium': 0.0416,  # $/heure
    't3.large':  0.0832,  # $/heure
    't3.xlarge': 0.1664,  # $/heure
}
```

**Formule:**
```python
coût_horaire = (
    nb_participants * coût_master +
    nb_participants * nb_workers * coût_worker
)

coût_journée = coût_horaire * 24
```

**Exemple:**
```
Configuration: 11 participants, t3.medium, 2 workers
Coût horaire = 11 * (1 * 0.0416 + 2 * 0.0416) = $1.37/h
Coût jour = $1.37 * 24 = $32.89/jour
```

### Estimations de Coût par Configuration

**Session-1 (0 workers, t3.medium):**
- Coût horaire: ~$0.04 par participant
- Exemple 10 participants: ~$9.60/jour

**Session-2 (2 workers, t3.medium):**
- Coût horaire: ~$0.12 par participant
- Exemple 10 participants: ~$29/jour

**Session-3 (5 workers, t3.large):**
- Coût horaire: ~$0.50 par participant
- Exemple 10 participants: ~$120/jour

### Bonnes Pratiques de Coût

1. **Détruire Rapidement:** Ne pas laisser tourner après formation
2. **Worker Count Approprié:** Utiliser le minimum nécessaire
3. **Instance Types:** Préférer t3.medium sauf besoin spécifique
4. **Sessions Courtes:** Planifier des sessions concentrées
5. **Monitoring:** Utiliser AWS Cost Explorer régulièrement
6. **Alertes:** Configurer des alertes de budget AWS
7. **Test avec 0 Workers:** Valider d'abord sans workers

### Nettoyage Post-Session

**Impératif:** Toujours détruire les ressources

```bash
# Archiver d'abord
mkdir -p archives/{session-name}
./scripts/generate-access-info.sh {session-name}
cp -r participant-access/{session-name} archives/{session-name}/
terraform output -json > archives/{session-name}/outputs.json

# Puis détruire
./scripts/manage-session.sh destroy {session-name}

# Vérifier la destruction
aws ec2 describe-instances \
  --filters "Name=tag:Session,Values={session-name}" \
  --query 'Reservations[].Instances[].State.Name'
```

---

## Dashboard Web

### Lancement

**Commande:**
```bash
./scripts/start-dashboard.sh [port]
```

**Port Défaut:** 8080

**Accès:** `http://localhost:8080`

### Fonctionnalités

1. **Vue Globale:**
   - Toutes les sessions actives
   - Nombre de participants par session
   - Type d'instances
   - Nombre de workers

2. **Informations d'Accès:**
   - IP publique du master
   - Commande SSH
   - Commande kubeconfig
   - Nom discret du participant

3. **Calcul de Coût:**
   - Coût horaire par session
   - Coût journalier estimé
   - Basé sur tarification AWS actuelle

4. **Auto-refresh:**
   - Toutes les 10 secondes
   - Données en temps réel depuis Terraform

### API Endpoints

**GET /api/data**
- Retourne: Données de toutes les sessions
- Format: JSON

**GET /api/data/{session}**
- Retourne: Données d'une session spécifique
- Format: JSON

**GET /api/sessions**
- Retourne: Liste des sessions actives
- Format: JSON (array)

**GET /health**
- Retourne: Statut du serveur
- Format: JSON

### Dépendances

**Python:**
```
Flask >= 3.0.0
Werkzeug >= 3.0.1
```

**Système:**
- Terraform (pour `terraform output`)
- jq (pour parsing JSON)

**Installation:**
```bash
pip install -r scripts/web-dashboard/requirements.txt
```

### Configuration

**Variables d'Environnement:**
```bash
export FLASK_PORT=8080        # Port du serveur
export TERRAFORM_DIR=./terraform  # Répertoire Terraform
```

**Fichier de Config:** Aucun (configuration via code)

---

## Documentation

### Standards de Documentation

**Format:** Markdown (GitHub-flavored)

**Structure Standard:**
```markdown
# Titre Principal

## Section Majeure

### Sous-section

**Élément Important**

- Liste à puces
- Deuxième élément

1. Liste numérotée
2. Deuxième élément

Code inline: `commande`

Bloc de code:
` ``bash
commande --option
` ``
```

### Niveaux de Documentation

**1. README.md Racine**
- Vue d'ensemble du projet
- Quick start
- Architecture globale
- Liens vers documentation détaillée

**2. Documentation Détaillée (docs/)**
- Un fichier par sujet majeur
- Guides complets
- Exemples détaillés
- Troubleshooting

**3. README par Répertoire**
- `sessions/README.md`: Configurations de session
- `participants/README.md`: Gestion des clés SSH
- `scripts/web-dashboard/README.md`: Dashboard

**4. Commentaires de Code**
- Logique complexe uniquement
- Pas de commentaires évidents
- Préférer code auto-documenté

### Bilinguisme

**Principe:** Documentation principalement en français

**Exceptions:**
- Code: Anglais (variables, fonctions, commentaires)
- Commits: Français accepté
- README technique: Bilingue acceptable

### Indicateurs Visuels

**Emojis/Icônes Standard:**
- ✅ / ✓ : Succès, validation
- ❌ / ✗ : Échec, erreur
- ⚠️ : Attention, avertissement
- 📋 : Liste, checklist
- 🔧 : Configuration
- 📊 : Statistiques, coûts
- 🚀 : Déploiement, lancement

**Utilisation:**
- Dans documentation pour clarté visuelle
- Dans scripts pour output utilisateur
- Pas dans code de production

### Tableaux

**Format Markdown:**
```markdown
| Colonne 1 | Colonne 2 | Colonne 3 |
|-----------|-----------|-----------|
| Valeur 1  | Valeur 2  | Valeur 3  |
```

**Utilisation:**
- Comparaisons de configurations
- Tableaux de tarification
- Listes de commandes avec descriptions

### Blocs de Code

**Syntaxe Highlighting:**
```markdown
` ``bash
terraform apply
` ``

` ``hcl
variable "example" {
  type = string
}
` ``

` ``python
def function():
    pass
` ``
```

### Exigences de Documentation

**Nouveau Fichier .tfvars:**
- Commenter chaque variable
- Documenter le cas d'usage
- Ajouter référence dans sessions/README.md

**Nouveau Script:**
- Help flag (`-h`, `--help`)
- Commentaires pour fonctions complexes
- Usage examples en en-tête

**Nouveau Module Terraform:**
- README.md dans le module
- Description de toutes les variables
- Exemples d'utilisation

---

## Git et Versioning

### .gitignore

**Fichiers Exclus:**

**Terraform:**
```gitignore
terraform/.terraform/
terraform/.terraform.lock.hcl
terraform/terraform.tfstate*
terraform/terraform.tfstate.d/
terraform/*.tfvars  # Sauf .example
```

**Python:**
```gitignore
__pycache__/
*.py[cod]
*.so
.Python
venv/
```

**IDE:**
```gitignore
.vscode/
.idea/
*.swp
*.swo
```

**OS:**
```gitignore
.DS_Store
Thumbs.db
```

**Générés:**
```gitignore
participant-access/
archives/
*.log
*.backup
```

### Branches

**Branche Principale:** `main` ou `master`

**Branches de Fonctionnalité:**
- Format: `claude/{descriptif}-{id}`
- Exemple: `claude/add-dashboard-costs-xyz123`

**Règles:**
- Une branche par fonctionnalité
- Merge via Pull Request
- Review obligatoire (si équipe)

### Commits

**Format:**
```
Type: Description courte

Description détaillée si nécessaire.
```

**Types:**
- `feat`: Nouvelle fonctionnalité
- `fix`: Correction de bug
- `docs`: Documentation
- `refactor`: Refactoring
- `test`: Tests
- `chore`: Tâches diverses

**Exemples:**
```
feat: Ajouter calcul de coût AWS dans le dashboard

Implémente le calcul automatique du coût horaire et journalier
basé sur les types d'instances et le nombre de participants.
```

```
fix: Corriger la communication master-worker pour 11 participants

Ajustement de la configuration réseau pour supporter
plus de 10 participants simultanément.
```

### Push et Pull

**Push:**
```bash
git push -u origin {branch-name}
```

**Règles:**
- Toujours `-u` pour la première poussée
- Branche doit commencer par `claude/`
- Retry jusqu'à 4 fois si erreur réseau (backoff exponentiel)

**Pull:**
```bash
git pull origin {branch-name}
```

**Fetch:**
```bash
git fetch origin {branch-name}
```

### Pull Requests

**Processus:**
1. Push vers branche feature
2. Créer PR vers main
3. Review (si équipe)
4. Tests passent (si CI/CD)
5. Merge

**Template PR:**
```markdown
## Description
[Décrire les changements]

## Type de changement
- [ ] Nouvelle fonctionnalité
- [ ] Correction de bug
- [ ] Documentation
- [ ] Refactoring

## Tests effectués
- [ ] Test local
- [ ] Validation avec session-1
- [ ] Dashboard vérifié

## Checklist
- [ ] Code formaté (terraform fmt)
- [ ] Documentation mise à jour
- [ ] Pas de secrets committés
```

---

## Bonnes Pratiques

### Avant Chaque Session

**Checklist:**
1. ✅ Créer répertoire `participants/{session-name}/`
2. ✅ Créer fichier `sessions/{session-name}.tfvars`
3. ✅ Collecter les clés SSH ed25519 des participants
4. ✅ Valider toutes les clés: `./scripts/validate-ssh-keys.sh {session}`
5. ✅ Tester avec `worker_count = 0` d'abord
6. ✅ Vérifier les coûts estimés
7. ✅ Configurer `allowed_cidrs` appropriés
8. ✅ Documenter la session dans `participants/{session}/README.md`

### Pendant la Session

**Monitoring:**
```bash
# Lancer le dashboard
./scripts/start-dashboard.sh

# Vérifier le status régulièrement
./scripts/manage-session.sh status {session}

# Tester la connectivité d'un participant
ssh ubuntu@{master-ip} 'kubectl get nodes'
```

**Support Participants:**
- Distribuer access info via `generate-access-info.sh`
- Tester les commandes SSH avant distribution
- Avoir les outputs Terraform accessibles

### Après Chaque Session

**Archivage:**
```bash
# Créer l'archive
mkdir -p archives/{session-name}

# Copier les informations importantes
cp -r participant-access/{session-name} archives/{session-name}/
cd terraform
terraform output -json > ../archives/{session-name}/outputs.json
terraform show > ../archives/{session-name}/state-summary.txt

# Créer un README de session
cat > archives/{session-name}/README.md <<EOF
# Session: {session-name}

**Date:** DD-MM-YYYY
**Formateur:** Nom
**Participants:** XX
**Configuration:** t3.medium, 2 workers

## Notes
[Retours de la session]

## Coûts
[Coûts réels AWS]
EOF
```

**Nettoyage:**
```bash
# Détruire les ressources
./scripts/manage-session.sh destroy {session-name}

# Vérifier la destruction complète
aws ec2 describe-instances \
  --filters "Name=tag:Session,Values={session-name}" \
  --query 'Reservations[].Instances[].State.Name'

# Supprimer le workspace (optionnel)
cd terraform
terraform workspace select default
terraform workspace delete {session-name}
```

### Sécurité

1. **Ne jamais commit:**
   - `terraform.tfvars` (avec vraies valeurs)
   - Clés privées SSH
   - Tokens AWS
   - Outputs contenant IPs en production

2. **Rotation:**
   - Nouvelle clé SSH par session
   - Pas de réutilisation inter-sessions

3. **Restriction d'accès:**
   - Toujours restreindre `allowed_cidrs` en production
   - Ne jamais laisser 0.0.0.0/0 pour formations sensibles

4. **Nettoyage rapide:**
   - Détruire dans les 24h après la formation
   - Ne pas laisser tourner la nuit

### Déploiement

1. **Tester d'abord:**
   - Toujours `terraform plan` avant `apply`
   - Tester avec 0 workers pour validation rapide
   - Vérifier les coûts estimés

2. **Valider les inputs:**
   - SSH keys valides (ed25519)
   - Fichier tfvars correct
   - Workspace correct

3. **Monitoring:**
   - Surveiller les logs de déploiement
   - Vérifier que tous les workers rejoignent
   - Tester la connectivité SSH

### Performance

1. **Workers appropriés:**
   - 0 workers: Tests uniquement
   - 1-2 workers: Formations standard
   - 3-5 workers: Scénarios avancés
   - 5+ workers: Rarement nécessaire

2. **Instance types:**
   - t3.medium: Suffisant pour la plupart des cas
   - t3.large: Workloads intensifs
   - t3.xlarge: Rarement nécessaire

3. **Parallel sessions:**
   - VPC partagé supporte plusieurs sessions
   - Attention aux quotas AWS EC2
   - Monitoring des coûts cumulés

### Documentation

1. **Toujours documenter:**
   - Nouveaux scripts → help flag
   - Nouveaux modules → README.md
   - Nouvelles sessions → metadata dans README

2. **Mise à jour:**
   - Mettre à jour ce fichier PROJECT-RULES.md
   - Mettre à jour README principal si architecture change
   - Documenter les problèmes rencontrés

---

## Stack Technologique

### Infrastructure

**Cloud Provider:**
- **AWS** (Amazon Web Services)
- **Région par défaut:** eu-west-1 (Ireland)
- **Services utilisés:** EC2, VPC, IGW, NAT, Security Groups

**Infrastructure as Code:**
- **Terraform** >= 1.0
- **Modules:** VPC, K8s-cluster
- **State:** Local ou S3 (avec DynamoDB locking)

### Kubernetes

**Version:** 1.28 (configurable)

**Container Runtime:** Containerd

**CNI:** Calico

**Outils:**
- kubeadm (initialisation cluster)
- kubectl (gestion cluster)
- kubelet (agent node)

### Système d'Exploitation

**Distribution:** Ubuntu 22.04 LTS

**Source:** AMI officielle Canonical

**Virtualisation:** HVM

**Architecture:** x86_64

### Automatisation

**Scripts Shell:**
- Bash >= 4.0
- set -e pour error handling
- Color output avec ANSI codes

**Utilitaires:**
- jq (parsing JSON)
- ssh-keygen (validation clés)
- aws-cli (opérations AWS)

### Dashboard Web

**Framework:** Flask 3.0.0

**Langage:** Python 3

**Dépendances:**
- Flask >= 3.0.0
- Werkzeug >= 3.0.1

**Frontend:**
- HTML5
- CSS3 (embedded)
- JavaScript (auto-refresh)

### Développement

**Versioning:** Git

**Hosting:** GitHub

**CI/CD:** None (manuel)

**Testing:** Manuel + scripts de validation

### Types d'Instances AWS

**Recommandés:**
- **t3.medium:** 2 vCPU, 4 GB RAM - Standard
- **t3.large:** 2 vCPU, 8 GB RAM - Workloads intensifs
- **t3.xlarge:** 4 vCPU, 16 GB RAM - Rare

**Famille T3:**
- Burstable performance
- Équilibre CPU/mémoire
- Bon rapport qualité/prix pour labs

### Networking

**VPC CIDR:** 10.0.0.0/16

**Pod Networks:** 10.100.0.0/16 - 10.255.0.0/16

**Service Network:** 10.96.0.0/12 (Kubernetes default)

**DNS:** AWS VPC DNS

**Load Balancing:** None (accès direct master IP)

---

## Règles de Mise à Jour de ce Document

### Quand Mettre à Jour

**Obligatoire:**
1. Ajout d'une nouvelle convention de nommage
2. Modification de la structure des répertoires
3. Nouveau module Terraform
4. Nouvelle variable obligatoire
5. Changement de processus de déploiement
6. Nouvelles règles de sécurité
7. Modification de l'architecture réseau

**Recommandé:**
1. Ajout de nouvelles bonnes pratiques
2. Nouvelles commandes utiles
3. Nouveaux exemples
4. Lessons learned de sessions
5. Optimisations de coûts

### Comment Mettre à Jour

**Processus:**
1. Éditer `docs/PROJECT-RULES.md`
2. Mettre à jour la version en en-tête
3. Mettre à jour "Dernière mise à jour"
4. Ajouter note de changement si majeur
5. Commit avec message explicite
6. Push vers branche feature
7. PR pour review si équipe

**Format des Changements:**
```markdown
## Historique des Versions

### Version 1.1 - 2025-12-15
- Ajout: Nouvelle section sur XYZ
- Modification: Règle ABC mise à jour
- Suppression: Règle obsolète DEF

### Version 1.0 - 2025-12-12
- Version initiale
```

---

## Conclusion

Ce document `PROJECT-RULES.md` sert de référence unique et centralisée pour toutes les règles, conventions et standards du projet Kubernetes AWS Lab.

**Objectifs atteints:**
- ✅ Documentation complète de toutes les règles projet
- ✅ Référence unique pour les itérations futures
- ✅ Standards de code clairs
- ✅ Processus documentés
- ✅ Bonnes pratiques établies

**Utilisation:**
- Consulter avant chaque nouvelle fonctionnalité
- Référencer dans les code reviews
- Partager avec nouveaux contributeurs
- Mettre à jour régulièrement

**Maintenance:**
- Document vivant, à jour avec le projet
- Version trackée dans Git
- Historique des changements
- Review régulière pour pertinence

---

**Pour toute question ou suggestion d'amélioration de ce document, ouvrir une issue ou PR.**
