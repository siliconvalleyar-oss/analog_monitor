# 02 - Hardware y cableado del ADC

## Pines analogicos de la Pico W

El RP2040 integra un ADC SAR de 12 bits (0-4095) con 5 entradas multiplexadas:

| Canal ADC | GPIO | Pin fisico | Uso |
|-----------|------|-----------|-----|
| 0 | GPIO 26 | 31 | Entrada analogica libre |
| 1 | GPIO 27 | 32 | Entrada analogica libre |
| 2 | GPIO 28 | 34 | Entrada analogica libre |
| 3 | GPIO 29 | 35 | **RESERVADO para el WiFi CYW43** |
| 4 | - | - | Sensor de temperatura interno del chip |

> **IMPORTANTE**: en la Pico W el GPIO 29 es la linea SPI del chip WiFi
> CYW43; **no** esta disponible para el usuario. Solo se usan los canales
> 0-2 (GPIO 26, 27, 28).

## Caracteristicas electricas

- Rango de entrada: **0 V a 3.3 V** (referencia interna, VREF).
- Resolucion: 12 bits -> 4096 pasos (LSB = 3.3/4096 = 0.8057 mV).
- Precision tipica del ADC: ~9 ENOB (epsilon significativa de ruido).
- Frecuencia de muestreo: ~500 kS/s.

## Elegir la resistencia de entrada

El pin ADC de la Pico W soporta lecturas directas de **hasta 3.3 V**. Para
señales mayores hay que usar un **divisor resistivo** o un amplificador.

Ejemplo: medir una bateria de 12 V con divisor 1:4 (R1=30k, R2=10k):

```
Vin(12V) ── R1 (30k) ──┬── GPIO 26 (ADC0)
                       │
                       R2 (10k)
                       │
                      GND
```

- Vout = Vin * R2/(R1+R2) = 12 * 10/40 = **3.0 V** (dentro del rango).
- En el firmware, el voltaje reportado es el de la salida del divisor.

## Sensores compatibles

- Potenciometro / divisor resistivo
- Sensor de temperatura LM35 / TMP36 (salida lineal 10 mV/°C)
- LDR + divisor (luminosidad)
- Cualquier senal analogica en 0-3.3 V

## Lectura y oversampling

`adc_reader_read()` repite `ADC_OVERSAMPLE_COUNT` lecturas por canal y
promedia para reducir el ruido. El valor se convierte a milivoltios con:

```
V_mV = (raw / 4095) * 3300
```

y se divide por 1000 en el servidor HTTP para reportar **voltios**
(3 decimales, p. ej. `"voltage": 3.289`).

La temperatura interna (campo `temperature` del `AdcReading`) se calcula
desde el sensor del RP2040: `T = 27 - (V - 706) / 1.721` (grados Celsius).