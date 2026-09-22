/**
 * =============================================================================
 * lwipopts.h - Opciones de lwIP para el firmware Analog Pico Monitor
 * =============================================================================
 *
 * Configurado para NO_SYS (RAW API, sin threads) usado con
 * pico_cyw43_arch_lwip_poll: la pila TCP/IP se procesa en el loop principal
 * mediante cyw43_arch_poll().
 *
 * Caracteristicas habilitadas:
 *   - TCP + UDP (UDP lo usa el cliente SNTP para la hora)
 *   - DHCP (obtener IP automaticamente) y DNS (resolver hostname del NTP)
 *   - ARP/ICMP/RAW para operacion LAN normal
 *   - HTTP con un maximo de HTTP_MAX_CLIENTS conexiones simultaneas
 * =============================================================================
 */

#ifndef _LWIPOPTS_H
#define _LWIPOPTS_H

// Sin sistema operativo: lwIP se usa en modo RAW (sin threads, sin sockets)
#define NO_SYS                       1
#define LWIP_SOCKET                  0
#define LWIP_NETCONN                 0

// En modo poll la memoria se pide con malloc del libc (limita la RAM usada
// por lwIP al minimo necesario)
//#define MEM_LIBC_MALLOC             1
#define MEM_ALIGNMENT                4

// Buffers de red
#define MEMP_NUM_TCP_SEG             32
#define MEMP_NUM_ARP_QUEUE           10
#define PBUF_POOL_SIZE               24
#define TCP_WND                      (8 * TCP_MSS)
#define TCP_MSS                      1460
#define TCP_SND_BUF                  (8 * TCP_MSS)
#define TCP_SND_QUEUELEN             ((4 * (TCP_SND_BUF) + (TCP_MSS - 1)) / (TCP_MSS))

// Conexiones TCP simultaneas (HTTP_MAX_CLIENTS en http_server.h)
#define MEMP_NUM_TCP_PCB             12

// Slots de timers. LWIP_NUM_SYS_TIMEOUT_INTERNAL no puede usarse aqui porque
// aun no esta definida cuando se incluye este archivo (opt.h). Valor seguro:
// TCP(1) + ARP(1) + DHCP(2) + DNS(1) + SNTP(1) + margen = 8
#define MEMP_NUM_SYS_TIMEOUT         8

// Protocolos
#define LWIP_ARP                     1
#define LWIP_ETHERNET                1
#define LWIP_ICMP                    1
#define LWIP_RAW                     1
#define LWIP_IPV4                    1
#define LWIP_TCP                     1
#define LWIP_UDP                     1
#define LWIP_DHCP                    1
#define LWIP_DNS                     1
#define LWIP_TCP_KEEPALIVE           1
#define LWIP_NETIF_TX_SINGLE_PBUF    1
#define DHCP_DOES_ARP_CHECK          0
#define LWIP_DHCP_DOES_ACD_CHECK     0

// Callbacks e identificacion del host
#define LWIP_NETIF_STATUS_CALLBACK   1
#define LWIP_NETIF_LINK_CALLBACK     1
#define LWIP_NETIF_HOSTNAME          1

// SNTP: permitir configurar el servidor por hostname
#define SNTP_SERVER_DNS              1

// SNTP: capturar el epoch UTC que recibe el cliente NTP y guardarlo en
// sntp_store_system_time() (implementada en http_server.cpp). Sin este
// callback el cliente SNTP no notifica a nadie de la hora recibida.
#define SNTP_SET_SYSTEM_TIME(sec)     sntp_store_system_time((sec))

// Declaracion de la funcion que guarda el epoch (se usa desde sntp.c, que es
// C puro, y desde los modulos C++ del firmware)
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
void sntp_store_system_time(uint32_t sec);
#ifdef __cplusplus
}
#endif

// Estadisticas desactivadas en release (familia de debug opcional)
#define MEM_STATS                    0
#define SYS_STATS                    0
#define MEMP_STATS                   0
#define LINK_STATS                   0
#define LWIP_CHKSUM_ALGORITHM        3

// Logs de depuracion apagados por defecto
#define LWIP_DEBUG                   0
#define LWIP_STATS                   0
#define LWIP_STATS_DISPLAY           0

#define ETHARP_DEBUG                 LWIP_DBG_OFF
#define NETIF_DEBUG                  LWIP_DBG_OFF
#define PBUF_DEBUG                   LWIP_DBG_OFF
#define TCP_DEBUG                    LWIP_DBG_OFF
#define TCP_INPUT_DEBUG              LWIP_DBG_OFF
#define TCP_OUTPUT_DEBUG             LWIP_DBG_OFF
#define UDP_DEBUG                    LWIP_DBG_OFF
#define DHCP_DEBUG                   LWIP_DBG_OFF
#define MEM_DEBUG                    LWIP_DBG_OFF
#define MEMP_DEBUG                   LWIP_DBG_OFF

#endif /* _LWIPOPTS_H */