# domain/

Pure Dart. Modèles + règles métier uniquement.

**Interdit :** `package:flutter/*`, `package:drift/*`, `package:geolocator/*`, `package:path_provider/*`, etc.

Doit être testable sans Flutter runtime. Si un fichier ici importe un package UI ou I/O, il est au mauvais endroit.
