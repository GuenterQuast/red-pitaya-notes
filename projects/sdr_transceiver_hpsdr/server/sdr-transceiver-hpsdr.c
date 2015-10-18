#include <stdio.h>
#include <errno.h>
#include <stdlib.h>
#include <limits.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <math.h>
#include <poll.h>
#include <pthread.h>
#include <sys/mman.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

uint32_t *rx_freq[2], *rx_rate[2], *tx_freq;
uint16_t *gpio, *rx_cntr[2], *tx_cntr;
void *rx_data[2], *tx_data;

const uint32_t freq_min = 0;
const uint32_t freq_max = 61440000;

int receivers = 1;

int sock_ep2;
struct sockaddr_in addr_ep6;
socklen_t size_ep6;

int enable_thread = 0;
int active_thread = 0;

void process_ep2(char *frame);
void *handler_ep6(void *arg);

int main(int argc, char *argv[])
{
  int fd;
  pthread_t thread;
  void *cfg[2], *sts[2];
  char *name = "/dev/mem";
  char buffer[1032];
  uint8_t reply[11] = {0xef, 0xfe, 2, 0, 0, 0, 0, 0, 0, 18, 0};
  struct sockaddr_in addr_ep2;
  ssize_t result;
  int yes = 1;

  if((fd = open(name, O_RDWR)) < 0)
  {
    perror("open");
    return EXIT_FAILURE;
  }

  cfg[0] = mmap(NULL, sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0x40000000);
  sts[0] = mmap(NULL, sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0x40001000);
  rx_data[0] = mmap(NULL, 2*sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0x40002000);
  tx_data = mmap(NULL, 2*sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0x40004000);
  cfg[1] = mmap(NULL, sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0x40006000);
  sts[1] = mmap(NULL, sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0x40007000);
  rx_data[1] = mmap(NULL, 2*sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0x40008000);

  gpio = ((uint16_t *)(cfg + 0));

  rx_freq[0] = ((uint32_t *)(cfg[0] + 4));
  rx_rate[0] = ((uint32_t *)(cfg[0] + 8));
  rx_cntr[0] = ((uint16_t *)(sts[0] + 0));

  tx_freq = ((uint32_t *)(cfg[0] + 12));
  tx_cntr = ((uint16_t *)(sts[0] + 2));

  rx_freq[1] = ((uint32_t *)(cfg[1] + 0));
  rx_rate[1] = ((uint32_t *)(cfg[1] + 4));
  rx_cntr[1] = ((uint16_t *)(sts[1] + 0));

  /* set PTT pin to low */
  *gpio = 0;

  /* set default rx phase increment */
  *rx_freq[0] = (uint32_t)floor(600000/125.0e6*(1<<30)+0.5);
  *rx_freq[1] = (uint32_t)floor(600000/125.0e6*(1<<30)+0.5);
  /* set default rx sample rate */
  *rx_rate[0] = 1000;
  *rx_rate[1] = 1000;

  /* set default tx phase increment */
  *tx_freq = (uint32_t)floor(600000/125.0e6*(1<<30)+0.5);

  if((sock_ep2 = socket(AF_INET, SOCK_DGRAM, 0)) < 0)
  {
    perror("socket");
    return EXIT_FAILURE;
  }

  setsockopt(sock_ep2, SOL_SOCKET, SO_REUSEADDR, (void *)&yes , sizeof(yes));

  memset(&addr_ep2, 0, sizeof(addr_ep2));
  addr_ep2.sin_family = AF_INET;
  addr_ep2.sin_addr.s_addr = htonl(INADDR_ANY);
  addr_ep2.sin_port = htons(1024);

  if(bind(sock_ep2, (struct sockaddr *)&addr_ep2, sizeof(addr_ep2)) < 0)
  {
    perror("bind");
    return EXIT_FAILURE;
  }

  while(1)
  {
    result = recvfrom(sock_ep2, buffer, 1032, 0, (struct sockaddr *)&addr_ep6, &size_ep6);
    if(result <= 0) break;

    printf("read %08x\n", *(uint32_t *)buffer);

    switch(*(uint32_t *)buffer)
    {
      case 0x0201feef:
        process_ep2(buffer + 11);
        process_ep2(buffer + 523);
        break;
      case 0x0002feef:
        reply[2] = 2 + active_thread;
        memset(buffer, 0, 60);
        memcpy(buffer, reply, 11);
        sendto(sock_ep2, buffer, 60, 0, (struct sockaddr *)&addr_ep6, size_ep6);
        break;
      case 0x0004feef:
        enable_thread = 0;
        while(active_thread)
        {
          usleep(1000);
        }
        break;
      case 0x0104feef:
      case 0x0204feef:
      case 0x0304feef:
        if(!active_thread)
        {
          enable_thread = 1;
          active_thread = 1;
          if(pthread_create(&thread, NULL, handler_ep6, NULL) < 0)
          {
            perror("pthread_create");
            return EXIT_FAILURE;
          }
          pthread_detach(thread);
        }
        break;
    }
  }

  close(sock_ep2);

  return EXIT_SUCCESS;
}

void process_ep2(char *frame)
{
  uint32_t freq;
  printf("frame %02x %02x %02x %02x %02x\n", (uint8_t)frame[0], (uint8_t)frame[1], (uint8_t)frame[2], (uint8_t)frame[3], (uint8_t)frame[4]);
  switch(frame[0])
  {
    case 0:
    case 1:
      receivers = ((frame[4] >> 3) & 7) + 1;
      /* set PTT pin */
      *gpio = frame[0] & 1;
      /* set rx sample rate */
      switch(frame[1] & 3)
      {
        case 0:
          *rx_rate[0] = 1000;
          *rx_rate[1] = 1000;
          break;
        case 1:
          *rx_rate[0] = 500;
          *rx_rate[1] = 500;
          break;
        case 2:
          *rx_rate[0] = 250;
          *rx_rate[1] = 250;
          break;
        case 3:
          *rx_rate[0] = 125;
          *rx_rate[1] = 125;
          break;
      }
      break;
    case 2:
    case 3:
      /* set tx phase increment */
      freq = ntohl(*(uint32_t *)(frame + 1));
      printf("%d\n", freq);
      if(freq < freq_min || freq > freq_max) break;
      *tx_freq = (uint32_t)floor(freq/125.0e6*(1<<30)+0.5);
      break;
    case 4:
    case 5:
      /* set rx phase increment */
      freq = ntohl(*(uint32_t *)(frame + 1));
      printf("%d\n", freq);
      if(freq < freq_min || freq > freq_max) break;
      *rx_freq[0] = (uint32_t)floor(freq/125.0e6*(1<<30)+0.5);
      break;
    case 6:
    case 7:
      /* set rx phase increment */
      freq = ntohl(*(uint32_t *)(frame + 1));
      printf("%d\n", freq);
      if(freq < freq_min || freq > freq_max) break;
      *rx_freq[1] = (uint32_t)floor(freq/125.0e6*(1<<30)+0.5);
      break;
  }
}

void *handler_ep6(void *arg)
{
  int i, size, rx_position, rx_limit, rx_offset;
  int data_offset, header_offset, buffer_offset, frame_offset;
  uint32_t counter;
  char data0[4096];
  char data1[4096];
  char buffer[1032];
  uint8_t header[40] =
  {
    127, 127, 127, 0, 0, 32, 0, 18,
    127, 127, 127, 8, 0, 0, 0, 0,
    127, 127, 127, 16, 0, 0, 0, 0,
    127, 127, 127, 24, 0, 0, 0, 0,
    127, 127, 127, 32, 64, 64, 64, 64
  };

  counter = 0;
  rx_limit = 512;
  header_offset = 0;
  buffer_offset = 16;
  frame_offset = 0;
  size = receivers * 6 + 2;

  memset(buffer, 0, 1032);
  *(uint32_t *)(buffer + 0) = 0x0601feef;

  while(1)
  {
    if(!enable_thread) break;

    /* read ram writer position */
    rx_position = *rx_cntr[0];

    /* read 4096 bytes if ready, otherwise sleep */
    if((rx_limit > 0 && rx_position > rx_limit) || (rx_limit == 0 && rx_position < 512))
    {
      rx_offset = rx_limit > 0 ? 0 : 4096;
      rx_limit = rx_limit > 0 ? 0 : 512;
      memcpy(data0, rx_data[0] + rx_offset, 4096);
      memcpy(data1, rx_data[1] + rx_offset, 4096);

      data_offset = 0;

      for(i = 0; i < 512; ++i)
      {
        memcpy(buffer + buffer_offset + frame_offset, data0 + data_offset, 6);
        if(size >= 12)
        {
          memcpy(buffer + buffer_offset + frame_offset + 6, data1 + data_offset, 6);
        }
        data_offset += 8;
        frame_offset += size;
        if(frame_offset + size > 504)
        {
          frame_offset = 0;

          if(buffer_offset == 16)
          {
            buffer_offset = 528;
          }
          else
          {
            *(uint32_t *)(buffer + 4) = htonl(counter);
            memcpy(buffer + 8, header + header_offset, 8);
            header_offset = header_offset >= 32 ? 0 : header_offset + 8;
            memcpy(buffer + 520, header + header_offset, 8);
            header_offset = header_offset >= 32 ? 0 : header_offset + 8;
            sendto(sock_ep2, buffer, 1032, 0, (struct sockaddr *)&addr_ep6, size_ep6);
            buffer_offset = 16;
            size = receivers * 6 + 2;
            memset(buffer + 8, 0, 1024);
            ++counter;
          }
        }
      }
    }
    else
    {
      usleep(*rx_rate[0] * 2);
    }
  }

  active_thread = 0;

  return NULL;
}
