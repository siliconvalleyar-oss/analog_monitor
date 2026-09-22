# 02 - Hardware y Conexiones

## Raspberry Pi Pico W

La Pico W es una variante de la Raspberry Pi Pico con chip WiFi CYW43022
integrado. Utiliza el microcontrolador RP2040 (dual-core ARM Cortex-M0+).

### Especificaciones del RP2040

| Parametro | Valor |
|-----------|-------|
| Procesador | Dual ARM Cortex-M0+ @ 133 MHz |
| RAM | 264 KB SRAM |
| Flash | 2 MB (externa, W25Q16JV) |
| ADC | 12 bits, 500 kS/s, 5 canales |
| GPIO | 26 pines (GP0 - GP25) + 3 del CYW43 |
| USB | USB 1.1 Host/Device |
| UART | 2x |
| SPI | 2x |
| I2C | 2x |
| PWM | 16 canales (8 slices) |

### Especificaciones del CYW43022 (WiFi)

| Parametro | Valor |
|-----------|-------|
| Estandard | 802.11 b/g/n |
| Frecuencia | 2.4 GHz |
| Seguridad | WPA2-PSK, WPA/WPA2-mixed |
| Interface | SPI (GPIO 23-25, 29) |
| GPIO del chip | 3 pines (WL_GPIO0-2) |

## Pines ADC Disponibles

En la Pico W, el GPIO 29 esta reservado para el chip WiFi (linea de reloj SPI).
Solo 3 de los 5 canales ADC estan disponibles para el usuario:

```
+------------------+----------+------------+------------------+
| Canal ADC        | GPIO     | Pin fisico | Estado en Pico W |
+------------------+----------+------------+------------------+
| Canal 0 (ADC0)   | GPIO 26  | Pin 31     | DISPONIBLE       |
| Canal 1 (ADC1)   | GPIO 27  | Pin 32     | DISPONIBLE       |
| Canal 2 (ADC2)   | GPIO 28  | Pin 34     | DISPONIBLE       |
| Canal 3 (ADC3)   | GPIO 29  | Pin 35     | RESERVADO WiFi   |
| Canal 4 (Temp)   | Interno  | N/A        | Sensor interno   |
+------------------+----------+------------+------------------+
```

## Diagrama de Pines (Vista Superior)

```
                    PICO W (vista superior)
                 +------------------------+
    GP0  (TX)  1 | o                    40 | GP39
    GP1  (RX)  2 | o                    39 | GP38
    GND        3 |                      38 | GP37
    GP2        4 | o                    37 | GP36
    GP3        5 | o                    36 | GP35
    GP4  (SDA) 6 | o                    35 | GP34  <-- ADC2 (Canal 2)
    GP5  (SCL) 7 | o                    34 | GP33
    GND        8 |                      33 | GP32  <-- ADC1 (Canal 1)
    GP6        9 | o                    32 | GP31
    GP7       10 | o                    31 | GP30
    GP8       11 | o                    30 | GP29  *** RESERVADO WiFi ***
    GP9       12 | o                    29 | GP28  <-- ADC0 (Canal 0)
    GND       13 |                      28 | GP27  <-- ADC1 (Canal 1)
    GP10      14 | o                    27 | GP26  <-- ADC0 (Canal 0)
    GP11      15 | o                    26 | RUN
    GP12      16 | o                    25 | GP22
    GP13      17 | o                    24 | LED  (CYW43 GPIO0)
    GND       18 |                      23 | GP21
    GP14      19 | o                    22 | GP20
    GP15      20 | o                    21 | GP19
    GP16 (MISO)21 | o                    20 | GP18
    GP17 (CS) 22 | o                    19 | GP17
    GP18 (SCK)23 | o                    18 | GP16
    GP19 (MOSI)24| o                    17 | GP15
    GND       25 |                      16 | GP14
    GP20      26 | o                    15 | GP13
    GP21      27 | o                    14 | GP12
    GP22      28 | o                    13 | GP11
    RUN       29 |                      12 | GP10
    GP26  <-- ADC0  30 | o              11 | GP9
                31 | o               10 | GP8
                32 | o                9 | GP7
                33 |                  8 | GP6
                34 | o                7 | GP5
                35 |                  6 | GP4
                36 | o                5 | GP3
                37 |                  4 | GP2
                38 |                  3 | GND
                39 | o                2 | GP1 (RX)
                40 | o                1 | GP0 (TX)
                 +------------------------+
                          USB
```

**NOTA:** Los pines ADC estan en el lado derecho de la placa. En la Pico W,
el GP29 (pin 35) esta reservado para el chip WiFi y NO puede usarse como ADC.

## Circuito de Ejemplo: Division de Voltaje

Para medir voltajes mayores a 3.3V, usar un divisor resistivo:

```
    Vin (0 - 30V)
      |
      +---[R1 = 100K]---+---[R2 = 10K]---+--- GND
                         |
                         +---> GP26 (ADC0)

    Vout = Vin * R2 / (R1 + R2)
    Vout = Vin * 10K / 110K
    Vout = Vin * 0.0909

    Para Vin = 30V: Vout = 2.73V (dentro del rango del ADC)
```

**IMPORTANTE:** Siempre incluir un capacitor de 100nF entre el punto de
medicion y GND para filtrar ruido de alta frecuencia.

## Circuito de Ejemplo: Sensor LM35

El LM35 proporciona 10mV por grado Celsius:

```
    +5V ---+
            |
          [LM35]
            |
            +---> GP27 (ADC1)
            |
          [100nF]  (capacitor de filtro)
            |
           GND

    Vout = 10mV/°C * T
    A 25°C: Vout = 250mV = 0.25V
    A 100°C: Vout = 1000mV = 1.0V
```

## Circuito de Ejemplo: LDR (Luminosidad)

```
    +3.3V ---+
              |
            [LDR]
              |
              +---> GP28 (ADC2)
              |
            [10K]  (resistencia fija)
              |
             GND

    A mayor luz -> menor resistencia del LDR -> mayor voltaje en ADC
    A oscuridad -> mayor resistencia del LDR -> menor voltaje en ADC
```

## Alimentacion

| Metodo | Voltaje | Notas |
|--------|---------|-------|
| USB | 5V | Recomendado para desarrollo |
| VSYS (pin 39) | 1.8V - 5.5V | Para alimentacion con bateria |
| VBUS (pin 40) | 5V directo del USB | Solo cuando USB conectado |

**NOTA:** El ADC usa VREF = 3.3V (regulador interno). Las mediciones son
siempre en el rango 0 - 3.3V, sin importar el voltaje de alimentacion.

## Proteccion del Pin ADC

Para proteger el pin ADC contra voltajes excesivos:

```
    Senal de entrada
      |
      +---[1K]---+---[Zener 3.3V]--- GND
                  |
                  +---> Pin ADC
```

La resistencia limita la corriente y el diodo Zener corta el voltaje
a 3.3V maximo.
