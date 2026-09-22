/// Indicador visual de conexion con la Pico W.
///
/// Muestra un punto de color y una etiqueta acorde al estado actual, junto con
/// un texto opcional con detalles (por ejemplo, el ultimo error).
library;

import 'package:flutter/material.dart';

import '../providers/device_state.dart';

class ConnectionStatus extends StatelessWidget {
  const ConnectionStatus({
    super.key,
    required this.state,
    this.detail,
    this.compact = false,
  });

  /// Estado de conexion a mostrar.
  final DeviceConnectionState state;

  /// Texto secundario (error, ultima actualizacion, etc.).
  final String? detail;

  /// Si `true` muestra solo el indicador compacto (punto + etiqueta corta).
  final bool compact;

  (Color, String) get _info => switch (state) {
        DeviceConnectionState.connected => (
            Colors.green,
            'Conectado',
          ),
        DeviceConnectionState.connecting => (
            Colors.orange,
            'Conectando...',
          ),
        DeviceConnectionState.disconnected => (
            Colors.red,
            'Desconectado',
          ),
      };

  @override
  Widget build(BuildContext context) {
    final (color, label) = _info;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: compact ? 10 : 12,
          height: compact ? 10 : 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.5),
                blurRadius: 6,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              if (detail != null && !compact)
                Text(
                  detail!,
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );
  }
}