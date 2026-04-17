# infrastructure/

Implémentations concrètes des interfaces définies dans `domain/` : Drift, geolocator, filesystem, path_provider, image_picker, etc.

Peut importer tout. Point d'adaptation entre le métier pur et les libs tierces.

Si une lib tierce change d'API ou doit être remplacée, c'est ici que ça se passe, sans toucher `domain/` ni `application/`.
