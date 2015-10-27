
install_AIO2.tgz : install_AIO2 dependencies.txt README.md install_AIO2.ex euphoria-721157c2f5ef.tar makearchive.ex
	tar -czf install_AIO2.tgz install_AIO2 dependencies.txt README.md install_AIO2.ex euphoria-721157c2f5ef.tar makearchive.ex

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
	
