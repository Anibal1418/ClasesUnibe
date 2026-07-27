# YourArtArchive

YourArtArchive es un aplicativo de Flutter hecho para organizar, calificar y
reseñar libros, películas, series, juegos, manga, anime y teatro. Se ejecuta en
Android y Chrome y almacena el archivo de cada cuenta localmente en SQLite.

## Ejecutar en chrome

La base de datos web se persiste en IndexedDB. 
Mantén el mismo puerto para que el navegador
use el mismo origen de la base de datos:

```powershell
flutter pub get
dart run sqflite_common_ffi_web:setup --force
flutter run -d chrome --web-port 8080
```

Cambiar el puerto, usar una ventana de incógnito o borrar los datos del sitio crea una
nueva base de datos en el navegador.

## Ejectuar en Android

1. Abre esta carpeta en Android Studio.
2. Configura el SDK de Flutter y un SDK/emulador de Android.
3. Ejecuta flutter pub get.
4. Selecciona el emulador y ejecuta lib/main.dart.

## Validación

```powershell
flutter analyze
flutter test
flutter build web
```

## Data local

`your_art_archive.db` contiene:

- `users`
- `artworks`
- `reviews`
- `lists`
- `list_items`

Las fuentes de imágenes y tipografías se enumeran en [assets/CREDITS.md](assets/CREDITS.md).
