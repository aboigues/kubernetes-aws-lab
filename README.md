# Kubernetes AWS Lab

Infrastructure as Code pour déployer des clusters Kubernetes isolés sur AWS pour des sessions de formation ou de test.

## Vue d'ensemble

Ce projet permet de déployer automatiquement plusieurs clusters Kubernetes multi-nœuds isolés sur AWS, chaque cluster étant dédié à un participant. Les clusters partagent un VPC commun mais sont complètement isolés les uns des autres via des security groups dédiés.

### Architecture

- **VPC partagé** : Un seul VPC pour tous les clusters
- **Clusters isolés** : Un cluster Kubernetes par participant avec :
  - 1 master node (t3.medium par défaut)
  - 2 worker nodes (t3.small par défaut)
- **Accès SSH** : Chaque participant utilise sa propre clé SSH ed25519
- **Réseau** : Chaque cluster a son propre pod network CIDR pour éviter les conflits

### Composants

- **Kubernetes 1.28** avec kubeadm
- **Containerd** comme container runtime
- **Calico** comme CNI (Container Network Interface)
- **Ubuntu 22.04 LTS** sur toutes les instances

## Prérequis

- [Terraform](https://www.terraform.io/downloads) >= 1.0
- [AWS CLI](https://aws.amazon.com/cli/) configuré avec les credentials appropriés
- Droits AWS pour créer VPC, EC2, Security Groups, etc.

## Installation rapide

### 1. Déposer votre clé SSH publique

Chaque participant doit déposer sa clé SSH publique dans le répertoire de session approprié :

```bash
# Générer une clé ed25519 si nécessaire
ssh-keygen -t ed25519

# Créer votre fichier de clé dans le répertoire de session
cat ~/.ssh/id_ed25519.pub > participants/session-XXXXX/prenom.nom.pub

# Commiter
git add participants/session-XXXXX/prenom.nom.pub
git commit -m "Add SSH key for prenom.nom"
git push
```

**Note :** Le nom du fichier sera automatiquement transformé en format discret (prénom + 2 lettres du nom) pour préserver la confidentialité.

Voir [participants/README.md](participants/README.md) pour plus de détails.

### 2. Valider les clés SSH

```bash
# Valider les clés d'une session spécifique
./scripts/validate-ssh-keys.sh participants/session-XXXXX

# Ou valider toutes les clés dans participants/ (racine uniquement)
./scripts/validate-ssh-keys.sh
```

### 3. Déployer l'infrastructure

```bash
cd terraform

# Initialiser Terraform
terraform init

# Voir ce qui va être créé
terraform plan

# Déployer
terraform apply
```

### 4. Accéder à votre cluster

Après le déploiement, Terraform affichera les informations de connexion :

```bash
# Récupérer l'IP de votre master node
terraform output

# Se connecter en SSH
ssh ubuntu@<master-ip>

# Vérifier le cluster
kubectl get nodes
kubectl get pods --all-namespaces
```

## Structure du projet

```
kubernetes-aws-lab/
├── README.md                          # Ce fichier
├── docs/                              # Documentation
│   ├── SESSION-MANAGEMENT.md          # Guide gestion des sessions
│   └── PARTICIPANT-ACCESS-SOLUTIONS.md # Solutions de distribution des accès
├── participants/                      # Clés SSH publiques des participants
│   ├── README.md                      # Instructions pour les participants
│   ├── example.user.pub.example       # Exemple de clé (à renommer en .pub)
│   └── session-XXXXX/                 # Répertoire par session
│       ├── README.md                  # Infos de la session
│       ├── example.user.pub.example   # Exemple de clé (à renommer en .pub)
│       └── prenom.nom.pub             # Clés des participants
├── scripts/
│   ├── validate-ssh-keys.sh           # Script de validation des clés
│   └── generate-access-info.sh        # Génération des infos d'accès
└── terraform/                         # Infrastructure Terraform
    ├── main.tf                        # Configuration principale
    ├── variables.tf                   # Variables Terraform
    ├── outputs.tf                     # Outputs Terraform
    ├── terraform.tfvars.example       # Exemple de configuration
    └── modules/
        ├── vpc/                       # Module VPC partagé
        │   ├── main.tf
        │   ├── variables.tf
        │   └── outputs.tf
        └── k8s-cluster/               # Module cluster Kubernetes
            ├── main.tf
            ├── variables.tf
            ├── outputs.tf
            ├── user-data-master.sh    # Script d'init master node
            └── user-data-worker.sh    # Script d'init worker node
```

## Configuration

### Variables Terraform principales

Vous pouvez personnaliser le déploiement en créant un fichier `terraform.tfvars` (voir `terraform.tfvars.example`) :

```hcl
# Session identifier (pour le suivi des coûts)
session_name = "session-nov-2025"

# Région AWS
aws_region = "eu-west-1"

# Configuration réseau
vpc_cidr = "10.0.0.0/16"
availability_zones = ["eu-west-1a", "eu-west-1b"]

# Sécurité - Restreindre l'accès SSH et API (recommandé)
allowed_ssh_cidrs = ["0.0.0.0/0"]  # IPs autorisées pour SSH
allowed_api_cidrs = ["0.0.0.0/0"]  # IPs autorisées pour Kubernetes API

# Type d'instances
instance_type_master = "t3.medium"  # 2 vCPU, 4 GB RAM
instance_type_worker = "t3.small"   # 2 vCPU, 2 GB RAM

# Nombre de workers par cluster
worker_count = 2

# Version Kubernetes
kubernetes_version = "1.28"

# Nom du projet
project_name = "k8s-lab"
```

### Coûts estimés

Pour un déploiement avec 5 participants en eu-west-1 :

- 5 master nodes (t3.medium) : ~$0.0416/heure × 5 = ~$0.21/heure
- 10 worker nodes (t3.small) : ~$0.0208/heure × 10 = ~$0.21/heure
- NAT Gateway : ~$0.045/heure × 2 = ~$0.09/heure
- Total : **~$0.51/heure** (~$12/jour)

⚠️ **Important** : Pensez à détruire l'infrastructure quand vous ne l'utilisez plus !

```bash
cd terraform
terraform destroy
```

## Utilisation

### Commandes utiles sur le master node

```bash
# Voir les nœuds du cluster
kubectl get nodes

# Voir tous les pods
kubectl get pods --all-namespaces

# Déployer une application de test
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80 --type=NodePort

# Voir les services
kubectl get services

# Informations du cluster
/home/ubuntu/cluster-info.sh
```

### Ajouter un participant

1. Le participant ajoute sa clé dans `participants/session-XXXXX/`
2. Valider avec `./scripts/validate-ssh-keys.sh participants/session-XXXXX`
3. Appliquer les changements : `cd terraform && terraform apply`

### Retirer un participant

1. Supprimer le fichier de clé du participant dans `participants/session-XXXXX/`
2. Appliquer les changements : `cd terraform && terraform apply`

Le cluster du participant sera automatiquement détruit.

## Résolution de problèmes

### Les worker nodes ne rejoignent pas le cluster

SSH sur le worker node et vérifier les logs :

```bash
ssh ubuntu@<worker-ip>
sudo tail -f /var/log/user-data.log
```

### Le cluster n'est pas accessible

Vérifier les security groups dans la console AWS.

### Problèmes de réseau

Vérifier que Calico est bien déployé :

```bash
kubectl get pods -n kube-system | grep calico
```

## Gestion des Sessions de Formation

Ce projet supporte maintenant la gestion de sessions de formation avec :

- **📁 Organisation par session** : Créez des sous-répertoires dans `participants/` pour chaque session
- **💰 Suivi des coûts AWS** : Tags automatiques par session pour AWS Cost Explorer
- **📨 Distribution automatique** : Script pour générer et distribuer les accès aux participants
- **🔒 Sécurité configurable** : VPC et Security Groups paramétrables

### Démarrage rapide pour une session

```bash
# 1. Créer une session
mkdir -p participants/session-nov-2025

# 2. Les participants ajoutent leurs clés
# participants/session-nov-2025/prenom.nom.pub

# 3. Configurer Terraform
cat > terraform/terraform.tfvars << EOF
session_name = "session-nov-2025"
allowed_ssh_cidrs = ["0.0.0.0/0"]  # ou IP spécifique
allowed_api_cidrs = ["0.0.0.0/0"]
EOF

# 4. Déployer
cd terraform && terraform apply

# 5. Distribuer les accès
cd .. && ./scripts/generate-access-info.sh
```

### Documentation détaillée

- **[Guide de gestion des sessions](docs/SESSION-MANAGEMENT.md)** - Configuration et organisation des sessions
- **[Solutions de communication](docs/PARTICIPANT-ACCESS-SOLUTIONS.md)** - Comment distribuer les accès aux participants

### Suivi des coûts AWS

Toutes les ressources sont automatiquement taguées avec `Session = <nom-session>` :

```bash
# Dans AWS Cost Explorer
Filtrer par Tag: Session = session-nov-2025

# Ou via Terraform
cd terraform && terraform output session_info
```

## Améliorations possibles

- [ ] Utiliser un bastion host au lieu d'exposer les masters publiquement
- [ ] Ajouter un monitoring (Prometheus/Grafana)
- [ ] Configurer des backups automatiques avec Velero
- [ ] Utiliser un load balancer pour l'API server
- [ ] Ajouter des exemples d'applications à déployer
- [ ] Implémenter des quotas par namespace
- [ ] Ajouter des dashboards Kubernetes (Dashboard officiel)

## Sécurité

⚠️ **Attention** : Cette configuration est prévue pour des environnements de formation/test. Pour la production :

- Ne pas exposer les master nodes publiquement
- Utiliser un bastion host ou VPN
- Activer l'audit logging
- Implémenter des Network Policies strictes
- Utiliser des secrets chiffrés (KMS)
- Activer le chiffrement des disques EBS
- Configurer des rôles IAM appropriés

## Licence

MIT

## Contribution

Les contributions sont les bienvenues ! N'hésitez pas à ouvrir une issue ou une pull request.
