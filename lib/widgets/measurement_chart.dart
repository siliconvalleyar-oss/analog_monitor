/// Grafico de lineas con la evolucion del voltaje de los canales.
///
/// Basado en `fl_chart`, dibuja una linea por canal dentro de una ventana
/// temporal (`minX`/`maxX` en milisegundos desde epoch). La gestion del zoom y
/// el desplazamiento se realiza desde la pantalla que lo utiliza.
library;

import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/measurement_sample.dart';
import '../utils/formatters.dart';

/// Paleta de colores utilizada para diferenciar canales.
const List<Color> _palette = [
  Color(0xFF2196F3),
  Color(0xFF4CAF50),
  Color(0xFFFF9800),
  Color(0xFF9C27B0),
  Color(0xFF00BCD4),
  Color(0xFFF44336),
  Color(0xFF3F51B5),
  Color(0xFF8BC34A),
];

/// Devuelve un color estable para un numero de canal.
Color channelColor(int channel) => _palette[channel % _palette.length];

class MeasurementChart extends StatelessWidget {
  const MeasurementChart({
    super.key,
    required this.series,
    required this.selectedChannels,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
  });

  /// Series completas de voltaje por canal (en memoria).
  final Map<int, List<MeasurementSample>> series;

  /// Canales que deben dibujarse.
  final Set<int> selectedChannels;

  /// Limites del eje X en milisegundos desde epoch.
  final double minX;
  final double maxX;

  /// Limites del eje Y (voltios).
  final double minY;
  final double maxY;

  @override
  Widget build(BuildContext context) {
    final bars = <LineChartBarData>[];

    for (final channel in selectedChannels) {
      final samples = series[channel] ?? const <MeasurementSample>[];
      final spots = samples
          .where((s) => _inWindow(s))
          .map((s) => FlSpot(
                s.timestamp.millisecondsSinceEpoch.toDouble(),
                s.voltage,
              ))
          .toList();
      if (spots.isEmpty) {
        continue;
      }
      final color = channelColor(channel);
      bars.add(
        LineChartBarData(
          spots: spots,
          color: color,
          isCurved: true,
          curveSmoothness: 0.25,
          barWidth: 2,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: color.withValues(alpha: 0.08),
          ),
        ),
      );
    }

    if (bars.isEmpty) {
      return Center(
        child: Text(
          'Sin datos para el rango seleccionado',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return LineChart(
      LineChartData(
        minX: minX,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: _niceInterval(maxY - minY, 4),
          getDrawingVerticalLine: (value) => FlLine(
            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
            strokeWidth: 1,
          ),
          getDrawingHorizontalLine: (value) => FlLine(
            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: _niceInterval(maxY - minY, 4),
              getTitlesWidget: (value, meta) => Text(
                value.toStringAsFixed(1),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: _niceInterval(maxX - minX, 4),
              getTitlesWidget: (value, meta) {
                final t = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(
                    formatTime(t),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipMargin: 8,
            getTooltipColor: (spot) => spot.bar.color ?? Colors.blueGrey,
            getTooltipItems: (spots) => spots.map((spot) {
              final channel = _channelForSpot(spot, selectedChannels, series);
              return LineTooltipItem(
                'Canal $channel\n${formatVoltage(spot.y)}',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              );
            }).toList(),
          ),
        ),
        lineBarsData: bars,
      ),
      duration: const Duration(milliseconds: 150),
    );
  }

  bool _inWindow(MeasurementSample s) {
    final x = s.timestamp.millisecondsSinceEpoch.toDouble();
    return x >= minX && x <= maxX;
  }

  /// Encuentra el canal al que pertenece un spot, comparando el indice dentro
  /// de la lista de puntos dibujados.
  int _channelForSpot(
    LineBarSpot spot,
    Set<int> selected,
    Map<int, List<MeasurementSample>> series,
  ) {
    var index = -1;
    for (final channel in selected) {
      final samples = series[channel] ?? const <MeasurementSample>[];
      if (samples.any(_inWindow)) {
        index++;
      }
      if (index == spot.barIndex) {
        return channel;
      }
    }
    return selected.isEmpty ? 0 : selected.first;
  }

  /// Calcula un intervalo redondo para las lineas de la cuadricula.
  double _niceInterval(double span, int targetTicks) {
    if (span <= 0) {
      return 1;
    }
    final rawStep = span / targetTicks;
    final magnitude = pow(10, (log(rawStep) / ln10).floor()).toDouble();
    final normalized = rawStep / magnitude;
    late final double niceStep;
    if (normalized <= 1) {
      niceStep = 1;
    } else if (normalized <= 2) {
      niceStep = 2;
    } else if (normalized <= 5) {
      niceStep = 5;
    } else {
      niceStep = 10;
    }
    return niceStep * magnitude;
  }
}