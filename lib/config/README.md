# config/

Constantes partagées only. Pas de logique.

Importable depuis n'importe quelle couche (`domain`, `application`, `infrastructure`, `presentation`).

Règle : si ça a des dépendances runtime ou de l'état, ça n'a rien à faire ici.
