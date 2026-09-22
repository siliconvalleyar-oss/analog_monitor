/// Pantalla principal (Dashboard).
///
/// Muestra el estado de conexion, informacion del dispositivo y las tarjetas
/// de cada entrada analogica con su valor RAW y voltaje en tiempo real.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/device_status.dart';
import '../providers/device_provider.dart';
import '../providers/device_state.dart';
import '../providers/settings_provider.dart';
import '../utils/formatters.dart';
import '../widgets/analog_channel_card.dart';
import '../widgets/connection_status.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final device = context.watch<DeviceProvider>();
    final settings = context.watch<SettingsProvider>().settings;
    final measurement = device.lastMeasurement;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Conectar ahora',
            onPressed: () => context.read<DeviceProvider>().refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStatusCard(context, device, settings),
          const SizedBox(height: 16),
          if (measurement == null)
            _buildEmptyState(context, device)
          else ...[
            _buildSummary(context, device, measurement.channels.length),
            const SizedBox(height: 12),
            ..._buildChannelCards(device, settings),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusCard(
    BuildContext context,
    DeviceProvider device,
    AppSettings settings,
  ) {
    final theme = Theme.of(context);
    final status = device.deviceStatus;

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: ConnectionStatus(
                    state: device.connectionState,
                    detail: device.lastError,
                  ),
                ),
                IconButton(
                  tooltip: 'Reintentar conexion',
                  onPressed: () => context.read<DeviceProvider>().refresh(),
                  icon: const Icon(Icons.sync),
                ),
              ],
            ),
            const Divider(height: 24),
            _InfoRow(
              icon: Icons.lan,
              label: 'Dispositivo',
              value: _deviceLabel(status, settings),
            ),
            _InfoRow(
              icon: Icons.router_outlined,
              label: 'IP',
              value: 'http://${settings.host}:${settings.port}',
            ),
            _InfoRow(
              icon: Icons.network_wifi,
              label: 'Senal WiFi',
              value: formatRssi(status?.wifiRssi),
            ),
            _InfoRow(
              icon: Icons.timer_outlined,
              label: 'Tiempo activo',
              value: status == null
                  ? '--'
                  : formatUptime(status.uptimeSeconds),
            ),
            _InfoRow(
              icon: Icons.schedule,
              label: 'Ultima actualizacion',
              value: device.lastUpdate == null
                  ? '--'
                  : formatDateTime(device.lastUpdate!),
            ),
            _InfoRow(
              icon: Icons.analytics_outlined,
              label: 'Modo',
              value: settings.useMock ? 'Simulacion' : 'Real (Pico)',
            ),
          ],
        ),
      ),
    );
  }

  String _deviceLabel(DeviceStatus? status, AppSettings settings) {
    if (status != null) {
      return '${status.device}${status.connected ? '' : ' (inactivo)'}';
    }
    return 'Raspberry Pi Pico W';
  }

  Widget _buildSummary(
    BuildContext context,
    DeviceProvider device,
    int receivedChannels,
  ) {
    final theme = Theme.of(context);
    final expected = device.expectedChannels.length;
    final color = receivedChannels >= expected
        ? theme.colorScheme.primary
        : theme.colorScheme.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.priority_high, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Canales analogicos: $receivedChannels / $expected',
              style: theme.textTheme.titleSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildChannelCards(
    DeviceProvider device,
    AppSettings settings,
  ) {
    final measurement = device.lastMeasurement;
    if (measurement == null) {
      return const [];
    }

    final byChannel = {
      for (final c in measurement.channels) c.channel: c,
    };
    final expected = device.expectedChannels;

    return [
      for (final ch in expected)
        if (byChannel.containsKey(ch))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AnalogChannelCard(
              channel: byChannel[ch]!,
              adcMax: settings.adcMax,
              referenceVoltage: settings.referenceVoltage,
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _MissingChannelCard(channel: ch),
          ),
    ];
  }

  Widget _buildEmptyState(BuildContext context, DeviceProvider device) {
    final connected = device.connectionState != DeviceConnectionState.disconnected;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            if (connected)
              const CircularProgressIndicator()
            else
              const Icon(Icons.cloud_off, size: 56),
            const SizedBox(height: 12),
            Text(
              connected
                  ? 'Esperando primera medicion...'
                  : 'Sin datos. Verifica la conexion y la IP de la Pico.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _MissingChannelCard extends StatelessWidget {
  const _MissingChannelCard({required this.channel});

  final int channel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: theme.colorScheme.error,
            ),
            const SizedBox(width: 12),
            Text(
              'CANAL $channel no recibido',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}