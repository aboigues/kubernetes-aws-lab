# Configuration Claude Code

Ce répertoire contient la configuration pour Claude Code, incluant les hooks et slash commands personnalisés.

## Structure

```
.claude/
├── README.md                      # Ce fichier
├── settings.json                  # Configuration des hooks
├── hooks/
│   └── session-start.sh          # Hook exécuté au démarrage de chaque session
└── commands/
    └── read-project-rules.md     # Slash command pour lire les règles du projet
```

## Session Start Hook

**Fichier:** `hooks/session-start.sh`

**Objectif:** Rappeler à Claude de lire `docs/PROJECT-RULES.md` au début de chaque session.

**Actions:**
1. Affiche un message de rappel visible au démarrage
2. Crée un fichier `.RULES-REMINDER.txt` à la racine du projet
3. Rappelle l'existence du slash command `/read-project-rules`

**Déclenchement:** Automatique au début de chaque session Claude Code (web ou desktop)

**Mode:** Synchrone (garantit que le rappel est affiché avant le début de la session)

## Slash Commands

### `/read-project-rules`

**Fichier:** `commands/read-project-rules.md`

**Usage:**
```
/read-project-rules
```

**Objectif:** Force Claude à lire le document complet `docs/PROJECT-RULES.md` avant de travailler sur le projet.

**Quand l'utiliser:**
- Au début de chaque nouvelle session
- Avant de commencer une nouvelle fonctionnalité
- Lorsque vous avez un doute sur les conventions du projet
- Après des modifications importantes du projet

## Pourquoi Cette Configuration ?

Le projet Kubernetes AWS Lab a des conventions strictes :
- **Nommage:** Format précis pour clés SSH, sessions, ressources AWS
- **Code:** Standards Bash/Terraform/Python à respecter
- **Déploiement:** Workflow spécifique avec validation obligatoire
- **Sécurité:** Règles de sécurité et bonnes pratiques
- **Coûts:** Gestion stricte des coûts AWS

**Sans lecture des règles :**
- ❌ Code non-conforme aux standards
- ❌ Échecs de déploiement
- ❌ Vulnérabilités de sécurité
- ❌ Augmentation des coûts
- ❌ Documentation incohérente

**Avec lecture des règles :**
- ✅ Code conforme dès le premier essai
- ✅ Déploiements réussis
- ✅ Sécurité respectée
- ✅ Coûts optimisés
- ✅ Documentation cohérente

## Test du Hook

Pour tester manuellement le hook :

```bash
# Exécuter le hook
CLAUDE_PROJECT_DIR=$(pwd) ./.claude/hooks/session-start.sh

# Vérifier que le fichier de rappel a été créé
cat .RULES-REMINDER.txt
```

## Modification de la Configuration

### Ajouter un nouveau hook

1. Créer le script dans `.claude/hooks/`
2. Le rendre exécutable : `chmod +x .claude/hooks/mon-hook.sh`
3. Ajouter dans `.claude/settings.json`

### Ajouter un nouveau slash command

1. Créer le fichier markdown dans `.claude/commands/`
2. Nommer le fichier : `mon-command.md` → `/mon-command`
3. Utiliser avec `/mon-command`

## Documentation Officielle

Pour plus d'informations sur Claude Code et ses fonctionnalités :
- Hooks: https://docs.anthropic.com/claude-code/hooks
- Slash Commands: https://docs.anthropic.com/claude-code/slash-commands
- Configuration: https://docs.anthropic.com/claude-code/configuration
