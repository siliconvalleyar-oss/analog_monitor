/// Pantalla de Configuracion.
///
/// Permite configurar la IP y puerto de la Pico, el intervalo de lectura, el
/// timeout, la cantidad de canales, la conversion RAW -> voltaje, el registro
/// de mediciones y el modo real/simulacion. La configuracion se guarda
/// localmente.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/device_provider.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late final TextEditingController _timeoutController;
  late final TextEditingController _channelCountController;
  late final TextEditingController _adcMaxController;
  late final TextEditingController _referenceVoltageController;

  late int _pollIntervalMs;
  late bool _enableLogging;
  late bool _useMock;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>().settings;
    _hostController = TextEditingController(text: settings.host);
    _portController = TextEditingController(text: '${settings.port}');
    _timeoutController = TextEditingController(text: '${settings.timeoutMs}');
    _channelCountController =
        TextEditingController(text: '${settings.channelCount}');
    _adcMaxController = TextEditingController(text: '${settings.adcMax}');
    _referenceVoltageController =
        TextEditingController(text: '${settings.referenceVoltage}');
    _pollIntervalMs = settings.pollIntervalMs;
    _enableLogging = settings.enableLogging;
    _useMock = settings.useMock;
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _timeoutController.dispose();
    _channelCountController.dispose();
    _adcMaxController.dispose();
    _referenceVoltageController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final settingsProvider = context.read<SettingsProvider>();
    final current = settingsProvider.settings;

    final settings = AppSettings(
      host: _hostController.text.trim(),
      port: int.parse(_portController.text.trim()),
      pollIntervalMs: _pollIntervalMs,
      timeoutMs: int.parse(_timeoutController.text.trim()),
      channelCount: int.parse(_channelCountController.text.trim()),
      adcMax: int.parse(_adcMaxController.text.trim()),
      referenceVoltage: double.parse(_referenceVoltageController.text.trim()),
      enableLogging: _enableLogging,
      useMock: _useMock,
    );

    await settingsProvider.save(settings);
    if (!mounted) {
      return;
    }
    // Reconfigura la capa de red y reinicia el polling con los nuevos valores.
    context.read<DeviceProvider>().refresh();

    final changed = settings != current;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(changed ? 'Configuracion guardada' : 'Sin cambios'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuracion'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Guardar'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionTitle(context, 'Conexion'),
            _labeledField(
              label: 'IP de la Pico',
              child: TextFormField(
                controller: _hostController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.lan),
                  hintText: '192.168.1.100',
                  helperText: 'Ejemplo: http://192.168.1.100',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final text = (value ?? '').trim();
                  if (text.isEmpty) {
                    return 'La IP no puede estar vacia';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 12),
            _labeledField(
              label: 'Puerto HTTP',
              child: TextFormField(
                controller: _portController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.dns_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: _intValidator(1, 65535, 'puerto'),
              ),
            ),
            const SizedBox(height: 12),
            _labeledField(
              label: 'Timeout de conexion (ms)',
              child: TextFormField(
                controller: _timeoutController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.timer_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: _intValidator(100, 60000, 'timeout'),
              ),
            ),
            _sectionTitle(context, 'Lectura'),
            _labeledField(
              label:
                  'Intervalo de lectura: $_pollIntervalMs ms',
              child: Slider(
                value: _pollIntervalMs.toDouble().clamp(200, 5000),
                min: 200,
                max: 5000,
                divisions: 24,
                label: '$_pollIntervalMs ms',
                onChanged: (value) {
                  setState(() => _pollIntervalMs = value.round());
                },
              ),
            ),
            const SizedBox(height: 12),
            _labeledField(
              label: 'Canales esperados',
              child: TextFormField(
                controller: _channelCountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.tune),
                  border: OutlineInputBorder(),
                ),
                validator: _intValidator(1, 8, 'cantidad de canales'),
              ),
            ),
            _sectionTitle(context, 'Conversion RAW -> voltaje'),
            Row(
              children: [
                Expanded(
                  child: _labeledField(
                    label: 'ADC maximo',
                    child: TextFormField(
                      controller: _adcMaxController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      validator: _intValidator(1, 1000000, 'ADC maximo'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _labeledField(
                    label: 'Voltaje de referencia (V)',
                    child: TextFormField(
                      controller: _referenceVoltageController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      validator: _doubleValidator(0.01, 100, 'voltaje'),
                    ),
                  ),
                ),
              ],
            ),
            _sectionTitle(context, 'Registro y modo'),
            SwitchListTile(
              title: const Text('Registrar mediciones'),
              subtitle: const Text('Guarda las lecturas en el historial local'),
              secondary: const Icon(Icons.storage),
              value: _enableLogging,
              onChanged: (value) => setState(() => _enableLogging = value),
            ),
            SwitchListTile(
              title: const Text('Modo simulacion'),
              subtitle: const Text(
                'Genera datos simulados sin necesidad de la Pico',
              ),
              secondary: const Icon(Icons.smart_toy_outlined),
              value: _useMock,
              onChanged: (value) => setState(() => _useMock = value),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Guardar configuracion'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }

  Widget _labeledField({
    required String label,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  String? Function(String?) _intValidator(int min, int max, String name) {
    return (value) {
      final parsed = int.tryParse((value ?? '').trim());
      if (parsed == null) {
        return 'Ingresa un numero entero valido';
      }
      if (parsed < min || parsed > max) {
        return 'Debe estar entre $min y $max';
      }
      return null;
    };
  }

  String? Function(String?) _doubleValidator(
    double min,
    double max,
    String name,
  ) {
    return (value) {
      final parsed = double.tryParse((value ?? '').trim());
      if (parsed == null) {
        return 'Ingresa un numero valido';
      }
      if (parsed < min || parsed > max) {
        return 'Debe estar entre $min y $max';
      }
      return null;
    };
  }
}