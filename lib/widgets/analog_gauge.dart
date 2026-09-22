/// Barra indicadora proporcional al valor analogico.
///
/// Muestra una barra rellena de forma proporcional a `raw / adcMax`, con escala
/// de voltaje (0V a voltaje de referencia) y un marcador de posicion.
library;

import 'package:flutter/material.dart';

class AnalogGauge extends StatelessWidget {
  const AnalogGauge({
    super.key,
    required this.raw,
    required this.adcMax,
    required this.referenceVoltage,
    required this.voltage,
    this.color,
  });

  /// Valor RAW.
  final int raw;

  /// Valor maximo del ADC.
  final int adcMax;

  /// Voltaje de referencia (extremo de la escala).
  final double referenceVoltage;

  /// Voltaje calculado para mostrar en la escala.
  final double voltage;

  /// Color de la barra (por defecto usa el tema).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fillColor = color ?? scheme.primary;
    final fraction = adcMax <= 0 ? 0.0 : (raw / adcMax).clamp(0.0, 1.0);

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 12,
            child: Stack(
              children: [
                Container(
                  color: scheme.surfaceContainerHighest,
                ),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: fraction,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      gradient: LinearGradient(
                        colors: [
                          fillColor.withValues(alpha: 0.6),
                          fillColor,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '0 V',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              Text(
                '${referenceVoltage.toStringAsFixed(1)} V',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}