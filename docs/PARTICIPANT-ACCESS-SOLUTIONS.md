# Solutions pour Communiquer les Accès aux Participants

Ce document présente différentes solutions simples et pratiques pour distribuer les informations d'accès aux participants.

## 🎯 Comparaison des Solutions

| Solution | Complexité | Automatisation | Sécurité | Cas d'usage |
|----------|------------|----------------|----------|-------------|
| 1. Email individuel | ⭐ Facile | ⭐⭐ Partielle | ⭐⭐⭐ Bonne | Petites sessions (<10) |
| 2. Slack/Teams | ⭐ Facile | ⭐⭐ Partielle | ⭐⭐ Moyenne | Sessions collaboratives |
| 3. Portail web statique | ⭐⭐ Moyen | ⭐⭐⭐ Élevée | ⭐⭐⭐ Bonne | Toutes tailles |
| 4. Google Sheets | ⭐ Facile | ⭐ Manuelle | ⭐ Faible | Sessions internes |
| 5. GitHub/GitLab | ⭐ Facile | ⭐⭐⭐ Élevée | ⭐⭐⭐⭐ Excellente | Sessions techniques |

## 1. 📧 Email Individuel (Recommandé pour <10 participants)

### Avantages
- Simple et direct
- Chaque participant reçoit uniquement ses informations
- Traçabilité claire

### Mise en œuvre

#### Étape 1 : Générer les fichiers
```bash
# Générer les fichiers d'accès pour une session
./scripts/generate-access-info.sh <session-name>

# Exemple pour session-1
./scripts/generate-access-info.sh session-1
```

Cela crée des fichiers individuels dans `participant-access/<session-name>/`:
```
participant-access/session-1/
├── jean.martin-access.txt
├── marie.dubois-access.txt
├── pierre.bernard-access.txt
└── participants-session-1.csv
```

#### Étape 2 : Script d'envoi automatique

**Option A : Avec `mutt` (Linux/Mac)**

```bash
#!/bin/bash
# scripts/send-access-emails.sh

ACCESS_DIR="participant-access"
SUBJECT="Accès à votre environnement Kubernetes Lab - Session Nov 2025"

for file in "$ACCESS_DIR"/*-access.txt; do
    participant=$(basename "$file" -access.txt)
    email="${participant}@example.com"  # Adapter selon votre convention

    mutt -s "$SUBJECT" -a "$file" -- "$email" << EOF
Bonjour,

Veuillez trouver en pièce jointe vos informations d'accès pour la session de formation Kubernetes.

La formation débute le [DATE] à [HEURE].

Merci de tester votre accès avant le début de la session.

Cordialement,
L'équipe formation
EOF

    echo "Email sent to $email"
done
```

**Option B : Avec Python et Gmail API**

```python
#!/usr/bin/env python3
# scripts/send-access-emails.py

import os
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from email.mime.base import MIMEBase
from email import encoders

SMTP_SERVER = "smtp.gmail.com"
SMTP_PORT = 587
SENDER_EMAIL = "your-email@gmail.com"
SENDER_PASSWORD = "your-app-password"  # Use app password, not real password

ACCESS_DIR = "participant-access"

# Map participant names to emails
PARTICIPANT_EMAILS = {
    "jean.martin": "jean.martin@example.com",
    "marie.dubois": "marie.dubois@example.com",
    # ... add all participants
}

def send_email(participant, email, access_file):
    msg = MIMEMultipart()
    msg['From'] = SENDER_EMAIL
    msg['To'] = email
    msg['Subject'] = "Accès à votre environnement Kubernetes Lab"

    body = """
Bonjour,

Veuillez trouver en pièce jointe vos informations d'accès pour la session de formation Kubernetes.

La formation débute le [DATE] à [HEURE].

Merci de tester votre accès avant le début de la session.

Cordialement,
L'équipe formation
    """

    msg.attach(MIMEText(body, 'plain'))

    # Attach access file
    with open(access_file, 'rb') as f:
        part = MIMEBase('application', 'octet-stream')
        part.set_payload(f.read())
        encoders.encode_base64(part)
        part.add_header('Content-Disposition', f'attachment; filename={os.path.basename(access_file)}')
        msg.attach(part)

    # Send email
    with smtplib.SMTP(SMTP_SERVER, SMTP_PORT) as server:
        server.starttls()
        server.login(SENDER_EMAIL, SENDER_PASSWORD)
        server.send_message(msg)

    print(f"Email sent to {email}")

# Send to all participants
for participant, email in PARTICIPANT_EMAILS.items():
    access_file = f"{ACCESS_DIR}/{participant}-access.txt"
    if os.path.exists(access_file):
        send_email(participant, email, access_file)
    else:
        print(f"Warning: {access_file} not found for {participant}")
```

## 2. 💬 Slack / Microsoft Teams (Recommandé pour sessions collaboratives)

### Avantages
- Communication instantanée
- Canal dédié à la session
- Facile de répondre aux questions

### Mise en œuvre

#### Slack

**Option A : Message privé individuel**

```bash
#!/bin/bash
# scripts/send-to-slack.sh

SLACK_BOT_TOKEN="xoxb-your-token-here"
ACCESS_DIR="participant-access"

# Map participants to Slack user IDs
declare -A SLACK_USERS=(
    ["jean.martin"]="U01234ABC"
    ["marie.dubois"]="U56789DEF"
)

for participant in "${!SLACK_USERS[@]}"; do
    user_id="${SLACK_USERS[$participant]}"
    access_file="$ACCESS_DIR/${participant}-access.txt"

    if [ -f "$access_file" ]; then
        message=$(cat "$access_file")

        curl -X POST https://slack.com/api/chat.postMessage \
            -H "Authorization: Bearer $SLACK_BOT_TOKEN" \
            -H "Content-Type: application/json" \
            -d "{
                \"channel\": \"$user_id\",
                \"text\": \"Vos accès Kubernetes Lab\",
                \"blocks\": [{
                    \"type\": \"section\",
                    \"text\": {
                        \"type\": \"mrkdwn\",
                        \"text\": \"\`\`\`$message\`\`\`\"
                    }
                }]
            }"

        echo "Sent to $participant ($user_id)"
    fi
done
```

**Option B : Canal partagé avec tableau**

```markdown
# 🎓 Kubernetes Lab - Session Nov 2025

## 📋 Informations d'accès

| Participant | Master IP | SSH Command | Status |
|-------------|-----------|-------------|--------|
| Jean Martin | `54.123.45.67` | `ssh ubuntu@54.123.45.67` | ✅ Ready |
| Marie Dubois | `54.123.45.89` | `ssh ubuntu@54.123.45.89` | ✅ Ready |
| Pierre Bernard | `54.123.46.12` | `ssh ubuntu@54.123.46.12` | ✅ Ready |

## 🚀 Premiers pas

1. Connectez-vous avec la commande SSH ci-dessus
2. Vérifiez votre cluster : `kubectl get nodes`
3. Infos détaillées : `/home/ubuntu/cluster-info.sh`

## ⏰ Planning
- **Début** : [DATE] à [HEURE]
- **Fin** : [DATE] à [HEURE]
- **Support** : Ce canal Slack

## ❓ Questions
Posez vos questions ici, toute l'équipe peut vous aider !
```

#### Microsoft Teams

Utilisez un **Bot Teams** ou postez dans un canal :

```python
import requests
import json

TEAMS_WEBHOOK = "https://outlook.office.com/webhook/your-webhook-url"

def send_to_teams(participant_info):
    message = {
        "@type": "MessageCard",
        "@context": "http://schema.org/extensions",
        "themeColor": "0076D7",
        "summary": "Kubernetes Lab Access",
        "sections": [{
            "activityTitle": "Vos accès Kubernetes Lab",
            "activitySubtitle": f"Participant: {participant_info['name']}",
            "facts": [
                {"name": "Master IP", "value": participant_info['ip']},
                {"name": "SSH Command", "value": f"`ssh ubuntu@{participant_info['ip']}`"},
                {"name": "Workers", "value": participant_info['workers']}
            ]
        }]
    }

    requests.post(TEAMS_WEBHOOK, json=message)
```

## 3. 🌐 Portail Web Statique (Recommandé pour >20 participants)

### Avantages
- Professionnel
- Auto-service
- Protection par mot de passe

### Mise en œuvre

#### Générer le portail HTML

```bash
#!/bin/bash
# scripts/generate-web-portal.sh

cat > participant-access/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Kubernetes Lab Access Portal</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 1200px;
            margin: 50px auto;
            padding: 20px;
            background: #f5f5f5;
        }
        .header {
            background: #0066cc;
            color: white;
            padding: 20px;
            border-radius: 5px;
        }
        .participant-card {
            background: white;
            padding: 20px;
            margin: 20px 0;
            border-radius: 5px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .ssh-command {
            background: #2d2d2d;
            color: #00ff00;
            padding: 10px;
            border-radius: 3px;
            font-family: monospace;
            margin: 10px 0;
        }
        .copy-btn {
            background: #0066cc;
            color: white;
            border: none;
            padding: 5px 10px;
            border-radius: 3px;
            cursor: pointer;
        }
        .search-box {
            width: 100%;
            padding: 10px;
            margin: 20px 0;
            font-size: 16px;
            border: 2px solid #ddd;
            border-radius: 5px;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>🎓 Kubernetes Lab Access Portal</h1>
        <p>Session: session-nov-2025</p>
    </div>

    <input type="text" id="searchBox" class="search-box" placeholder="🔍 Rechercher votre nom...">

    <div id="participants"></div>

    <script>
        const participants = PARTICIPANTS_DATA_HERE;

        function renderParticipants(filter = '') {
            const container = document.getElementById('participants');
            container.innerHTML = '';

            participants
                .filter(p => p.name.toLowerCase().includes(filter.toLowerCase()))
                .forEach(p => {
                    const card = document.createElement('div');
                    card.className = 'participant-card';
                    card.innerHTML = `
                        <h2>👤 ${p.name}</h2>
                        <p><strong>Master IP:</strong> ${p.ip}</p>
                        <div class="ssh-command">
                            <code id="ssh-${p.name}">ssh ubuntu@${p.ip}</code>
                            <button class="copy-btn" onclick="copySSH('${p.name}', '${p.ip}')">📋 Copy</button>
                        </div>
                        <p><strong>Worker Nodes:</strong> ${p.workers}</p>
                        <p><strong>Status:</strong> ✅ Ready</p>
                        <details>
                            <summary>Getting Started</summary>
                            <ol>
                                <li>Connect: <code>ssh ubuntu@${p.ip}</code></li>
                                <li>Check nodes: <code>kubectl get nodes</code></li>
                                <li>Cluster info: <code>/home/ubuntu/cluster-info.sh</code></li>
                            </ol>
                        </details>
                    `;
                    container.appendChild(card);
                });
        }

        function copySSH(name, ip) {
            const text = `ssh ubuntu@${ip}`;
            navigator.clipboard.writeText(text);
            alert('SSH command copied!');
        }

        document.getElementById('searchBox').addEventListener('input', (e) => {
            renderParticipants(e.target.value);
        });

        renderParticipants();
    </script>
</body>
</html>
EOF

# Inject participant data from Terraform
cd terraform
terraform output -json clusters | jq '[
    .[] | {
        name: .participant_name,
        ip: .master_public_ip,
        workers: .worker_ips | length
    }
]' > ../participant-access/data.json

# Merge data into HTML
# ... (script to inject data.json into HTML)
```

#### Héberger le portail

**Option A : GitHub Pages (Gratuit)**

```bash
# 1. Créer une branche gh-pages
git checkout -b gh-pages
git add participant-access/index.html
git commit -m "Add access portal"
git push origin gh-pages

# 2. Activer GitHub Pages dans Settings
# URL: https://your-username.github.io/kubernetes-aws-lab/
```

**Option B : S3 + CloudFront (AWS)**

```bash
# Upload to S3
aws s3 cp participant-access/index.html s3://your-bucket/index.html \
    --acl private

# Configure S3 website
aws s3 website s3://your-bucket/ \
    --index-document index.html

# Add Basic Auth via Lambda@Edge or Cognito
```

**Option C : Nginx avec Basic Auth**

```bash
# Sur une instance EC2
sudo apt install nginx apache2-utils

# Créer un mot de passe
sudo htpasswd -c /etc/nginx/.htpasswd session2025

# Nginx config
sudo tee /etc/nginx/sites-available/k8s-portal << EOF
server {
    listen 80;
    root /var/www/k8s-portal;

    auth_basic "Kubernetes Lab Access";
    auth_basic_user_file /etc/nginx/.htpasswd;

    location / {
        try_files \$uri /index.html;
    }
}
EOF

# Copier les fichiers
sudo mkdir /var/www/k8s-portal
sudo cp participant-access/index.html /var/www/k8s-portal/

# Activer
sudo ln -s /etc/nginx/sites-available/k8s-portal /etc/nginx/sites-enabled/
sudo systemctl reload nginx
```

## 4. 📊 Google Sheets (Simple mais moins sécurisé)

### Avantages
- Très simple
- Accessible partout
- Collaboratif

### Mise en œuvre

```bash
# Générer le CSV pour une session
./scripts/generate-access-info.sh <session-name>

# Le CSV est dans participant-access/<session-name>/participants-<session-name>.csv
# Exemple pour session-1 : participant-access/session-1/participants-session-1.csv

# 1. Ouvrir Google Sheets
# 2. File > Import > Upload > participants-session-1.csv
# 3. Partager avec les participants (view only)
```

⚠️ **Attention** : Ne pas utiliser pour des informations sensibles

## 5. 🔐 GitHub/GitLab Issues (Pour sessions techniques)

### Avantages
- Traçabilité complète
- Issue par participant
- Notifications automatiques

### Mise en œuvre

```bash
#!/bin/bash
# scripts/create-github-issues.sh

REPO="your-org/kubernetes-aws-lab"
GH_TOKEN="your-github-token"
ACCESS_DIR="participant-access"

for file in "$ACCESS_DIR"/*-access.txt; do
    participant=$(basename "$file" -access.txt)
    content=$(cat "$file")

    # Create issue
    gh issue create \
        --repo "$REPO" \
        --title "Kubernetes Lab Access - $participant" \
        --body "\`\`\`
$content
\`\`\`" \
        --assignee "$participant" \
        --label "access,session-nov2025"

    echo "Issue created for $participant"
done
```

## 🏆 Recommandation Finale

Pour une session de formation typique :

### Configuration recommandée (Mix)

1. **Avant la formation** (J-2) :
   - Email individuel avec fichier d'accès en pièce jointe
   - Canal Slack/Teams avec tableau récapitulatif

2. **Pendant la formation** :
   - Canal Slack/Teams pour le support en temps réel
   - Portail web pour référence rapide

3. **Après la formation** :
   - Laisser le canal actif 1 semaine
   - Archiver les accès

### Script complet automatisé

```bash
#!/bin/bash
# scripts/distribute-access.sh

SESSION="session-nov-2025"
SESSION_DATE="12-13 Novembre 2025"

echo "🚀 Generating access information..."
./scripts/generate-access-info.sh "$SESSION"

echo "📧 Sending individual emails..."
./scripts/send-access-emails.sh

echo "💬 Posting to Slack..."
./scripts/send-to-slack.sh

echo "🌐 Generating web portal..."
./scripts/generate-web-portal.sh

echo "✅ Done! All participants have been notified."
echo ""
echo "Next steps:"
echo "1. Monitor Slack for questions"
echo "2. Test one cluster access yourself"
echo "3. Prepare training materials"
```

## 📱 Solutions Mobiles

Pour permettre l'accès depuis mobile :

1. **Termux** (Android) : App terminal SSH
2. **iSH** (iOS) : Shell Linux sur iOS
3. **Blink Shell** (iOS) : Client SSH professionnel

Envoyez un guide rapide :
```
📱 Accès mobile

Android (Termux) :
1. Install Termux from F-Droid
2. pkg install openssh
3. ssh ubuntu@[YOUR-IP]

iOS (Blink Shell) :
1. Install Blink Shell from App Store
2. Add host: [YOUR-IP]
3. User: ubuntu
```

## Support et Aide

Pour toute question :
- Documentation complète : `docs/SESSION-MANAGEMENT.md`
- Scripts d'exemple : `scripts/`
- Terraform outputs : `cd terraform && terraform output`
