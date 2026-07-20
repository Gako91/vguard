# V-Guard 🛡️

Un client de bureau WireGuard VPN cross-platform, ultra-léger et rapide, développé entièrement en **langage V** à l'aide du framework graphique officiel `vlang/gui`.

## ✨ Caractéristiques

- **Interface graphique native et épurée** : Pas de framework web lourd (comme Electron). L'application consomme moins de 30 Mo de RAM.
- **Démarrage instantané** : Performance du code compilé de manière native.
- **Sélecteur de fichiers intégré** : Importation directe de vos fichiers de configuration `.conf` WireGuard standard via l'explorateur système.
- **Cross-platform** : Conçu pour fonctionner sur Windows, macOS et Linux.

---

## 🚀 Installation & Prérequis

### 1. Dépendances système

Pour interagir avec le protocole WireGuard, l'application s'appuie sur les outils natifs de votre système d'exploitation :

- **Linux / macOS** : Assurez-vous que `wg-quick` est installé et disponible dans votre PATH.
- **Windows** : (En cours de validation) Nécessite l'accès à l'API ou l'exécutable officiel `wireguard.exe`.

### 2. Installer le langage V et vlang/gui

Si vous n'avez pas encore installé V, suivez le guide sur le [site officiel de V](https://vlang.io).

Installez ensuite la bibliothèque d'interface graphique officielle :

```bash
v install gui
```

---

## 🛠️ Compilation et Lancement

### En mode Développement

Pour tester et lancer l'application rapidement avec le rafraîchissement à la volée :

```bash
v run src/main.v
```

### En mode Production (Gestion de mémoire optimisée)

Le langage V intègre une option appelée **Autofree** qui libère automatiquement la mémoire sans utiliser de Garbage Collector. Pour compiler un binaire final ultra-optimisé, utilisez :

```bash
v -prod -autofree -o vguard main.v
```

_Note : Sur Linux, le binaire généré `vguard` sera autonome et prêt à être exécuté._

---

## 📂 Structure du Code Source

- **`config/parser.v`** : Analyse textuelle des fichiers `.conf` (proche du format INI) et extraction sécurisée des clés d'interface et de pairs (peers).
- **`vpn/manager.v`** : Gestionnaire d'exécution système. Exécute les commandes réseaux adaptées (`wg-quick up`/`down`) selon votre OS.
- **`guard_ui/views.v`** : Contient l'interface utilisateur en _immediate-mode_. L'interface graphique est une fonction pure de l'état de l'application.
- **`main.v`** : Initialise la structure étatique globale (`AppState`) et configure la boucle d'événements de la fenêtre graphique à 60 FPS.

---

## ⚠️ Notes de Sécurité et Privilèges

La création et la modification d'interfaces réseau (tunnels VPN) requièrent impérativement des privilèges élevés sur tous les systèmes d'exploitation :

- **Sur Linux / macOS** : L'application doit avoir la permission d'exécuter des commandes `sudo`. Il est recommandé de configurer `wg-quick` dans le fichier `sudoers` pour éviter d'avoir à saisir votre mot de passe à chaque connexion.
- **Sur Windows** : L'application finale doit être exécutée avec le mode "Exécuter en tant qu'administrateur".

## 📄 Licence

Ce projet est distribué sous la licence MIT. Voir le fichier `LICENSE` pour plus de détails.
