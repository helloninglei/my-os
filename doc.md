### 依赖包安装

- 安装汇编器
`brew install nasm`

- truncate函数
`brew install truncate`

- 硬件模拟工具
`brew install qemu`

- mkfs.fat所需依赖库
  - HomeBrew安装：
`brew install dosfstools`
  - 手动安装：
    ```
    git clone https://github.com/dosfstools/dosfstools
    cd ./dosfstools
    bash ./autogen.sh
    bash ./configure
    make && make install
    ```
- mcopy 所需依赖库
`brew install mtools`

- 安装bochs模拟工具
`brew install bochs`

- 其他工具
需要安装的工具有：x86_64-elf-gcc、i386-elf-gdb、cmake，安装方式如下：
`brew install x86_64-elf-gcc`
`brew install x86_64-elf-gdb`
`brew install cmake`

### 启动命令

- 运行镜像
`make && qemu-system-i386 -fda build/main_floppy.img`


- 调试
`bash debug.sh`


### 参考资料

- cpu 寄存器 x86
https://wiki.osdev.org/CPU_Registers_x86
https://nieyong.github.io/wiki_cpu/CPU%E4%BD%93%E7%B3%BB%E6%9E%B6%E6%9E%84-%E5%AF%84%E5%AD%98%E5%99%A8.html

- cpu 指令集 x86
https://en.wikipedia.org/wiki/X86_instruction_listings
https://www.felixcloutier.com/x86/
