# Quick Start - Sessions Parallèles

Guide rapide pour démarrer avec les sessions parallèles.

## Vue d'ensemble

Ce système permet de déployer plusieurs configurations Kubernetes en parallèle :

| Session | Master | Workers | Cas d'usage |
|---------|--------|---------|-------------|
| session-1 | t3.medium | 0 | Test, démo rapide |
| session-2 | t3.medium | 2 | Formation standard |
| session-3 | t3.large | 5 | Simulation production |

## Démarrage rapide (5 minutes)

### 1. Voir les sessions disponibles

```bash
./scripts/manage-session.sh list
```

### 2. Préparer une session

```bash
# Créer le répertoire participants pour session-1
mkdir -p participants/session-1

# Ajouter votre clé SSH ed25519 (remplacer par votre nom)
cat ~/.ssh/id_ed25519.pub > participants/session-1/alice.smith.pub

# Vérifier la configuration
cat sessions/session-1.tfvars
```

### 3. Déployer

```bash
# Initialiser la session
./scripts/manage-session.sh init session-1

# Voir ce qui sera créé
./scripts/manage-session.sh plan session-1

# Déployer l'infrastructure
./scripts/manage-session.sh apply session-1
```

### 4. Accéder au cluster

```bash
# Voir les outputs (IPs, etc.)
./scripts/manage-session.sh output session-1

# Se connecter au master
ssh ubuntu@<master-ip>

# Vérifier le cluster
kubectl get nodes
```

### 5. Nettoyer

```bash
# Détruire l'infrastructure
./scripts/manage-session.sh destroy session-1
```

## Déploiement de plusieurs sessions en parallèle

### Option 1: Terminaux multiples

**Terminal 1:**
```bash
./scripts/manage-session.sh apply session-1
```

**Terminal 2:**
```bash
./scripts/manage-session.sh apply session-2
```

**Terminal 3:**
```bash
./scripts/manage-session.sh apply session-3
```

### Option 2: Jobs en arrière-plan

```bash
# Démarrer tous les déploiements
./scripts/manage-session.sh apply session-1 &
./scripts/manage-session.sh apply session-2 &
./scripts/manage-session.sh apply session-3 &

# Attendre que tous se terminent
wait

echo "Tous les déploiements terminés!"
```

## Créer une nouvelle session personnalisée

```bash
# Créer la configuration
./scripts/manage-session.sh create-config ma-session

# Éditer la configuration (changer worker_count, etc.)
vi sessions/ma-session.tfvars

# Créer le répertoire participants
mkdir -p participants/ma-session

# Ajouter les clés SSH ed25519
cp /path/to/keys/*.pub participants/ma-session/

# Déployer
./scripts/manage-session.sh init ma-session
./scripts/manage-session.sh apply ma-session
```

## Exemples de configurations

### Configuration minimale (tests)

```hcl
# sessions/test.tfvars
session_name = "test"
worker_count = 0
instance_type_master = "t3.small"
# Coût: ~0.02€/heure par participant
```

### Configuration standard (formation)

```hcl
# sessions/formation.tfvars
session_name = "formation"
worker_count = 2
instance_type_master = "t3.medium"
instance_type_worker = "t3.small"
# Coût: ~0.08€/heure par participant
```

### Configuration large (production)

```hcl
# sessions/prod-sim.tfvars
session_name = "prod-sim"
worker_count = 5
instance_type_master = "t3.large"
instance_type_worker = "t3.medium"
# Coût: ~0.29€/heure par participant
```

## Commandes utiles

```bash
# Lister toutes les sessions
./scripts/manage-session.sh list

# Voir les workspaces Terraform
./scripts/manage-session.sh workspaces

# Vérifier le statut d'une session
./scripts/manage-session.sh status session-1

# Voir les outputs d'une session
./scripts/manage-session.sh output session-1

# Basculer sur une session (pour commandes terraform manuelles)
./scripts/manage-session.sh switch session-1
```

## Comparaison des approches

### Approche classique (avant)

```bash
# Une seule configuration, déploiement séquentiel
cd terraform
terraform apply
# Attendre la fin (10-15 min)
terraform destroy
# Modifier terraform.tfvars
terraform apply
# Attendre encore (10-15 min)
```

### Approche parallèle (maintenant)

```bash
# Plusieurs configurations, déploiement parallèle
./scripts/manage-session.sh apply session-1 &
./scripts/manage-session.sh apply session-2 &
./scripts/manage-session.sh apply session-3 &
wait
# Toutes les sessions déployées en même temps!
```

## Workflow typique pour une formation

### Préparation (1 jour avant)

```bash
# 1. Créer la configuration
./scripts/manage-session.sh create-config formation-dec-2025

# 2. Ajuster worker_count selon le besoin
vi sessions/formation-dec-2025.tfvars

# 3. Créer le répertoire participants
mkdir -p participants/formation-dec-2025

# 4. Demander aux participants d'ajouter leurs clés SSH ed25519
# (ou les ajouter vous-même)
```

### Jour J (matin)

```bash
# 1. Vérifier les clés SSH
./scripts/validate-ssh-keys.sh participants/formation-dec-2025

# 2. Déployer
./scripts/manage-session.sh init formation-dec-2025
./scripts/manage-session.sh apply formation-dec-2025

# 3. Distribuer les infos de connexion
./scripts/generate-access-info.sh
```

### Jour J (soir)

```bash
# Détruire l'infrastructure pour économiser
./scripts/manage-session.sh destroy formation-dec-2025
```

### Jours suivants (si multi-jours)

```bash
# Redéployer le matin
./scripts/manage-session.sh apply formation-dec-2025

# Détruire le soir
./scripts/manage-session.sh destroy formation-dec-2025
```

## Suivi des coûts

Chaque session est taguée dans AWS pour un suivi facile :

```bash
# Dans AWS Cost Explorer
Tag: Session = session-1
Tag: Project = k8s-lab
```

Coûts estimés (eu-west-1):

| Configuration | Coût/heure/participant | Coût/jour (8h) | Coût/semaine (5j x 8h) |
|---------------|----------------------|----------------|---------------------|
| session-1 (0 workers) | 0.04€ | 0.32€ | 1.60€ |
| session-2 (2 workers) | 0.08€ | 0.64€ | 3.20€ |
| session-3 (5 workers) | 0.29€ | 2.32€ | 11.60€ |

Pour 10 participants sur session-2:
- **Coût journée (8h)**: ~6.40€
- **Coût semaine (5j x 8h)**: ~32€

## Troubleshooting

### "No participant SSH keys found"

```bash
# Vérifier le répertoire
ls -la participants/session-1/

# Ajouter au moins une clé ed25519
cat ~/.ssh/id_ed25519.pub > participants/session-1/test.user.pub
```

### "Workspace not found"

```bash
# Initialiser d'abord
./scripts/manage-session.sh init session-1
```

### "Session config not found"

```bash
# Créer la configuration
./scripts/manage-session.sh create-config ma-session
```

### Voir les logs détaillés

```bash
export TF_LOG=DEBUG
./scripts/manage-session.sh plan session-1
```

## Pour aller plus loin

- **Documentation complète**: [docs/PARALLEL-SESSIONS.md](docs/PARALLEL-SESSIONS.md)
- **Gestion des sessions**: [docs/SESSION-MANAGEMENT.md](docs/SESSION-MANAGEMENT.md)
- **Backend S3**: Voir [terraform/backend.tf](terraform/backend.tf) pour configuration production

## Support

Pour toute question :

1. Vérifier le statut: `./scripts/manage-session.sh status <session>`
2. Consulter la documentation: `docs/PARALLEL-SESSIONS.md`
3. Vérifier les logs Terraform en mode debug
