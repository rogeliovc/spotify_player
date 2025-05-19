# Sincronía - Reproductor de Música con Spotify

![Sincronía Logo](assets/images/logo.png)

Aplicación móvil desarrollada en Flutter que integra la API de Spotify para ofrecer una experiencia completa de reproducción musical, gestión de listas de reproducción y sincronización con tu cuenta de Spotify.

## Características Principales

- Autenticación segura con Spotify OAuth 2.0
- Reproductor de música completo con controles de reproducción
- Búsqueda global de canciones, álbumes y artistas
- Calendario integrado para organizar tareas y eventos
- Soporte para temas claro y oscuro
- Interfaz de usuario intuitiva y receptiva
- Notificaciones locales para controles de reproducción
- Sincronización en tiempo real con tu cuenta de Spotify

## Requisitos

- Flutter (versión 3.x.x o superior)
- Dart SDK (compatible con Flutter)
- Cuenta de Spotify Premium (requerida para la reproducción completa)
- Dispositivo móvil o emulador con Android/iOS

## Instalación

1. **Clona el repositorio**
   ```bash
   git clone <URL-del-repositorio>
   cd spotify_player
   ```

2. **Instala las dependencias**
   ```bash
   flutter pub get
   ```

3. **Configura las variables de entorno**
   Crea un archivo `.env` en la raíz del proyecto con tus credenciales de Spotify:
   ```
   SPOTIFY_CLIENT_ID=tu_client_id
   SPOTIFY_REDIRECT_URI=tu_redirect_uri
   ```

4. **Ejecuta la aplicación**
   ```bash
   flutter run
   ```
## Acceso
   ```
   Si deseas utilizar la aplicacion recuerda solicitar el acceso a la api, al estar en modo beta no es publica
   ```

## Acceso a la API

Para utilizar la aplicación, necesitarás:

1. Registrar tu aplicación en el [Dashboard de Desarrolladores de Spotify](https://developer.spotify.com/dashboard/)
2. Configurar los URIs de redirección permitidos
3. Obtener las credenciales de la API (Client ID y Client Secret)
4. Solicitar acceso al modo de desarrollo extendido si es necesario

## Características Técnicas

- **Arquitectura**: Clean Architecture con Provider para la gestión de estado
- **Persistencia**: Almacenamiento local para preferencias y caché
- **Notificaciones**: Soporte para notificaciones locales y controles de reproducción
- **Temas**: Sistema de temas personalizables
- **Control de reproducción**: Integración con el reproductor de Spotify

## Licencia

Este proyecto está bajo la licencia MIT. Consulta el archivo [LICENSE](LICENSE) para más detalles.

## Contacto

Para más información o soporte, por favor contacta al equipo de desarrollo.
- Recuerda tener una cuenta de spotify activa
