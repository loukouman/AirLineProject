# ✈️ Envol — Application mobile aéroport

Application Flutter pour la gestion des vols, de l'enregistrement, des cartes d'embarquement et du suivi de parcours voyageur en aéroport.

## Fonctionnalités

- Authentification (email/mot de passe + Google Sign-In)
- Cartes d'embarquement digitales avec QR code
- Enregistrement (check-in) via scan
- Suivi en temps réel des vols et tableau des départs/arrivées
- Gestion des bagages, plan de l'aéroport, parking, objets perdus, assistance PMR
- Notifications push et alertes
- Mode hors-ligne (cache local des vols avec Hive)
- Espace administrateur (gestion des vols, rôles, publicités, alertes)
- Espace agent (desk d'enregistrement, contrôle sécurité)

## Stack technique

- Frontend : Flutter / Dart
- Backend : Supabase (auth, base de données PostgreSQL, storage, realtime)
- Notifications : Firebase Cloud Messaging
- Cache local : Hive
- Scan QR : mobile_scanner / qr_flutter

## Prérequis

- Flutter SDK (voir .metadata pour la version utilisée)
- Un projet Supabase configuré
- Un projet Firebase configuré (pour les notifications push)

## Installation

1. Cloner le dépôt

   git clone https://github.com/loukouman/AirLineProject.git
   cd AirLineProject

2. Installer les dépendances

   flutter pub get

3. Configurer les variables d'environnement

   Crée un fichier .env à la racine du projet (non versionné, voir .gitignore) :

   SUPABASE_URL=https://xxxxx.supabase.co
   SUPABASE_ANON_KEY=ta_cle_anon_supabase

4. Configurer Firebase

   Ce fichier n'est pas versionné pour des raisons de sécurité. Il faut le récupérer depuis la console Firebase du projet et le placer à :

   android/app/google-services.json

5. Lancer l'application

   flutter run

## Structure du projet

lib/
  core/
    models/     Modèles de données (Flight, Passenger...)
    services/   Supabase, cache hors-ligne, notifications, météo
    theme/      Thème et couleurs de l'app
    widgets/    Widgets réutilisables
  features/
    admin/      Espace administrateur
    agent/      Espace agent (check-in desk, sécurité)
    auth/       Authentification
    boarding_pass/  Cartes d'embarquement
    checkin/    Enregistrement
    home/       Écran d'accueil
    tracking/   Suivi de vol

## Notes

- Les fichiers .env et android/app/google-services.json contiennent des identifiants sensibles et ne sont volontairement pas versionnés.
- Le dossier supabase/.temp/ est généré automatiquement par la CLI Supabase et n'est pas versionné.
