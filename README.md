# ⚡ Lifeforge - AI Life Simulator

**Lifeforge** est un simulateur de vie textuel et immersif (style *BitLife*) propulsé par l'IA (Gemini) et construit avec **Ruby on Rails 8** et **Hotwire (Turbo/Stimulus)**.

Le concept repose sur un modèle hybride innovant : la narration et les opportunités sont générées à la volée par l'IA en fonction de votre passé, tandis que les statistiques, l'inventaire, les relations et les règles de survie sont gérés de manière déterministe et sécurisée en base de données par le code Ruby.

---

## 🎮 Fonctionnalités

* **Création libre** : Décrivez librement qui vous voulez être pour lancer votre vie (ex: *"Un hacker rebelle à Séoul"*, *"Un boxeur en quête de rédemption à Chicago"*).
* **Flux Chronologique Interactif** : Vivez votre vie année après année avec des cartes d'événements illustrées et des choix d'actions.
* **Barre de Chat Intelligente** : Saisissez vos propres actions personnalisées en texte libre pour guider votre destin.
* **Fiche de Personnage Complète** : Suivez vos attributs (Santé, Bonheur, Intelligence, Fitness, Apparence, Charisme), votre compte en banque, votre inventaire et vos relations avec votre entourage.
* **Mort & Retraite** : Règles de fin de vie gérées par le moteur physique (décès à 0 de santé, retraite à 100 ans).

---

## 🛠️ Pile Technique (Tech Stack)

* **Backend** : Ruby on Rails 8.1 (SQLite pour le stockage local).
* **Frontend** : **Vanilla CSS** (thème sobre noir anthracite inspiré de maquettes Figma) + **Hotwire (Turbo Streams & Stimulus)** pour des transitions fluides et instantanées sans rechargement de page.
* **IA** : API Google Gemini (`gemini-2.5-flash`) interrogée en JSON structuré, avec un mode de simulation local/hors-ligne intégré si aucune clé API n'est fournie.

---

## 🚀 Installation & Lancement

### Prerequis
* Ruby 3.3.x (installé avec DevKit/MSYS2 sous Windows)
* SQLite3

### 1. Cloner et installer les dépendances
Ouvrez votre terminal dans le dossier du projet et installez les gems :
```powershell
$env:PATH = "C:\Ruby33-x64\bin;" + $env:PATH
bundle install
```

### 2. Configurer la base de données
Exécutez les migrations pour créer la structure des tables (Runs, Characters, LifeEvents) :
```powershell
bin/rails db:migrate
```

### 3. Configurer la clé d'API Gemini
1. Ouvrez le fichier `.env` à la racine du projet.
2. Remplacez `"VOTRE_CLE_API_GEMINI_ICI"` par votre clé obtenue gratuitement sur [Google AI Studio](https://aistudio.google.com/).

### 4. Lancer le serveur de développement
Démarrez le serveur local :
```powershell
bin/rails server
```
L'application est maintenant accessible sur **[http://localhost:3000](http://localhost:3000)** !

---

## 📂 Structure du Code Clé

* **`app/services/game_engine.rb`** : Le moteur logique qui valide les statistiques, applique les changements, fait vieillir le personnage et gère sa fin de vie.
* **`app/services/gemini_client.rb`** : Le client API qui interroge Gemini pour obtenir les résolutions et les nouveaux événements au format JSON structuré.
* **`app/controllers/runs_controller.rb`** : Gère les actions web (création de run, exécution d'un tour) et renvoie les flux Turbo Streams.
* **`app/views/runs/play.turbo_stream.erb`** : Décrit les composants HTML à mettre à jour dynamiquement à la fin de chaque tour.
* **`app/assets/stylesheets/application.css`** : Feuille de style sur mesure (Vanilla CSS) pour tout le rendu graphique.
