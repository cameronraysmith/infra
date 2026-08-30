#include <err.h>
#include <fcntl.h>
#include <linux/kvm.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <unistd.h>
int main(void){
  const uint8_t code[]={0xba,0xf8,0x03, 0x00,0xd8, 0x04,'0', 0xee, 0xb0,'\n', 0xee, 0xf4};
  int kvm=open("/dev/kvm",O_RDWR|O_CLOEXEC); if(kvm<0) err(1,"open /dev/kvm");
  int v=ioctl(kvm,KVM_GET_API_VERSION,0); if(v!=12) errx(1,"KVM_GET_API_VERSION=%d (want 12)",v);
  int vm=ioctl(kvm,KVM_CREATE_VM,0UL); if(vm<0) err(1,"KVM_CREATE_VM");
  uint8_t*mem=mmap(NULL,0x1000,PROT_READ|PROT_WRITE,MAP_SHARED|MAP_ANONYMOUS,-1,0); if(mem==MAP_FAILED) err(1,"mmap");
  memcpy(mem,code,sizeof code);
  struct kvm_userspace_memory_region r={.slot=0,.guest_phys_addr=0x1000,.memory_size=0x1000,.userspace_addr=(uint64_t)mem};
  if(ioctl(vm,KVM_SET_USER_MEMORY_REGION,&r)<0) err(1,"KVM_SET_USER_MEMORY_REGION");
  int cpu=ioctl(vm,KVM_CREATE_VCPU,0UL); if(cpu<0) err(1,"KVM_CREATE_VCPU");
  int sz=ioctl(kvm,KVM_GET_VCPU_MMAP_SIZE,0); if(sz<0) err(1,"KVM_GET_VCPU_MMAP_SIZE");
  struct kvm_run*run=mmap(NULL,sz,PROT_READ|PROT_WRITE,MAP_SHARED,cpu,0); if(run==MAP_FAILED) err(1,"mmap run");
  struct kvm_sregs s; if(ioctl(cpu,KVM_GET_SREGS,&s)<0) err(1,"KVM_GET_SREGS");
  s.cs.base=0; s.cs.selector=0; if(ioctl(cpu,KVM_SET_SREGS,&s)<0) err(1,"KVM_SET_SREGS");
  struct kvm_regs g={.rip=0x1000,.rax=2,.rbx=2,.rflags=2}; if(ioctl(cpu,KVM_SET_REGS,&g)<0) err(1,"KVM_SET_REGS");
  for(;;){
    if(ioctl(cpu,KVM_RUN,0)<0) err(1,"KVM_RUN");
    switch(run->exit_reason){
      case KVM_EXIT_HLT: puts("KVM_EXIT_HLT -> KVM VM ENTRY/EXIT WORKS"); return 0;
      case KVM_EXIT_IO: if(run->io.direction==KVM_EXIT_IO_OUT&&run->io.size==1&&run->io.port==0x3f8) { putchar(*((char*)run+run->io.data_offset)); fflush(stdout); break; }
                        errx(1,"unhandled IO exit");
      case KVM_EXIT_FAIL_ENTRY: errx(1,"KVM_EXIT_FAIL_ENTRY reason=0x%llx",(unsigned long long)run->fail_entry.hardware_entry_failure_reason);
      case KVM_EXIT_INTERNAL_ERROR: errx(1,"KVM_EXIT_INTERNAL_ERROR suberror=0x%x",run->internal.suberror);
      default: errx(1,"unexpected exit_reason=0x%x",run->exit_reason);
    }
  }
}
