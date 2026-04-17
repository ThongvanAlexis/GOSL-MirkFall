# application/

Use cases / controllers. Riverpod providers (`@riverpod`).

Peut importer :
- `domain/` (entités, règles métier)
- `infrastructure/` uniquement via **interfaces** définies dans `domain/`

Ne doit pas importer directement une implémentation concrète d'`infrastructure/` ni `presentation/`.
