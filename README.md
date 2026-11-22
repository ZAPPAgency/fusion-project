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

### À la souris

- **Carte** : clic pour aller à un endroit (le héros contourne les obstacles), bouton maintenu pour suivre le curseur, clic sur un personnage ou un coffre pour y aller et interagir. Boutons « Héros » et « Menu » en haut à droite.
- **Menus** : survoler sélectionne, clic gauche choisit, clic droit revient en arrière.
- **Combat** : clic sur une action puis sur un ennemi ; au bon moment, clic gauche pour attaquer ou parer, clic droit pour esquiver.

## Développement

- Moteur : Godot 4.8 (GDScript).
- Tests : `godot --headless --path . -s addons/gut/gut_cmdln.gd`.
- Chaque push sur `main` relance les tests et republie la version web (voir `.github/workflows/pages.yml`).
- Crédits des graphismes : `assets/CREDITS.md`.
