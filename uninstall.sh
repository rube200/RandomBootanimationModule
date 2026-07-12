#!/system/bin/sh

for dest in \
  /product/media/bootanimation.zip \
  /system/media/bootanimation.zip \
  /system/product/media/bootanimation.zip
do
  umount -l "$dest" 2>/dev/null
done
rm -f /data/adb/bootanimations/.active/bootanimation.zip
exit 0
