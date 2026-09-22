/**
 * =============================================================================
 * adc_reader.h - Modulo de lectura del Convertidor Analogico-Digital (ADC)
 * =============================================================================
 *
 * Este modulo encapsula toda la logica de inicializacion y lectura de los
 * canales analogicos del RP2040 en la Raspberry Pi Pico W.
 *
 * HARDWARE:
 *   El RP2040 tiene un ADC SAR de 12 bits con 5 entradas multiplexadas:
 *     - Canal 0: GPIO 26 (ADC0) - Pin fisico 31
 *     - Canal 1: GPIO 27 (ADC1) - Pin fisico 32
 *     - Canal 2: GPIO 28 (ADC2) - Pin fisico 34
 *     - Canal 3: GPIO 29 (ADC3) - Pin fisico 35 ** USADO POR CYW43 WiFi **
 *     - Canal 4: Sensor de temperatura interno
 *
 *   IMPORTANTE: En la Pico W, el GPIO 29 esta reservado para el chip WiFi
 *   CYW43 (linea de reloj SPI). Solo los canales 0-2 estan disponibles
 *   para el usuario.
 *
 * RANGO DE MEDICION:
 *   - Rango del ADC: 0V a 3.3V (referencia VREF = 3.3V)
 *   - Resolucion: 12 bits (0-4095)
 *   - Voltaje por LSB: 3.3V / 4096 = 0.8057 mV
 *   - Precision tipica: ~9 ENOB (Effective Number of Bits)
 *
 * SENSORES COMPATIBLES:
 *   - Divisor voltaje resistivo (para medir > 3.3V)
 *   - Sensor LM35 / TMP36 (temperatura)
 *   - LDR (luminosidad)
 *   - Potenciometro
 *   - Cualquier senal analogica 0-3.3V
 *
 * METODO DE MUESTREO:
 *   Se usa oversampling (promediacion de N muestras) para reducir el ruido
 *   digital. Configurable via ADC_OVERSAMPLE_COUNT en wifi_config.h.
 * =============================================================================
 */

#ifndef ADC_READER_H
#define ADC_READER_H

#include <cstdint>

/**
 * Estructura que contiene las mediciones de todos los canales ADC.
 * Cada campo almacena el valor promedio de las ultimas N lecturas.
 *
 * Campos:
 *   voltage_ch0 - Voltaje del canal 0 (GPIO 26) en milivoltios
 *   voltage_ch1 - Voltaje del canal 1 (GPIO 27) en milivoltios
 *   voltage_ch2 - Voltaje del canal 2 (GPIO 28) en milivoltios
 *   raw_ch0     - Valor crudo ADC del canal 0 (0-4095)
 *   raw_ch1     - Valor crudo ADC del canal 1 (0-4095)
 *   raw_ch2     - Valor crudo ADC del canal 2 (0-4095)
 *   temperature - Temperatura del sensor interno en grados Celsius
 *   timestamp   - Marca de tiempo en milisegundos desde el arranque
 */
struct AdcReading {
    float    voltage_ch0;    /* Voltaje canal 0 en mV */
    float    voltage_ch1;    /* Voltaje canal 1 en mV */
    float    voltage_ch2;    /* Voltaje canal 2 en mV */
    uint16_t raw_ch0;        /* Valor crudo canal 0 */
    uint16_t raw_ch1;        /* Valor crudo canal 1 */
    uint16_t raw_ch2;        /* Valor crudo canal 2 */
    float    temperature;    /* Temperatura interna en °C */
    uint32_t timestamp;      /* Milisegundos desde boot */
};

/**
 * Inicializa el hardware ADC del RP2040.
 *
 * Funciones realizadas:
 *   1. Resetea el bloque ADC y espera que este listo
 *   2. Configura los GPIO 26, 27 y 28 como entradas analogicas
 *      (desabilita funciones digitales, pulls y receptor digital)
 *   3. Habilita el sensor de temperatura interno
 *
 * Debe llamarse una sola vez al inicio, antes de cualquier lectura.
 * Usa las funciones del SDK: adc_init(), adc_gpio_init(),
 * adc_set_temp_sensor_enabled().
 */
void adc_reader_init(void);

/**
 * Realiza una lectura completa de todos los canales ADC disponibles.
 *
 * Proceso:
 *   1. Para cada canal (0, 1, 2):
 *      a. Selecciona el canal con adc_select_input()
 *      b. Realiza ADC_OVERSAMPLE_COUNT lecturas consecutivas
 *      c. Calcula el promedio para reducir ruido
 *      d. Convierte el valor crudo a milivoltios: V = (raw / 4095) * 3300
 *   2. Lee el sensor de temperatura interno (canal 4):
 *      a. Formula: T = 27 - (V_adc - 706) / 1.721
 *   3. Registra la marca de tiempo actual
 *
 * @param reading Puntero a estructura AdcReading donde se almacenan los
 *                resultados. Debe estar previamente allocada.
 *
 * NOTA: Esta funcion es bloqueante durante la lectura. El tiempo total
 * depende de ADC_OVERSAMPLE_COUNT y la velocidad del ADC (~500 kS/s).
 * Con 16 muestras por canal, toma ~0.1 ms por canal.
 */
void adc_reader_read(AdcReading *reading);

/**
 * Retorna el voltaje de referencia del ADC en milivoltios.
 * En la Pico W este valor es 3300 mV (3.3V).
 *
 * @return Voltaje de referencia en mV
 */
float adc_reader_get_vref(void);

/**
 * Convierte un valor crudo del ADC (0-4095) a milivoltios.
 * Util para conversiones manuales o calibracion.
 *
 * @param raw_value Valor crudo del ADC (0-4095)
 * @return Voltaje en milivoltios (0 - 3300 mV)
 */
float adc_reader_raw_to_millivolts(uint16_t raw_value);

#endif /* ADC_READER_H */
