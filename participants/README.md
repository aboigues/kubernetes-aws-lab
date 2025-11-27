# Dépôt des clés SSH publiques

## Organisation par sessions

Ce répertoire peut être organisé de deux façons :

### Option 1 : Clés directement dans `participants/`
Pour une utilisation simple ou des formations ponctuelles, déposez directement votre clé ici.

### Option 2 : Organisation par session (recommandé pour les formations)
Pour gérer plusieurs sessions de formation, organisez les clés dans des sous-répertoires :

```
participants/
├── session-nov-2025/
│   ├── README.md
│   ├── jean.martin.pub
│   └── marie.dupont.pub
└── session-dec-2025/
    ├── README.md
    └── pierre.durand.pub
```

Voir [docs/SESSION-MANAGEMENT.md](../docs/SESSION-MANAGEMENT.md) pour plus de détails sur la gestion des sessions.

## Comment déposer votre clé publique

### 1. Générer votre clé SSH ed25519 (si nécessaire)

```bash
ssh-keygen -t ed25519 -C "votre.email@example.com"
```

### 2. Récupérer votre clé publique

```bash
cat ~/.ssh/id_ed25519.pub
```

### 3. Créer votre fichier dans ce dossier

Créez un fichier nommé `prenom.nom.pub` contenant votre clé publique.

**Format du nom de fichier :** `prenom.nom.pub`

**Exemple :** `john.doe.pub`

**Contenu :** Votre clé publique ed25519 complète (commence par `ssh-ed25519`)

**Emplacement** :
- Sans session : `participants/votre.nom.pub`
- Avec session : `participants/session-XXXXX/votre.nom.pub`

### 4. Soumettre votre clé

```bash
# Cloner le dépôt
git clone <repository-url>
cd kubernetes-aws-lab

# Option 1 : Sans session
echo "ssh-ed25519 AAAA... votre-email@example.com" > participants/votre.nom.pub

# Option 2 : Avec session
echo "ssh-ed25519 AAAA... votre-email@example.com" > participants/session-nov-2025/votre.nom.pub

# Commiter et pousser
git add participants/
git commit -m "Add SSH key for votre.nom"
git push
```

## Format attendu

Chaque fichier doit contenir **une seule ligne** avec :
- Type de clé : `ssh-ed25519`
- La clé publique encodée en base64
- (Optionnel) Un commentaire/email

**Exemple de contenu valide :**
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl john.doe@example.com
```

## Validation

Pour vérifier que votre clé est valide avant de la soumettre :

```bash
./scripts/validate-ssh-keys.sh participants/votre.nom.pub
```

## Accès à votre cluster

Une fois votre clé déposée et le déploiement effectué, vous recevrez :
- L'adresse IP de votre master node
- Le nom de votre cluster
- Les instructions de connexion

```bash
ssh ubuntu@<master-ip>
kubectl get nodes
```
