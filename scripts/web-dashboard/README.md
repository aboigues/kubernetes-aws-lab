# Kubernetes AWS Lab - Web Dashboard

Dashboard web temps réel pour afficher les informations d'accès des participants.

## 🌟 Fonctionnalités

- **Affichage en temps réel** : Tableau dynamique avec les informations de connexion de tous les participants
- **Rafraîchissement automatique** : Mise à jour automatique toutes les 10 secondes (configurable)
- **Copie en un clic** : Copiez les commandes SSH d'un simple clic
- **Design responsive** : Interface adaptée mobile et desktop
- **Multi-sessions** : Support des sessions multiples via workspaces Terraform

## 📋 Prérequis

- Python 3.6 ou supérieur
- Flask (installé automatiquement si manquant)
- Terraform configuré avec au moins une session déployée
- jq (optionnel, pour un meilleur parsing JSON)

## 🚀 Démarrage rapide

### Méthode 1 : Script de lancement (Recommandé)

```bash
# Depuis la racine du projet
./scripts/start-dashboard.sh

# Ou avec un port personnalisé
./scripts/start-dashboard.sh --port 3000
```

### Méthode 2 : Lancement manuel

```bash
# Installer les dépendances
cd scripts/web-dashboard
pip3 install -r requirements.txt

# Démarrer le serveur
python3 app.py
```

## 🌐 Accès au dashboard

Une fois le serveur démarré, ouvrez votre navigateur à :

```
http://localhost:8080
```

## 📊 Captures d'écran

Le dashboard affiche :
- Nom de la session active
- Nombre total de participants
- Statut de connexion en temps réel
- Pour chaque participant :
  - Nom du participant
  - IP publique du master node
  - IP privée du master node
  - Nombre de worker nodes
  - IPs publiques des workers
  - Commande SSH pour se connecter

## 🔄 Rafraîchissement des données

- **Automatique** : Activé par défaut, rafraîchit toutes les 10 secondes
- **Manuel** : Utilisez le bouton "🔄 Actualiser"
- **Contrôle** : Désactivez/activez avec le toggle "Auto"

## 🛠️ API Endpoints

Le serveur expose plusieurs endpoints :

### `GET /`
Page principale du dashboard

### `GET /api/data`
Retourne les données de la session actuelle

```json
{
  "session": "session-1",
  "timestamp": "2025-12-04T10:30:00",
  "participant_count": 3,
  "participants": [
    {
      "name": "participant-1",
      "master_ip": "54.123.45.67",
      "master_private_ip": "10.0.1.10",
      "worker_count": 2,
      "worker_public_ips": ["54.123.45.68", "54.123.45.69"],
      "worker_private_ips": ["10.0.1.11", "10.0.1.12"],
      "ssh_command": "ssh ubuntu@54.123.45.67"
    }
  ]
}
```

### `GET /api/data/<session_name>`
Retourne les données pour une session spécifique

### `GET /api/sessions`
Liste toutes les sessions disponibles

```json
{
  "sessions": ["session-1", "session-2"],
  "current": "session-1"
}
```

### `GET /health`
Vérification de santé du serveur

```json
{
  "status": "ok",
  "timestamp": "2025-12-04T10:30:00"
}
```

## 🔧 Configuration

### Port du serveur

Modifiez le port dans `app.py` (ligne finale) ou utilisez l'option `--port` avec le script de lancement.

### Intervalle de rafraîchissement

Modifiez la constante `REFRESH_INTERVAL` dans `templates/dashboard.html` :

```javascript
const REFRESH_INTERVAL = 10000; // millisecondes
```

## 📂 Structure des fichiers

```
web-dashboard/
├── app.py                 # Serveur Flask
├── requirements.txt       # Dépendances Python
├── README.md             # Cette documentation
├── templates/
│   └── dashboard.html    # Page web principale
└── static/               # Fichiers statiques (si nécessaire)
```

## 🐛 Dépannage

### Le dashboard affiche "Aucun participant trouvé"

- Vérifiez qu'une session est déployée : `terraform workspace list`
- Assurez-vous d'être dans le bon workspace : `terraform workspace select <session-name>`
- Vérifiez que `terraform output clusters` retourne des données

### Erreur "Failed to get Terraform output"

- Vérifiez que Terraform est installé : `terraform --version`
- Assurez-vous d'être dans le bon répertoire terraform
- Vérifiez que le state Terraform existe

### Flask n'est pas installé

```bash
pip3 install flask
# ou
pip3 install -r requirements.txt
```

## 🔒 Sécurité

⚠️ **Important** : Ce dashboard est conçu pour un usage local ou sur un réseau sécurisé.

Pour une utilisation en production :
- Ajoutez de l'authentification
- Utilisez HTTPS
- Configurez un reverse proxy (nginx, Apache)
- Limitez l'accès par IP/firewall

## 📝 Notes

- Le dashboard récupère les données directement depuis Terraform
- Aucune donnée n'est stockée côté serveur
- Les commandes SSH peuvent être copiées en cliquant dessus
- Le design est responsive et fonctionne sur mobile

## 🤝 Contribution

Pour améliorer ce dashboard :
1. Modifiez les fichiers nécessaires
2. Testez vos changements localement
3. Créez un commit avec vos modifications

## 📄 Licence

Ce dashboard fait partie du projet Kubernetes AWS Lab.
