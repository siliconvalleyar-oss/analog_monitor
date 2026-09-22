/// Tarjeta de una entrada analogica.
///
/// Muestra el numero de canal, su GPIO, el valor RAW, el voltaje, una barra
/// proporcional ([AnalogGauge]) y un aviso si el valor esta fuera de rango.
library;

import 'package:flutter/material.dart';

import '../models/analog_channel.dart';
import '../utils/formatters.dart';
import 'analog_gauge.dart';

class AnalogChannelCard extends StatelessWidget {
  const AnalogChannelCard({
    super.key,
    required this.channel,
    required this.adcMax,
    required this.referenceVoltage,
  });

  /// Canal analogico a mostrar.
  final AnalogChannel channel;

  /// Valor maximo del ADC configurado.
  final int adcMax;

  /// Voltaje de referencia configurado.
  final double referenceVoltage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final voltage = channel.resolvedVoltage(
      adcMax: adcMax,
      referenceVoltage: referenceVoltage,
    );
    final outOfRange = channel.isOutOfRange(adcMax);

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: outOfRange
              ? scheme.error
              : scheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'CANAL ${channel.channel}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  formatGpio(channel.gpio),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _ValueBlock(
                    label: 'Valor RAW',
                    value: formatRaw(channel.raw),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ValueBlock(
                    label: 'Voltaje',
                    value: formatVoltage(voltage),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AnalogGauge(
              raw: channel.raw,
              adcMax: adcMax,
              referenceVoltage: referenceVoltage,
              voltage: voltage,
              color: outOfRange ? scheme.error : null,
            ),
            if (outOfRange) ...[
              const SizedBox(height: 8),
              Text(
                'Valor fuera de rango (maximo $adcMax)',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ValueBlock extends StatelessWidget {
  const _ValueBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}