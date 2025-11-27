# Gestion des noms de participants

## Format discret pour la confidentialité

Pour préserver la confidentialité des participants, les noms de fichiers sont automatiquement transformés en format discret par Terraform.

### Transformation automatique

**Format du fichier :** `prenom.nom.pub`

**Format dans AWS :** `prenom.no`

### Exemples de transformation

| Fichier de clé SSH | Identifiant dans AWS | Ressources créées |
|-------------------|---------------------|------------------|
| `john.doe.pub` | `john.do` | `k8s-lab-john.do-master` |
| `marie.dupont.pub` | `marie.du` | `k8s-lab-marie.du-master` |
| `pierre.martin.pub` | `pierre.ma` | `k8s-lab-pierre.ma-master` |
| `alice.wonderland.pub` | `alice.wo` | `k8s-lab-alice.wo-master` |

### Règles de transformation

1. **Prénom complet** : Le prénom est conservé tel quel
2. **Nom raccourci** : Seules les 2 premières lettres du nom sont utilisées
3. **Pas d'email** : Aucune référence à l'email n'est utilisée dans les ressources AWS
4. **Noms de ressources** : Format `{projet}-{prenom.no}-{ressource}`

### Implémentation dans Terraform

La transformation est effectuée dans `terraform/main.tf` :

```hcl
# Generate discrete participant names (prenom + 2 letters of nom)
# Format: prenom.nom.pub -> prenom.no
discrete_names = {
  for file in local.ssh_key_files :
  file => (
    length(split(".", replace(file, ".pub", ""))) >= 2 ?
    "${split(".", replace(file, ".pub", ""))[0]}.${substr(split(".", replace(file, ".pub", ""))[1], 0, 2)}" :
    replace(file, ".pub", "")
  )
}
```

### Avantages

1. **Confidentialité** : Le nom complet n'apparaît jamais dans AWS
2. **Traçabilité** : Le nom du fichier original reste identifiable pour l'administrateur
3. **Sécurité** : Pas de données personnelles sensibles (emails) dans les métadonnées AWS
4. **Simplicité** : Transformation automatique, aucune action manuelle requise

### Gestion des sessions

Les noms de participants sont toujours associés à une session via le tag `Session` :

```hcl
tags = {
  Project     = "k8s-lab"
  Participant = "john.do"
  Session     = "session-nov-2025"
  ManagedBy   = "Terraform"
}
```

Cela permet :
- Suivi des coûts AWS par session
- Identification rapide des ressources par formation
- Nettoyage facile des ressources d'une session spécifique

### Bonnes pratiques

1. **Noms de fichiers** : Utilisez toujours le format `prenom.nom.pub`
2. **Pas d'email** : N'incluez jamais d'email dans le nom du fichier
3. **Commentaire SSH** : L'email dans le commentaire de la clé SSH est optionnel et non utilisé
4. **Organisation** : Placez les clés dans le répertoire de session approprié

### Exemple complet

```bash
# Structure du répertoire
participants/
└── session-nov-2025/
    ├── john.doe.pub
    ├── marie.dupont.pub
    └── pierre.martin.pub

# Terraform crée les ressources avec noms discrets :
# - k8s-lab-john.do-master
# - k8s-lab-john.do-worker-1
# - k8s-lab-marie.du-master
# - k8s-lab-marie.du-worker-1
# - k8s-lab-pierre.ma-master
# - k8s-lab-pierre.ma-worker-1
```
