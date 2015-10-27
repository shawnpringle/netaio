
install_AIO2.tgz : dependencies.txt README.md install_AIO2.ex euphoria-721157c2f5ef.tar makearchive.ex bin64/libwxeu.so.16 bin32/libwxeu.so.16 bin32/libwxeu.so.2.9.17 bin32/libwx_gtk2u-2.9.so.4 bin32/wxide.bin bin32/wxide install_AIO2 bin64/libwxeu.so.2.9.17 bin64/libwx_gtk2u-2.9.so.4  bin64/wxide.bin bin64/wxide
	tar -czf install_AIO2.tgz install_AIO2 dependencies.txt README.md install_AIO2.ex euphoria-721157c2f5ef.tar makearchive.ex bin64/libwxeu.so.16 bin32/libwxeu.so.16 bin32/libwxeu.so.2.9.17 bin32/libwx_gtk2u-2.9.so.4 bin32/wxide.bin bin32/wxide bin64/libwxeu.so.2.9.17 bin64/libwx_gtk2u-2.9.so.4  bin64/wxide.bin bin64/wxide

install_AIO2 : install_AIO2.ex
	euc40tip install_AIO2.ex
	
euphoria-721157c2f5ef.tar : makearchive.ex ../euphoria-4.0
	eui40tip makearchive.ex ../euphoria-4.0

euphoria-59291b05e3bf.tar : makearchive.ex ../euphoria-4.1 eubin-2015-10-25-16462e686646+.tgz
	tar xzf eubin-2015-10-25-16462e686646+.tgz -C ../euphoria-4.1/source
	touch ../euphoria-4.1/source/build/*
	eui40tip makearchive.ex ../euphoria-4.1
	
eubin-2015-10-25-16462e686646+.tgz :
	wget http://openeuphoria.org/eubins/linux/4.1.0/32-bit/eubin-2015-10-25-16462e686646+.tgz
	
bin32/libwxeu.so.16 : wxeu-bin-linux32-0-16-0.tar.gz
	tar -xzf wxeu-bin-linux32-0-16-0.tar.gz -C /tmp
	cp /tmp/wxEuphoria/bin/libwxeu.so.16 bin32/libwxeu.so.16
	rm -fr /tmp/wxEuphoria
	
bin64/libwxeu.so.16 : wxeu-bin-linux64-0-16-0.tar.gz
	tar -xzf wxeu-bin-linux64-0-16-0.tar.gz -C /tmp
	cp /tmp/wxEuphoria/bin/libwxeu.so.16 bin64/libwxeu.so.16
	rm -fr /tmp/wxEuphoria
	
bin32/libwxeu.so.2.9.17 bin32/libwx_gtk2u-2.9.so.4 bin32/wxide.bin bin32/wxide : wxide-0.8.0-linux-x86.tgz
	tar -xzf wxide-0.8.0-linux-x86.tgz -C /tmp
	cp /tmp/wxide-0.8.0-linux-x86/bin/wxide /tmp/wxide-0.8.0-linux-x86/bin/libwxeu.so.2.9.17 /tmp/wxide-0.8.0-linux-x86/bin/libwx_gtk2u-2.9.so.4 /tmp/wxide-0.8.0-linux-x86/bin/wxide.bin bin32

docs/wxide.html : wxide-0.8.0-linux-x86.tgz 
	tar -xzf wxide-0.8.0-linux-x86.tgz  -C /tmp
	cp /tmp/./wxide-0.8.0-linux-x86/docs/wxide.html docs/wxide.html
	
bin64/libwxeu.so.2.9.17 bin64/libwx_gtk2u-2.9.so.4  bin64/wxide.bin bin64/wxide : wxide-0.8.0-linux-x86-64.tgz
	tar -xzf wxide-0.8.0-linux-x86-64.tgz -C /tmp
	cp /tmp/wxide-0.8.0-linux-x86-64/bin/wxide /tmp/wxide-0.8.0-linux-x86-64/bin/libwxeu.so.2.9.17 /tmp/wxide-0.8.0-linux-x86-64/bin/libwx_gtk2u-2.9.so.4 /tmp/wxide-0.8.0-linux-x86-64/bin/wxide.bin bin64
	
