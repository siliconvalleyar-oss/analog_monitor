/// Pantalla de Historial.
///
/// Permite consultar las mediciones almacenadas localmente, filtrarlas por
/// canal y por rango temporal, y borrarlas.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/measurement_sample.dart';
import '../providers/measurement_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/formatters.dart';

enum _TimeFilter {
  all('Todo'),
  lastHour('Ultima hora'),
  lastDay('Ultimas 24 h'),
  custom('Personalizado');

  const _TimeFilter(this.label);

  final String label;
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int? _channelFilter;
  _TimeFilter _timeFilter = _TimeFilter.all;
  DateTimeRange? _customRange;

  late Future<List<MeasurementSample>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<MeasurementSample>> _load() {
    final provider = context.read<MeasurementProvider>();
    return provider.loadHistory(
      channel: _channelFilter,
      from: _timeFilter == _TimeFilter.lastHour
          ? DateTime.now().subtract(const Duration(hours: 1))
          : _timeFilter == _TimeFilter.lastDay
              ? DateTime.now().subtract(const Duration(days: 1))
              : _timeFilter == _TimeFilter.custom
                  ? _customRange?.start
                  : null,
      to: _timeFilter == _TimeFilter.custom
          ? _customRange?.end
          : DateTime.now(),
    );
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
      initialDateRange: _customRange,
      helpText: 'Selecciona el rango temporal',
      saveText: 'Aplicar',
    );
    if (range == null) {
      return;
    }
    setState(() {
      _customRange = range;
      _timeFilter = _TimeFilter.custom;
    });
    _reload();
  }

  Future<void> _confirmClear() async {
    final provider = context.read<MeasurementProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Borrar historial'),
        content: const Text(
          'Se eliminaran todas las mediciones guardadas. Esta accion no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await provider.clearHistory();
    _reload();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Historial eliminado')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial'),
        actions: [
          IconButton(
            tooltip: 'Borrar historial',
            onPressed: _confirmClear,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(context),
          Expanded(
            child: FutureBuilder<List<MeasurementSample>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'No se pudo cargar el historial:\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                final samples = snapshot.data ?? const <MeasurementSample>[];
                if (samples.isEmpty) {
                  return Center(
                    child: Text(
                      'Sin mediciones${_filtersDescription()}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  );
                }
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${samples.length} registros',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        itemCount: samples.length,
                        itemBuilder: (context, index) {
                          final latest = samples.length - 1 - index;
                          return _HistoryTile(sample: samples[latest]);
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _filtersDescription() {
    final parts = <String>[
      if (_channelFilter != null) 'del canal $_channelFilter',
      if (_timeFilter != _TimeFilter.all) 'en ${_timeFilter.label.toLowerCase()}',
    ];
    return parts.isEmpty ? '' : ' ${parts.join(' ')}';
  }

  Widget _buildFilters(BuildContext context) {
    final settings = context.read<SettingsProvider>().settings;
    final channels = [for (var i = 0; i < settings.channelCount; i++) i];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int?>(
                  initialValue: _channelFilter,
                  decoration: const InputDecoration(
                    labelText: 'Canal',
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Todos'),
                    ),
                    for (final ch in channels)
                      DropdownMenuItem<int?>(
                        value: ch,
                        child: Text('Canal $ch'),
                      ),
                  ],
                  onChanged: (value) {
                    setState(() => _channelFilter = value);
                    _reload();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<_TimeFilter>(
                  initialValue: _timeFilter,
                  decoration: const InputDecoration(
                    labelText: 'Rango temporal',
                    isDense: true,
                  ),
                  items: [
                    for (final value in _TimeFilter.values)
                      DropdownMenuItem(value: value, child: Text(value.label)),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    if (value == _TimeFilter.custom) {
                      _pickCustomRange();
                      return;
                    }
                    setState(() {
                      _timeFilter = value;
                      _customRange = null;
                    });
                    _reload();
                  },
                ),
              ),
            ],
          ),
          if (_customRange != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Desde ${formatDateTime(_customRange!.start)}\n'
                      'Hasta ${formatDateTime(_customRange!.end)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() => _customRange = null);
                      _reload();
                    },
                    child: const Text('Quitar filtro de fecha'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.sample});

  final MeasurementSample sample;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatDateTime(sample.timestamp),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Canal ${sample.channel}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'RAW ${formatRaw(sample.raw)}',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  formatVoltage(sample.voltage),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}