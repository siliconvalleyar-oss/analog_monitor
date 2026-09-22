/**
 * =============================================================================
 * adc_reader.cpp - Implementacion del modulo de lectura ADC
 * =============================================================================
 *
 * Este archivo implementa las funciones declaradas en adc_reader.h.
 * Usa las primitivas del SDK de Pico (hardware/adc.h) para interactuar
 * con el modulo ADC del RP2040.
 *
 * REFERENCIAS:
 *   - RP2040 Datasheet, Chapter 4: ADC
 *   - Pico SDK: hardware_adc library
 *   - pico-sdk/src/rp2_common/hardware_adc/adc.c
 * =============================================================================
 */

#include "adc_reader.h"
#include "wifi_config.h"

/* SDK de Pico: driver del ADC y utilidades generales */
#include "hardware/adc.h"
#include "pico/stdlib.h"

/* ===========================================================================
 * Constantes de conversion del ADC
 * =========================================================================== */

/**
 * Voltaje de referencia del ADC en milivoltios.
 * La Pico W usa 3.3V como referencia. Este valor puede variar
 * ligeramente entre placas (3.2V a 3.4V). Para mayor precision,
 * se puede calibrar midiendo el voltaje real en un pin conocido.
 */
static const float ADC_VREF_MV = 3300.0f;

/**
 * Resolucion del ADC en cuentas.
 * El RP2040 tiene un ADC de 12 bits: 2^12 = 4096 niveles.
 */
static const float ADC_RESOLUTION = 4095.0f;

/**
 * Constantes para la conversion de temperatura del sensor interno.
 * Extraidas del datasheet del RP2040 (Section 4.9.5):
 *   T = 27 - (ADC_Voltage - 0.706) / 0.001721
 * Donde ADC_Voltage esta en伏特 (no mV).
 */
static const float TEMP_OFFSET     = 27.0f;    /* Temperatura base en °C */
static const float TEMP_VOLTAGE_0  = 0.706f;   /* Voltaje a 27°C en V */
static const float TEMP_COEFF      = 0.001721f; /* Coeficiente de temperatura V/°C */

/**
 * Cantidad total de canales ADC disponibles para el usuario en Pico W.
 * GPIO 26 (CH0), GPIO 27 (CH1), GPIO 28 (CH2).
 * GPIO 29 (CH3) esta reservado para CYW43 WiFi.
 */
static const uint NUM_USER_CHANNELS = 3;

/* ===========================================================================
 * Funciones publicas (ver adc_reader.h para documentacion completa)
 * =========================================================================== */

void adc_reader_init(void) {
    /* Inicializa el bloque ADC del RP2040.
     * Esta funcion:
     *   1. Resetea el periferico ADC (reset_unreset_block)
     *   2. Habilita el ADC (setea bit ADC_CS_EN)
     *   3. Espera a que el ADC este listo (bit ADC_CS_READY)
     */
    adc_init();

    /* Configura los GPIO 26, 27 y 28 como entradas analogicas.
     * Para cada pin, adc_gpio_init():
     *   1. Establece la funcion GPIO_FUNC_NULL (desactiva salida digital)
     *   2. Deshabilita pulls internos (pull-up/down)
     *   3. Deshabilita el receptor digital del pin
     *
     * Esto es necesario porque los mismos pines comparten funciones
     * digitales y analogicas. Para usar ADC, la parte digital debe
     * estar completamente desactivada.
     */
    adc_gpio_init(26);  /* Canal 0 - GPIO 26 */
    adc_gpio_init(27);  /* Canal 1 - GPIO 27 */
    adc_gpio_init(28);  /* Canal 2 - GPIO 28 */

    /* Habilita el sensor de temperatura interno del RP2040.
     * Este sensor esta conectado al canal 4 del ADC.
     * La formula de conversion es:
     *   T(°C) = 27 - (V_adc - 0.706) / 0.001721
     *
     * Nota: El sensor tiene una precision de ±2°C y es util solo
     * para monitoreo de temperatura del chip, no para medicion externa.
     */
    adc_set_temp_sensor_enabled(true);
}

void adc_reader_read(AdcReading *reading) {
    if (!reading) return;

    /* Array con los numeros de canal ADC correspondientes a cada GPIO.
     * Canal 0 = GPIO 26, Canal 1 = GPIO 27, Canal 2 = GPIO 28.
     * Nota: No confundir con el numero de GPIO. El canal ADC es
     * independiente del numero de GPIO (en este caso coinciden parcialmente).
     */
    static const uint channels[NUM_USER_CHANNELS] = {0, 1, 2};

    uint32_t raw_sums[NUM_USER_CHANNELS] = {0, 0, 0};

    /* ------------------------------------------------------------------
     * Fase 1: Muestreo con oversampling
     * ------------------------------------------------------------------
     * Para cada una de las N muestras (definidas por ADC_OVERSAMPLE_COUNT):
     *   1. Iteramos sobre los 3 canales disponibles
     *   2. Seleccionamos el canal con adc_select_input()
     *   3. Disparamos una conversion con adc_read() (bloqueante)
     *   4. Acumulamos el resultado para promediar despues
     *
     * El oversampling reduce el ruido aleatorio. Con N muestras,
     * el ruido se reduce por un factor de sqrt(N).
     * Ejemplo: 16 muestras reducen el ruido ~4x.
     * ------------------------------------------------------------------ */
    for (uint sample = 0; sample < ADC_OVERSAMPLE_COUNT; sample++) {
        for (uint ch = 0; ch < NUM_USER_CHANNELS; ch++) {
            /* Selecciona el canal ADC (0, 1, o 2) */
            adc_select_input(channels[ch]);

            /* Realiza una conversion y retorna el resultado de 12 bits.
             * Internamente:
             *   1. Setea el bit START_ONCE en el registro CS
             *   2. Espera a que el bit READY se active (~2 µs a 500 kS/s)
             *   3. Lee el resultado del registro RESULT (12 bits)
             */
            raw_sums[ch] += adc_read();
        }
    }

    /* ------------------------------------------------------------------
     * Fase 2: Calculo de promedios y conversion a milivoltios
     * ------------------------------------------------------------------
     * Promedia las N muestras y convierte a voltaje:
     *   voltage_mV = (raw_avg / 4095) * 3300
     *
     * Donde:
     *   raw_avg = suma / ADC_OVERSAMPLE_COUNT
     *   4095    = resolucion maxima del ADC (12 bits)
     *   3300    = voltaje de referencia en mV (3.3V)
     * ------------------------------------------------------------------ */
    float raw_avg_ch0 = (float)raw_sums[0] / (float)ADC_OVERSAMPLE_COUNT;
    float raw_avg_ch1 = (float)raw_sums[1] / (float)ADC_OVERSAMPLE_COUNT;
    float raw_avg_ch2 = (float)raw_sums[2] / (float)ADC_OVERSAMPLE_COUNT;

    reading->raw_ch0 = (uint16_t)(raw_avg_ch0 + 0.5f);  /* Redondeo */
    reading->raw_ch1 = (uint16_t)(raw_avg_ch1 + 0.5f);
    reading->raw_ch2 = (uint16_t)(raw_avg_ch2 + 0.5f);

    reading->voltage_ch0 = (raw_avg_ch0 / ADC_RESOLUTION) * ADC_VREF_MV;
    reading->voltage_ch1 = (raw_avg_ch1 / ADC_RESOLUTION) * ADC_VREF_MV;
    reading->voltage_ch2 = (raw_avg_ch2 / ADC_RESOLUTION) * ADC_VREF_MV;

    /* ------------------------------------------------------------------
     * Fase 3: Lectura del sensor de temperatura interno
     * ------------------------------------------------------------------
     * El sensor de temperatura esta en el canal 4 del ADC.
     * La lectura se convierte a voltaje y luego a temperatura usando
     * la formula del datasheet del RP2040:
     *
     *   T(°C) = 27 - (V_adc - 0.706) / 0.001721
     *
     * Precision: ±2°C (suficiente para monitoreo de temperatura del chip)
     * ------------------------------------------------------------------ */
    adc_select_input(4);  /* Canal 4 = sensor de temperatura interno */
    uint16_t temp_raw = adc_read();
    float temp_voltage_v = ((float)temp_raw / ADC_RESOLUTION) * 3.3f;  /* En伏特 */
    reading->temperature = TEMP_OFFSET - (temp_voltage_v - TEMP_VOLTAGE_0) / TEMP_COEFF;

    /* ------------------------------------------------------------------
     * Fase 4: Marca de tiempo
     * ------------------------------------------------------------------
     * time_us_64() retorna microsegundos desde el arranque del RP2040.
     * Dividimos entre 1000 para obtener milisegundos.
     * El valor es de 32 bits, suficiente para ~49.7 dias de uptime.
     * ------------------------------------------------------------------ */
    reading->timestamp = (uint32_t)(time_us_64() / 1000ULL);
}

float adc_reader_get_vref(void) {
    return ADC_VREF_MV;
}

float adc_reader_raw_to_millivolts(uint16_t raw_value) {
    return ((float)raw_value / ADC_RESOLUTION) * ADC_VREF_MV;
}
