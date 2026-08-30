#include <stdio.h>
#include <string.h>
#include <cpuid.h>
int main(void){
  unsigned a,b,c,d; char sig[13]={0}; char vend[13]={0};
  __cpuid(0,a,b,c,d); memcpy(vend,&b,4); memcpy(vend+4,&d,4); memcpy(vend+8,&c,4);
  printf("cpu_vendor=\"%s\"\n",vend);
  __cpuid(1,a,b,c,d);
  printf("leaf1.ecx: hypervisor_bit=%u vmx=%u\n",(c>>31)&1,(c>>5)&1);
  __cpuid(0x80000001,a,b,c,d);
  printf("leaf80000001.ecx: svm=%u\n",(c>>2)&1);
  __cpuid(0x40000000,a,b,c,d); memcpy(sig,&b,4); memcpy(sig+4,&c,4); memcpy(sig+8,&d,4);
  printf("hv_max_leaf=0x%x hv_signature=\"%s\"\n",a,sig);
  return 0; }
