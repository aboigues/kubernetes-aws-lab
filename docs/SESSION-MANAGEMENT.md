# Gestion des Sessions de Formation

Ce guide explique comment organiser et gérer des sessions de formation avec le système de gestion de sessions.

## Vue d'ensemble

Le système de sessions permet de :
- **Organiser** les participants par session de formation
- **Suivre les coûts** AWS par session via des tags
- **Distribuer facilement** les accès aux participants
- **Isoler** les ressources entre différentes sessions

## 1. Créer une nouvelle session

### Structure des répertoires

Créez un sous-répertoire dans `participants/` pour chaque session :

```bash
# Format recommandé: session-MOIS-ANNEE (simple et lisible)
mkdir -p participants/session-nov-2025

# Créer le README de la session
cat > participants/session-nov-2025/README.md << 'EOF'
# Session: session-nov-2025

## Informations de la session
- **Date**: 12-13 Novembre 2025
- **Formateur**: Jean Dupont
- **Nombre de participants**: 10

## Participants
Voir les fichiers .pub dans ce répertoire
EOF
```

### Naming Convention

Le nom du répertoire de session sera utilisé comme :
1. **Tag AWS** : `Session = session-nov-2025`
2. **Filtre dans AWS Cost Explorer** pour le suivi des dépenses
3. **Identifiant** dans les outputs Terraform

**Format recommandé** : `session-MOIS-ANNEE` (ou tout format descriptif de votre choix)

Exemples :
- `session-nov-2025` (recommandé : simple et lisible)
- `session-dec-2025`
- `session-winter-2025`
- `session-formation-k8s-q4-2025`

> **Note** : Le format est flexible - utilisez ce qui convient le mieux à votre organisation. L'important est d'être cohérent et descriptif.

## 2. Collecter les clés SSH des participants

Les participants déposent leurs clés dans le répertoire de session :

```bash
# Les participants créent leurs clés
ssh-keygen -t ed25519 -C "participant@example.com"

# Et les déposent dans le répertoire de session
cat ~/.ssh/id_ed25519.pub > participants/session-nov-2025/jean.martin.pub
```

Structure finale :
```
participants/
└── session-nov-2025/
    ├── README.md
    ├── jean.martin.pub
    ├── marie.dubois.pub
    ├── pierre.bernard.pub
    └── ...
```

## 3. Configurer Terraform pour la session

Créez ou modifiez `terraform/terraform.tfvars` :

```hcl
# Session identifier - MUST match the directory name
session_name = "session-nov-2025"

# AWS Configuration
aws_region = "eu-west-1"

# VPC Configuration
vpc_cidr           = "10.0.0.0/16"
availability_zones = ["eu-west-1a", "eu-west-1b"]

# Security - Restrict access if needed
allowed_ssh_cidrs = ["0.0.0.0/0"]  # Or restrict to office IP
allowed_api_cidrs = ["0.0.0.0/0"]

# Instance types
instance_type_master = "t3.medium"
instance_type_worker = "t3.small"
worker_count         = 2

# Kubernetes version
kubernetes_version = "1.28"
```

## 4. Déployer l'infrastructure

```bash
cd terraform

# Initialiser Terraform (première fois seulement)
terraform init

# Vérifier le plan
terraform plan

# Déployer
terraform apply
```

Terraform va :
1. Lire toutes les clés `.pub` du répertoire de session
2. Créer un cluster par participant
3. Taguer TOUTES les ressources AWS avec `Session = session-nov-2025`

## 5. Distribuer les accès aux participants

### Option 1 : Script automatique (Recommandé)

```bash
# Générer tous les fichiers d'accès pour une session
./scripts/generate-access-info.sh <session-name>

# Exemple pour session-1
./scripts/generate-access-info.sh session-1
```

Ce script crée :
- **Fichiers individuels** dans `participant-access/<session-name>/` :
  - `jean.martin-access.txt`
  - `marie.dubois-access.txt`
  - etc.
- **Fichier CSV** : `participant-access/<session-name>/participants-<session-name>.csv`
- **Affichage console** : Template email/Slack

### Option 2 : Terraform Output

```bash
cd terraform
terraform output participant_access_info
```

### Option 3 : Fichiers individuels

Envoyez le fichier `participant-access/nom.participant-access.txt` par email à chaque participant.

**Exemple de contenu** :
```
=================================================
Kubernetes Lab Access Information
=================================================

Participant: jean.martin
Session: session-nov-2025

Master Node: 54.123.45.67

SSH Access:
  ssh ubuntu@54.123.45.67

Getting Started:
1. Connect to your master node:
   ssh ubuntu@54.123.45.67

2. Verify cluster is ready:
   kubectl get nodes

3. View detailed cluster information:
   /home/ubuntu/cluster-info.sh
...
```

### Option 4 : Message groupé Slack/Email

```
Hi Team,

Your Kubernetes lab environment is ready! Here are your access details:

Participant: jean.martin
Master IP: 54.123.45.67
SSH: ssh ubuntu@54.123.45.67
Workers: 2 nodes
---

Participant: marie.dubois
Master IP: 54.123.45.89
SSH: ssh ubuntu@54.123.45.89
Workers: 2 nodes
---

To get started:
1. SSH into your master node using the command above
2. Run: kubectl get nodes
3. Run: /home/ubuntu/cluster-info.sh for cluster details

The environment will be available until [DATE/TIME].

Happy Learning!
```

## 6. Suivre les coûts AWS

### Dans AWS Cost Explorer

1. Accédez à **AWS Cost Explorer**
2. Cliquez sur **Filters**
3. Sélectionnez **Tag** → **Session**
4. Choisissez `session-nov-2025`
5. Sélectionnez la période de la formation

Vous verrez tous les coûts liés uniquement à cette session.

### Depuis Terraform

```bash
cd terraform
terraform output session_info
```

Output :
```json
{
  "session_name": "session-nov-2025",
  "participant_count": 10,
  "total_instances": 30,
  "aws_cost_explorer_filter": "Tag: Session = session-nov-2025"
}
```

### Avec AWS CLI

```bash
# Get costs for a specific session
aws ce get-cost-and-usage \
  --time-period Start=2025-11-12,End=2025-11-14 \
  --granularity DAILY \
  --metrics "UnblendedCost" \
  --filter file://<(cat <<EOF
{
  "Tags": {
    "Key": "Session",
    "Values": ["session-nov-2025"]
  }
}
EOF
)
```

## 7. Après la session : Nettoyage

### Détruire toute l'infrastructure

```bash
cd terraform
terraform destroy
```

**Important** : Cela supprime TOUS les clusters de la session !

### Archive la session

```bash
# Sauvegarder les informations
mkdir -p archives/session-nov-2025
cp -r participant-access archives/session-nov-2025/
cp terraform/terraform.tfstate archives/session-nov-2025/
```

## Multiples sessions en parallèle

Pour gérer plusieurs sessions simultanément, utilisez des **Terraform Workspaces** ou des **répertoires séparés** :

### Option 1 : Workspaces (Recommandé)

```bash
cd terraform

# Créer un workspace par session
terraform workspace new session-nov-2025
terraform workspace new session-jan-2026

# Basculer entre sessions
terraform workspace select session-nov-2025
terraform apply -var="session_name=session-nov-2025"

terraform workspace select session-jan-2026
terraform apply -var="session_name=session-jan-2026"
```

### Option 2 : Répertoires séparés

```bash
# Structure
terraform-sessions/
├── session-nov-2025/
│   ├── main.tf -> ../../terraform/main.tf (symlink)
│   ├── terraform.tfvars
│   └── .terraform/
└── session-jan-2026/
    ├── main.tf -> ../../terraform/main.tf (symlink)
    ├── terraform.tfvars
    └── .terraform/
```

## Bonnes pratiques

### ✅ À faire

1. **Nommer clairement** les sessions avec date et contexte
2. **Détruire** l'infrastructure après la formation
3. **Documenter** dans le README de session les détails
4. **Archiver** les informations importantes
5. **Restreindre les accès** avec `allowed_ssh_cidrs` et `allowed_api_cidrs`
6. **Suivre les coûts** régulièrement via Cost Explorer
7. **Tester le déploiement** 1-2 jours avant la formation

### ❌ À éviter

1. Ne pas spécifier de `session_name` si vous gérez plusieurs sessions
2. Laisser l'infrastructure active après la formation
3. Utiliser le même répertoire de participants pour plusieurs sessions
4. Oublier de communiquer les accès avant la formation
5. Ne pas vérifier que tous les clusters sont prêts avant la formation

## Dépannage

### Problème : "No SSH keys found"

```bash
# Vérifier que les clés sont bien dans le bon répertoire
ls -la participants/session-nov-2025/*.pub

# Vérifier la configuration session_name
grep session_name terraform/terraform.tfvars
```

### Problème : Les coûts ne s'affichent pas dans Cost Explorer

- Les tags peuvent mettre jusqu'à 24h à apparaître dans Cost Explorer
- Vérifiez que les ressources ont bien le tag `Session` :

```bash
# Vérifier les tags EC2
aws ec2 describe-instances \
  --filters "Name=tag:Session,Values=session-nov-2025" \
  --query 'Reservations[].Instances[].Tags'
```

### Problème : Impossible de se connecter en SSH

1. Vérifier les Security Groups :
   ```bash
   cd terraform
   terraform output clusters
   ```

2. Vérifier votre IP publique :
   ```bash
   curl -s ifconfig.me
   ```

3. Ajuster `allowed_ssh_cidrs` si nécessaire

## Exemple complet de workflow

```bash
# 1. Créer la session
mkdir -p participants/session-nov-2025

# 2. Les participants ajoutent leurs clés
# (via PR ou accès direct au repo)

# 3. Configurer Terraform
cat > terraform/terraform.tfvars << 'EOF'
session_name = "session-nov-2025"
aws_region = "eu-west-1"
EOF

# 4. Déployer (nouvelle approche avec manage-session.sh)
./scripts/manage-session.sh init session-nov-2025
./scripts/manage-session.sh apply session-nov-2025

# 5. Générer et distribuer les accès
./scripts/generate-access-info.sh session-nov-2025

# 6. Envoyer les fichiers aux participants
for file in participant-access/session-nov-2025/*-access.txt; do
  echo "Email $file to participant"
  # Ou utiliser un script d'envoi automatique
done

# 7. Après la formation
cd terraform
terraform destroy

# 8. Archiver
mkdir -p archives/session-nov-2025
mv participant-access archives/session-nov-2025/
```

## Support

Pour toute question sur la gestion des sessions :
1. Consultez la documentation principale : `README.md`
2. Vérifiez les logs Terraform : `terraform show`
3. Contactez l'équipe infrastructure
