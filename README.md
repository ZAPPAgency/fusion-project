# Fusion Project

**Valbrune — La Cloche Fêlée** : RPG tour par tour en pixel art, dans un univers médiéval-fantasy. Les combats se jouent au timing : appuie au moment de l'impact pour renforcer tes coups, pare ou esquive ceux des ennemis.

**Jouer dans le navigateur : https://zappagency.github.io/fusion-project/**

## Commandes

| Action | Clavier | Manette |
|---|---|---|
| Se déplacer | ZQSD (AZERTY) / WASD (QWERTY) / flèches | Stick gauche / croix |
| Valider, attaquer au bon moment | Espace / Entrée | A |
| Retour | Échap | B |
| Parade | E | RB |
| Esquive | A (AZERTY) / Q (QWERTY) | LB |
| Menu | Tab | Start |
| Changer de héros sur la carte | R | Y |
| Plein écran | F11 (Ctrl+Cmd+F sur Mac) | — |

En combat : F1 change la difficulté, F2 calibre la latence.

## Développement

- Moteur : Godot 4.8 (GDScript).
- Tests : `godot --headless --path . -s addons/gut/gut_cmdln.gd`.
- Chaque push sur `main` relance les tests et republie la version web (voir `.github/workflows/pages.yml`).
- Crédits des graphismes : `assets/CREDITS.md`.
