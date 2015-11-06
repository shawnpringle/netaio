EU40DEV=/home/shawn/development/modified/euphoria-4.0
EU41DEV=/home/shawn/development/modified/euphoria-4.1

install_AIO2.tgz : dependencies.txt README.md install_AIO2.ex euphoria-721157c2f5ef.tar makearchive.ex install_AIO2 GNUmakefile     
	tar -czf install_AIO2.tgz install_AIO2 dependencies.txt README.md install_AIO2.ex euphoria-721157c2f5ef.tar makearchive.ex GNUmakefile           

install_AIO2 : install_AIO2.ex
	eubind install_AIO2.ex
	
euphoria-721157c2f5ef.tar : makearchive.ex
	eui40tip makearchive.ex $EU40DEV

euphoria-59291b05e3bf.tar : makearchive.ex ../euphoria-4.1 eubin-2015-10-25-16462e686646+.tgz
	tar xzf eubin-2015-10-25-16462e686646+.tgz -C ../euphoria-4.1/source
	touch ../euphoria-4.1/source/build/*
	eui40tip makearchive.ex $EU41DEV
	
eubin-2015-10-25-16462e686646+.tgz :
	wget http://openeuphoria.org/eubins/linux/4.1.0/32-bit/eubin-2015-10-25-16462e686646+.tgz

docs/wxide.html : wxide-0.8.0-linux-x86.tgz 
	tar -xzf wxide-0.8.0-linux-x86.tgz  -C /tmp
	cp /tmp/./wxide-0.8.0-linux-x86/docs/wxide.html docs/wxide.html
	
