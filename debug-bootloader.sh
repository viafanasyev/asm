dd if=/dev/zero of=floppy.img bs=512 count=2880
dd if=$1 of=floppy.img conv=notrunc
qemu-system-x86_64 -drive format=raw,index=0,if=floppy,file=floppy.img -s -S & gdb -x bootloader-gdb-config.txt
rm floppy.img
