```
CREAR PROYECTO FLUTTER ANDROID - MONITOREO WIFI DE RASPBERRY PI PICO

OBJETIVO
Generar un proyecto completo en Flutter para Android que se conecte por WiFi a una Raspberry Pi Pico/Pico W y permita obtener, visualizar y registrar todas las mediciones provenientes de sus entradas analogicas.

REQUISITOS GENERALES
- Lenguaje: Dart.
- Framework: Flutter.
- Plataforma principal: Android.
- La aplicacion debe funcionar completamente mediante WiFi.
- La comunicacion entre Android y Raspberry Pi Pico W debe realizarse mediante una API HTTP REST sobre la red local.
- El proyecto debe quedar preparado para conectarse posteriormente a una Raspberry Pi Pico W real.
- No utilizar Bluetooth.
- No utilizar Firebase.
- No depender de Internet para la comunicacion con el Pico.
- La interfaz debe estar en espanol.
- Generar codigo limpio, modular, mantenible y documentado.
- El proyecto debe poder ejecutarse con:
  flutter pub get
  flutter run

COMUNICACION WIFI
Implementar un cliente HTTP para comunicarse con la Raspberry Pi Pico W.

La IP del Pico debe poder configurarse desde la aplicacion, por ejemplo:
http://192.168.1.100

Crear una capa independiente llamada ApiService o similar para encapsular toda la comunicacion de red.

Endpoints esperados en el Pico:

GET /api/status
Debe devolver informacion sobre el estado del dispositivo.

Ejemplo:
{
  "device": "Raspberry Pi Pico W",
  "connected": true,
  "ip": "192.168.1.100",
  "uptime": 12345,
  "wifi_rssi": -55
}

GET /api/analog
Debe devolver TODAS las mediciones analogicas disponibles.

Ejemplo:
{
  "timestamp": 123456,
  "channels": [
    {
      "channel": 0,
      "gpio": 26,
      "raw": 2048,
      "voltage": 1.65
    },
    {
      "channel": 1,
      "gpio": 27,
      "raw": 3000,
      "voltage": 2.42
    },
    {
      "channel": 2,
      "gpio": 28,
      "raw": 1024,
      "voltage": 0.83
    }
  ]
}

IMPORTANTE:
No asumir que solamente existen 3 canales. La aplicacion debe soportar una cantidad configurable de entradas analogicas.

MODELO DE DATOS
Crear modelos Dart separados, por ejemplo:

DeviceStatus
AnalogChannel
AnalogMeasurement

Cada modelo debe implementar:
- constructor
- fromJson()
- toJson()

Las mediciones deben conservar como minimo:
- numero de canal
- GPIO
- valor RAW
- voltaje
- timestamp

PANTALLA PRINCIPAL
Crear un Dashboard moderno y sencillo.

Debe mostrar:

- Estado de conexion WiFi.
- IP del Raspberry Pi Pico.
- RSSI WiFi si esta disponible.
- Tiempo de funcionamiento del Pico.
- Cantidad de canales analogicos detectados.
- Ultima actualizacion.
- Estado de la comunicacion.

Para cada entrada analogica mostrar una tarjeta con:

CANAL 0
GPIO 26

Valor RAW:
2048

Voltaje:
1.65 V

Tambien mostrar una barra o indicador visual proporcional al valor analogico.

ACTUALIZACION EN TIEMPO REAL
Implementar polling configurable.

Por defecto:
- consultar /api/analog cada 500 ms o 1 segundo.
- permitir modificar el intervalo desde Configuracion.

Evitar realizar multiples requests simultaneos.
Si una peticion esta en curso, no iniciar otra hasta que termine.

Si se pierde la conexion:
- mostrar claramente el estado desconectado.
- no bloquear la interfaz.
- realizar reintentos automaticos.
- implementar timeout.
- mostrar el ultimo valor valido recibido.

CONFIGURACION
Crear una pantalla de Configuracion.

Permitir configurar:
- IP del Raspberry Pi Pico.
- puerto HTTP.
- intervalo de lectura.
- timeout de conexion.
- cantidad esperada de canales analogicos.
- activar/desactivar registro de mediciones.

Guardar la configuracion localmente para que permanezca despues de cerrar la aplicacion.

CONVERSION DE VALORES
La aplicacion debe mostrar tanto RAW como voltaje.

No hardcodear una conversion que impida futuras modificaciones.

Crear una configuracion para:
- ADC maximo, por ejemplo 4095.
- voltaje de referencia, por ejemplo 3.3 V.

La formula por defecto debe ser:

voltage = raw / adcMax * referenceVoltage

Pero si el Pico ya devuelve voltage en la API, utilizar ese valor.

HISTORIAL DE MEDICIONES
Crear una pantalla de Historial.

Permitir visualizar las mediciones recibidas.

Como minimo almacenar:
- timestamp
- canal
- RAW
- voltaje

Utilizar almacenamiento local.

Permitir:
- consultar historial
- borrar historial
- filtrar por canal
- seleccionar rango temporal

GRAFICOS
Crear una pantalla de Graficos.

Mostrar la evolucion del voltaje de cada canal a lo largo del tiempo.

Debe permitir:
- seleccionar uno o varios canales
- zoom
- desplazamiento horizontal
- cambiar rango temporal
- mostrar valor actual
- mostrar minimo
- mostrar maximo
- mostrar promedio

Utilizar una libreria Flutter apropiada para graficos.

ARQUITECTURA
Organizar el proyecto de forma modular.

Propuesta:

lib/
  main.dart
  app.dart

  models/
    device_status.dart
    analog_channel.dart
    analog_measurement.dart

  services/
    api_service.dart
    storage_service.dart

  repositories/
    measurement_repository.dart

  providers/
    device_provider.dart
    measurement_provider.dart
    settings_provider.dart

  screens/
    dashboard_screen.dart
    history_screen.dart
    charts_screen.dart
    settings_screen.dart

  widgets/
    analog_channel_card.dart
    connection_status.dart
    analog_gauge.dart
    measurement_chart.dart

  utils/
    constants.dart
    formatters.dart

GESTION DE ESTADO
Utilizar una solucion sencilla y estable para gestion de estado, por ejemplo Provider.

Separar claramente:
- UI
- estado
- servicios
- modelos
- persistencia

No colocar llamadas HTTP directamente dentro de los widgets.

MANEJO DE ERRORES
Gestionar correctamente:

- IP incorrecta.
- Pico apagado.
- WiFi desconectado.
- timeout.
- HTTP 404.
- HTTP 500.
- JSON invalido.
- respuesta incompleta.
- canal analogico faltante.
- valores fuera de rango.

Mostrar mensajes comprensibles para el usuario.

SEGURIDAD Y RED
La aplicacion esta pensada inicialmente para una red WiFi local.

No implementar autenticacion compleja salvo que sea necesaria.

Permitir posteriormente agregar:
- API key
- usuario
- password
- HTTPS

No almacenar credenciales en texto plano si posteriormente se incorporan.

PERMISOS ANDROID
Configurar correctamente AndroidManifest.xml para permitir acceso a Internet.

Agregar solamente los permisos realmente necesarios.

UI/UX
Crear una interfaz moderna estilo Material 3.

Debe funcionar correctamente en telefonos Android.

Usar:
- AppBar
- NavigationBar
- Cards
- Switches
- Sliders
- Dialogs
- SnackBars
- indicadores de conexion
- indicadores de carga

Pantallas principales:

1. Dashboard
2. Graficos
3. Historial
4. Configuracion

La navegacion debe ser simple.

PRUEBAS
Crear tests para:

- parseo JSON de DeviceStatus.
- parseo JSON de AnalogChannel.
- parseo JSON de AnalogMeasurement.
- conversion RAW a voltaje.
- manejo de JSON invalido.
- manejo de errores HTTP.
- configuracion del intervalo de polling.

MOCK / SIMULACION
Crear una implementacion MockApiService para poder ejecutar y probar la aplicacion sin tener fisicamente conectado el Raspberry Pi Pico.

El modo mock debe generar varios canales analogicos con valores que cambien con el tiempo.

Agregar una opcion en Configuracion:

Modo real
Modo simulacion

Esto permitira desarrollar la aplicacion Android antes de tener conectado el Pico.

DOCUMENTACION
Crear un README.md que explique:

1. Requisitos.
2. Instalacion de Flutter.
3. Como ejecutar el proyecto.
4. Como configurar la IP del Pico.
5. Formato JSON esperado.
6. Endpoints HTTP.
7. Como funciona el polling.
8. Como utilizar el modo simulacion.
9. Como conectar posteriormente una Raspberry Pi Pico W real.
10. Estructura del proyecto.

IMPORTANTE SOBRE LA RASPBERRY PI PICO
No generar solamente la aplicacion Flutter.

El proyecto debe estar preparado para consumir una API HTTP que sera ejecutada por una Raspberry Pi Pico W.

Documentar claramente el contrato de API que debe implementar el firmware del Pico.

La aplicacion Flutter NO debe asumir nombres de campos diferentes a los definidos en este documento.

REQUISITOS DE CALIDAD
- No dejar codigo incompleto.
- No utilizar pseudocodigo en lugar de implementaciones.
- No utilizar funciones TODO.
- No generar archivos innecesarios.
- No duplicar codigo.
- Manejar correctamente lifecycle de Flutter.
- Detener timers cuando una pantalla o provider ya no este activo.
- Liberar recursos correctamente.
- Evitar memory leaks.
- Mantener separacion entre UI y logica.
- Usar null safety.
- Mantener compatibilidad con versiones modernas de Flutter y Dart.
- Incluir pubspec.yaml completo con las dependencias necesarias.
- Crear todos los archivos necesarios.
- El resultado debe ser un proyecto Flutter compilable.

RESULTADO ESPERADO
Entregar el proyecto completo listo para copiar a un directorio y ejecutar:

flutter pub get
flutter run

La aplicacion debe permitir introducir la IP de una Raspberry Pi Pico W, conectarse mediante WiFi, consultar periodicamente sus entradas analogicas, mostrar los valores RAW y voltajes en tiempo real, graficarlos, almacenarlos localmente y consultar el historial.

Priorizar robustez y simplicidad. No agregar funcionalidades que no sean necesarias para este objetivo.
```
