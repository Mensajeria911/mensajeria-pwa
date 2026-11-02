# App de domiciliarios · Mensajeros Montería 911

Un solo código Flutter para las dos versiones:

- **Android**: APK firmado con la llave de la mensajería.
- **iPhone**: PWA (Flutter Web) que se instala desde Safari con *Compartir → Agregar a inicio*.

## Qué hace

- Inicio de sesión con Supabase. La sesión queda abierta hasta cerrarla.
- Bloquea a quien no es domiciliario o está desactivado ("Usuario desactivado. Contacte a la Central.").
- Servicios asignados en tiempo real. Cuando la central asigna uno, suena la alerta propia, vibra, llega una notificación y sube la hoja de **Nuevo servicio**.
- Pasos del servicio en orden (recoger, comprar, cruce, entregar), factura, valor del medicamento y códigos de cruce.
- **Foto de la factura** obligatoria en las compras (cámara o galería). Se guarda en Storage privado.
- Deslizar para empezar y para entregar.
- Botones de Google Maps, llamar al cliente y llamar a la sede.
- Conectado / en pausa, y ubicación cada 2 minutos mientras la app está abierta (la central sugiere al más cercano).
- Ganancias de hoy, 7 y 30 días, separando lo pagado de lo pendiente, y desglose por tipo.
- Turnos, sonido, vibración, tema claro / oscuro / automático.

## Compilar

Las claves públicas de Supabase entran al compilar (nunca se escriben en el código):

```powershell
flutter build apk --release --dart-define=SUPABASE_URL=https://xwhohvxogfprizdmcusa.supabase.co --dart-define=SUPABASE_ANON_KEY=sb_publishable_...
flutter build web --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

El APK queda en `build/app/outputs/flutter-apk/app-release.apk`.

## Firma de Android (importante)

`android/key.properties` y `android/app/mensajeros911-release.jks` firman la app. **No van al repositorio** y hay que guardarlos en un lugar seguro (por ejemplo, una memoria USB y una copia en Drive). Si se pierden, las próximas versiones no podrán instalarse encima de la actual y cada domiciliario tendría que desinstalar y volver a instalar.

## Notificaciones con la app cerrada

Funcionan cuando se agrega Firebase: poner `google-services.json` en `android/app/` y configurar la función que envía los avisos (ver `supabase/functions`). Sin Firebase la app avisa con sonido y vibración solo mientras está abierta.
