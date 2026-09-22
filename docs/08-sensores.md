# 08 - Sensores Analogicos Compatibles

El ADC del RP2040 acepta voltajes entre **0V y 3.3V** con resolucion de 12 bits.
Cualquier sensor que produzca una senal en este rango puede conectarse directamente.
Para voltajes mayores, se requiere un divisor resistivo.

## Especificaciones del ADC

| Parametro | Valor |
|-----------|-------|
| Rango de entrada | 0V a 3.3V (VREF) |
| Resolucion | 12 bits (0 a 4095) |
| Voltaje por LSB | 3.3V / 4096 = 0.8057 mV |
| Impedancia de entrada | ~100 ohm (typ) |
| Velocidad de muestreo | 500 kS/s (max) |
| Precision efectiva | ~9 ENOB |
| Corriente de entrada | < 1 uA (typ) |

## Sensores de Temperatura

### LM35 (Precision, 0-100°C)

```
Pinout: VS (pin 5), VOUT (pin 2), GND (pin 3)

+5V ---+
        |
      [LM35]
        |
        +---[100nF]---+---> GP27 (ADC1)
        |             |
       GND           GND

Relacion: 10mV/°C
25°C = 250mV (ADC raw: 310)
100°C = 1000mV (ADC raw: 1241)
```

### TMP35 (Alternativa al LM35)

```
Igual conexion que LM35
Relacion: 10mV/°C (mismo rango)
Ventaja: Mayor disponibilidad
```

### TMP36 (Rango extendido, -40°C a 125°C)

```
+5V ---+
        |
      [TMP36]
        |
        +---[100nF]---+---> GP27 (ADC1)
        |             |
       GND           GND

Relacion: 10mV/°C con offset de 500mV
25°C = 750mV (ADC raw: 931)
0°C = 500mV (ADC raw: 621)
-40°C = 100mV (ADC raw: 124)
```

### Sensor Interno del RP2040

```
No requiere conexion externa.
Canal 4 del ADC (seleccionado automaticamente).
Precision: ±2°C
Rango util: ~0°C a ~85°C
Formula: T = 27 - (Vadc - 0.706) / 0.001721
```

## Sensores de Luz

### LDR (Fotoresistencia)

```
+3.3V ---+
          |
        [LDR]
          |
          +---[100nF]---+---> GP28 (ADC2)
          |             |
        [10K]          GND
          |
         GND

Luz fuerte: LDR ~1K -> Vout ~2700mV (ADC raw: 3354)
Oscuridad: LDR ~1M -> Vout ~33mV (ADC raw: 41)
```

### BH1750 (Digital, NO compatible directamente)

```
Este sensor es I2C, NO analogico.
Usar con el modulo I2C de la Pico W.
No conectar al ADC.
```

## Sensores de Voltaje/Corriente

### Divisor Resistivo (0-30V a 0-3.3V)

```
Vin (0-30V) ---[R1=100K]---+---[R2=10K]---+--- GND
                             |
                             +---> GP26 (ADC0)

Factor: Vout = Vin * R2/(R1+R2) = Vin * 0.0909
30V -> 2.73V (ADC raw: 3388)
15V -> 1.36V (ADC raw: 1694)
0V  -> 0.0V  (ADC raw: 0)
```

**NOTA:** Siempre usar R1 >= 10K para no sobrecargar la fuente.

### Sensor de Corriente ACS712 (5A/20A/30A)

```
+5V --- [ACS712] ---+
            |
            +---[100nF]---+---> GP26 (ADC0)
            |             |
           GND           GND

Salida: Vout = Vcc/2 + (I * Sensitivity)
5A:   Sensitivity = 185mV/A -> 0A = 2500mV
20A:  Sensitivity = 100mV/A -> 0A = 2500mV
30A:  Sensitivity = 66mV/A  -> 0A = 2500mV
```

### Sensor de Voltaje ZMPT101B (AC/DC)

```
AC/DC ---[ZMPT101B]---+
            |
            +---[100nF]---+---> GP27 (ADC1)
            |             |
          [10K]          GND
            |
           GND

Rango: 0-250V AC/DC
Precision: ±1%
Requiere calibracion con voltaje conocido
```

## Sensores de Presion/Humedad

### Sensor de Presion de Liquido (0.5-4.5V)

```
+5V ---+
        |
      [Sensor]  (ej: MPX5010, MPX5700)
        |
        +---[Divisor R: 10K/2.2K]---+---> GP26 (ADC0)
        |                            |
       GND                          GND

Factor: 2.2K/(10K+2.2K) = 0.18
4.5V -> 0.81V (ADC raw: 1006)
0.5V -> 0.09V (ADC raw: 112)
```

### DHT22 (Digital, NO compatible directamente)

```
Este sensor es digital (1-Wire).
Usar con el modulo GPIO correspondiente.
No conectar al ADC.
```

## Potenciometros y Encoders

### Potenciometro Lineal (10K)

```
+3.3V ---+
          |
        [Pot 10K]
          |
          +---[100nF]---+---> GP26 (ADC0)
          |             |
          o (wiper)    GND
          |
         GND (posible, pero ya conectado)

Giro completo: 0mV a 3300mV
```

### Divisor de Voltaje por Potenciometro

```
Vin ---[Pot 10K]---+---[R fija 10K]---+--- GND
                    |
                    +---> GP27 (ADC1)

Permite ajustar manualmente el voltaje de entrada al ADC.
```

## Circuitos de Proteccion

### Proteccion contra Sobreveltaje (Zener)

```
Senal --->[1K]---+---|>|--- GND  (Diodo Zener 3.3V)
                  |
                  +---> ADC

Si Vin > 3.3V + Vf_zener, el Zener conduce y limita el voltaje.
La resistencia de 1K limita la corriente.
```

### Filtro RC Anti-Aliasing

```
Senal --->[R=1K]---+---[C=100nF]---+---> ADC
                    |               |
                    +--- Senal      GND

Frecuencia de corte: fc = 1/(2*pi*R*C) = 1592 Hz
Elimina ruido de alta frecuencia antes del ADC.
```

### Filtro Pi (Mayor atenuacion)

```
Senal --->[R1=470R]---+---[R2=470R]---+---> ADC
                      |               |
                    [C1=100nF]     [C2=100nF]
                      |               |
                     GND             GND

Mejor atenuacion de ruido de alta frecuencia.
```

## Tabla Resumen de Sensores

| Sensor | Tipo | Rango | Voltaje de salida | Canal ADC | Precision |
|--------|------|-------|-------------------|-----------|-----------|
| LM35 | Temperatura | 0-100°C | 0-1.0V | CH1 | ±0.5°C |
| TMP36 | Temperatura | -40-125°C | 0.1-1.75V | CH1 | ±1°C |
| LDR | Luz | Oscuro-Brillante | 0-3.3V | CH2 | Qualitativo |
| Pot 10K | Posicion | 0-100% | 0-3.3V | CH0 | ±1% |
| ACS712 | Corriente | ±5A/20A/30A | 0-5V | CH0 | ±1.5% |
| ZMPT101B | Voltaje AC | 0-250V | 0-3.3V | CH1 | ±1% |
| Divisor R | Voltaje DC | 0-30V | 0-3.3V | CH0 | ±2% |
| Sensor Presion | Presion | 0-100kPa | 0.5-4.5V | CH0 | ±2.5% |

## Consejos de Instalacion

1. **Capacitor de desacople:** Siempre usar 100nF ceramico entre VCC y GND
   del sensor, y entre la salida del sensor y GND.

2. **Cableado:** Usar cables lo mas cortos posible. Cables largos actuan como
   antenas y captan interferencias electromagneticas.

3. **Tierra comun:** Asegurar que todos los sensores compartan la misma
   referencia de tierra con el Pico W.

4. **Separacion analogica/digital:** Mantener los cables del ADC separados
   de cables de alimentacion conmutada o señales digitales de alta velocidad.

5. **Filtrado hardware:** Siempre usar al menos un capacitor de 100nF como
   filtro de entrada al pin ADC.
