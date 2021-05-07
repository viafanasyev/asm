dd if=/dev/zero of=floppy.img bs=512 count=2880
dd if=$1 count=1 of=floppy.img conv=notrunc                  # Copy bootloader from program 1
dd if=$2 skip=1 count=2878 of=floppy.img seek=1 conv=notrunc # Copy all except bootloader from program 2
dd if=$2 count=1 of=floppy.img seek=2878 conv=notrunc        # Copy bootloader from program 2
dd if=$1 skip=1 count=1 of=floppy.img seek=2879 conv=notrunc # Copy second sector from program 1
qemu-system-x86_64 -drive format=raw,index=0,if=floppy,file=floppy.img -s -S & gdb -x bootloader-gdb-config.txt
rm floppy.img
