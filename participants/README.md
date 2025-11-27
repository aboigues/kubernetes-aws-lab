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
ssh-keygen -t ed25519
```

### 2. Récupérer votre clé publique

```bash
cat ~/.ssh/id_ed25519.pub
```

### 3. Créer votre fichier dans le répertoire de session

Créez un fichier nommé `prenom.nom.pub` contenant votre clé publique dans le répertoire de session approprié.

**Format du nom de fichier :** `prenom.nom.pub`

**Exemple :** `john.doe.pub`

**Contenu :** Votre clé publique ed25519 complète (commence par `ssh-ed25519`)

**Emplacement recommandé** : `participants/session-XXXXX/votre.nom.pub`

**Note importante sur la confidentialité :**
- Le nom du fichier sera automatiquement transformé en format discret : `prenom.no` (prénom + 2 premières lettres du nom)
- Exemple : `john.doe.pub` → identifiant `john.do` dans AWS
- N'incluez JAMAIS d'adresse email dans le nom du fichier
- L'email dans le commentaire de la clé SSH est optionnel et ne sera pas utilisé par Terraform

### 4. Soumettre votre clé

```bash
# Cloner le dépôt
git clone <repository-url>
cd kubernetes-aws-lab

# Déposer votre clé dans le répertoire de session (remplacer session-XXXXX par le nom de votre session)
echo "ssh-ed25519 AAAA..." > participants/session-XXXXX/votre.nom.pub

# Commiter et pousser
git add participants/session-XXXXX/votre.nom.pub
git commit -m "Add SSH key for votre.nom"
git push
```

## Format attendu

Chaque fichier doit contenir **une seule ligne** avec :
- Type de clé : `ssh-ed25519`
- La clé publique encodée en base64
- (Optionnel) Un commentaire (SANS email)

**Exemple de contenu valide :**
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
```

**Note :** Les fichiers `example.user.pub.example` dans ce dépôt sont des exemples. Pour les utiliser, renommez-les en `.pub` et remplacez leur contenu par votre clé réelle.

## Validation

Pour vérifier que votre clé est valide avant de la soumettre :

```bash
# Valider une clé spécifique
./scripts/validate-ssh-keys.sh participants/session-XXXXX/votre.nom.pub

# Valider toutes les clés d'une session
./scripts/validate-ssh-keys.sh participants/session-XXXXX
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
