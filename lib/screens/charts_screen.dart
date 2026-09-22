/// Pantalla de Graficos.
///
/// Muestra la evolucion del voltaje de cada canal a lo largo del tiempo con
/// zoom, desplazamiento horizontal, seleccion de canales, rango temporal y
/// estadisticas (actual, minimo, maximo y promedio) para la ventana visible.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/measurement_sample.dart';
import '../providers/measurement_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/formatters.dart';
import '../widgets/measurement_chart.dart';

enum _TimeRangePreset {
  last30s('Ultimos 30 s', Duration(seconds: 30)),
  last1m('Ultimo 1 min', Duration(minutes: 1)),
  last5m('Ultimos 5 min', Duration(minutes: 5)),
  last10m('Ultimos 10 min', Duration(minutes: 10));

  const _TimeRangePreset(this.label, this.duration);

  final String label;
  final Duration duration;
}

class ChartsScreen extends StatefulWidget {
  const ChartsScreen({super.key});

  @override
  State<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends State<ChartsScreen> {
  Set<int> _selectedChannels = {};
  _TimeRangePreset _preset = _TimeRangePreset.last1m;

  // Ventana visible en milisegundos desde epoch.
  double? _startX;
  double? _endX;
  bool _windowInitialized = false;

  @override
  void initState() {
    super.initState();
    _selectedChannels = _initialSelection();
  }

  Set<int> _initialSelection() {
    final settings = context.read<SettingsProvider>().settings;
    return {for (var i = 0; i < settings.channelCount; i++) i};
  }

  void _resetWindow(double fullMinX, double fullMaxX) {
    setState(() {
      _startX = fullMinX;
      _endX = fullMaxX;
      _windowInitialized = true;
    });
  }

  void _applyPreset(double fullMaxX) {
    final width = _preset.duration.inMilliseconds.toDouble();
    setState(() {
      _startX = fullMaxX - width;
      _endX = fullMaxX;
      _windowInitialized = true;
    });
  }

  void _zoom(double factor) {
    final (center, width) = _currentWindow();
    final newWidth = (width * factor).clamp(1000.0, double.infinity);
    setState(() {
      _startX = center - newWidth / 2;
      _endX = center + newWidth / 2;
    });
  }

  void _pan(double fraction) {
    final (center, width) = _currentWindow();
    setState(() {
      _startX = center + width * fraction - width / 2;
      _endX = center + width * fraction + width / 2;
    });
  }

  (double, double) _currentWindow() {
    final start = _startX ?? 0;
    final end = _endX ?? 1;
    return ((start + end) / 2, (end - start).abs());
  }

  (double, double) _clampWindow(double fullMinX, double fullMaxX) {
    var s = _startX ?? fullMinX;
    var e = _endX ?? fullMaxX;
    if (s < fullMinX) {
      s = fullMinX;
    }
    if (e > fullMaxX) {
      e = fullMaxX;
    }
    if ((e - s).abs() < 1.0) {
      s = fullMinX;
      e = fullMinX + (fullMaxX - fullMinX);
    }
    return (s, e);
  }

  double _maxVisibleVoltage(
    Map<int, List<MeasurementSample>> series,
    Set<int> selected,
    double startX,
    double endX,
  ) {
    var max = 0.0;
    for (final channel in selected) {
      for (final s in series[channel] ?? const <MeasurementSample>[]) {
        final x = s.timestamp.millisecondsSinceEpoch.toDouble();
        if (x >= startX && x <= endX && s.voltage > max) {
          max = s.voltage;
        }
      }
    }
    return max;
  }

  @override
  Widget build(BuildContext context) {
    final measurements = context.watch<MeasurementProvider>();
    final settings = context.watch<SettingsProvider>().settings;
    final series = measurements.series;

    final (fullMinX, fullMaxX) = _fullSpan(series, _selectedChannels);
    if (!_windowInitialized && fullMinX < fullMaxX) {
      // Inicializa la ventana sin setState: la asignacion es lo suficientemente
      // temprana como para usarse en este mismo build.
      _startX = fullMinX;
      _endX = fullMaxX;
      _windowInitialized = true;
    }

    final (startX, endX) = _clampWindow(fullMinX, fullMaxX);
    final stats = _computeStats(series, _selectedChannels, startX, endX);
    final maxVoltage =
        _maxVisibleVoltage(series, _selectedChannels, startX, endX);
    final chartMaxY = (settings.referenceVoltage > maxVoltage
            ? settings.referenceVoltage
            : maxVoltage) *
        1.05;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Graficos'),
        actions: [
          IconButton(
            tooltip: 'Ver todo',
            onPressed:
                fullMinX < fullMaxX ? () => _resetWindow(fullMinX, fullMaxX) : null,
            icon: const Icon(Icons.fit_screen),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _buildChannelSelector(context),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: _buildRangeControls(context),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildStats(context, stats),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
              child: series.isEmpty
                  ? Center(
                      child: Text(
                        'Esperando datos de la Pico...',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    )
                  : MeasurementChart(
                      series: series,
                      selectedChannels: _selectedChannels,
                      minX: startX,
                      maxX: endX,
                      minY: 0,
                      maxY: chartMaxY,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelSelector(BuildContext context) {
    final settings = context.read<SettingsProvider>().settings;
    final channels = [for (var i = 0; i < settings.channelCount; i++) i];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Canales',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final ch in channels)
              FilterChip(
                selected: _selectedChannels.contains(ch),
                label: Text('Canal $ch'),
                avatar: CircleAvatar(
                  backgroundColor: channelColor(ch),
                  child: const SizedBox.shrink(),
                ),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedChannels.add(ch);
                    } else {
                      _selectedChannels.remove(ch);
                    }
                  });
                },
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildRangeControls(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<_TimeRangePreset>(
            initialValue: _preset,
            decoration: const InputDecoration(
              labelText: 'Rango temporal',
              isDense: true,
            ),
            items: [
              for (final value in _TimeRangePreset.values)
                DropdownMenuItem(value: value, child: Text(value.label)),
            ],
            onChanged: (value) {
              if (value == null) {
                return;
              }
              final measurements = context.read<MeasurementProvider>();
              final (_, fullMaxX) =
                  _fullSpan(measurements.series, _selectedChannels);
              setState(() => _preset = value);
              _applyPreset(fullMaxX);
            },
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Desplazar a la izquierda',
          onPressed: () => _pan(0.2),
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          tooltip: 'Alejar',
          onPressed: () => _zoom(1.8),
          icon: const Icon(Icons.zoom_out),
        ),
        IconButton(
          tooltip: 'Acercar',
          onPressed: () => _zoom(1 / 1.8),
          icon: const Icon(Icons.zoom_in),
        ),
        IconButton(
          tooltip: 'Desplazar a la derecha',
          onPressed: () => _pan(-0.2),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _buildStats(BuildContext context, Map<int, _Stats> stats) {
    if (stats.isEmpty) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 34,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final entry in stats.entries)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _StatsCard(channel: entry.key, stats: entry.value),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Modelo de estadisticas y helpers de calculo
// ---------------------------------------------------------------------------

class _Stats {
  const _Stats({
    required this.current,
    required this.min,
    required this.max,
    required this.average,
  });

  final double current;
  final double min;
  final double max;
  final double average;
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.channel, required this.stats});

  final int channel;
  final _Stats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = channelColor(channel);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        'Canal $channel  ${formatVoltage(stats.current)}  '
        'min ${formatVoltage(stats.min)}  max ${formatVoltage(stats.max)}  '
        'avg ${formatVoltage(stats.average)}',
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

_Stats? _statsFor(
  List<MeasurementSample> samples,
  double startX,
  double endX,
) {
  final visible = samples
      .where((s) {
        final x = s.timestamp.millisecondsSinceEpoch.toDouble();
        return x >= startX && x <= endX;
      })
      .toList();
  if (visible.isEmpty) {
    return null;
  }

  var min = visible.first.voltage;
  var max = visible.first.voltage;
  var sum = 0.0;
  for (final s in visible) {
    min = s.voltage < min ? s.voltage : min;
    max = s.voltage > max ? s.voltage : max;
    sum += s.voltage;
  }
  return _Stats(
    current: visible.last.voltage,
    min: min,
    max: max,
    average: sum / visible.length,
  );
}

Map<int, _Stats> _computeStats(
  Map<int, List<MeasurementSample>> series,
  Set<int> selected,
  double startX,
  double endX,
) {
  final result = <int, _Stats>{};
  for (final channel in selected) {
    final samples = series[channel];
    if (samples == null) {
      continue;
    }
    final stats = _statsFor(samples, startX, endX);
    if (stats != null) {
      result[channel] = stats;
    }
  }
  return result;
}

(double, double) _fullSpan(
  Map<int, List<MeasurementSample>> series,
  Set<int> selected,
) {
  var minX = double.infinity;
  var maxX = -double.infinity;
  for (final channel in selected) {
    for (final s in series[channel] ?? const <MeasurementSample>[]) {
      final x = s.timestamp.millisecondsSinceEpoch.toDouble();
      if (x < minX) {
        minX = x;
      }
      if (x > maxX) {
        maxX = x;
      }
    }
  }
  if (minX > maxX) {
    return (0, 1);
  }
  if (minX == maxX) {
    maxX = minX + 1;
  }
return (minX, maxX);
  }