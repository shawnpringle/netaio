include revisions.GNUmake
include site.GNUmake

install_AIO2.tgz : dependencies.txt README.md install.ex install GNUmakefile revisions.GNUmake revisions.e
	tar -czf install_AIO2.tgz install dependencies.txt README.md install.ex GNUmakefile revisions.GNUmake revisions.e

install : revisions.e install.ex
	euc install.ex
	strip install
	
eudoc40tip.tar : $(wildcard $(EU40DEV)/build/html/*) $(wildcard $(EU40DEV)/build/html/js/*)  $(wildcard $(EU40DEV)/build/html/images/*)
	cd $(EU40DEV)/source;\
	tar -cf $(PWD)/eudoc40tip.tar build/html


	
eubin : eudoc40tip.tar
	
.DELETE_ON_ERROR : eubin

.ONESHELL : eubin eudoc40tip.tar

revisions.e : revisions.GNUmake GNUmakefile
	echo 'public constant eu41revision = "'$(EU41REV)'"' | tee revisions.e

.PHONY : eubin