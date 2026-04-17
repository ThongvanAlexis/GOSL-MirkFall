# presentation/

Widgets + screens. UI only.

Peut importer :
- `application/` (providers Riverpod)
- `config/` (constantes)

**Ne doit PAS importer directement `infrastructure/`.** Passe toujours par `application/`.

Règle : si un widget appelle Drift ou `geolocator` directement, il est au mauvais endroit.
