include revisions.GNUmake
include site.GNUmake

install_AIO2.tgz : dependencies.txt README.md install.ex aio.e install GNUmakefile revisions.GNUmake revisions.e makearchives.ex
	tar -czf install_AIO2.tgz install dependencies.txt README.md aio.e install.ex GNUmakefile revisions.GNUmake revisions.e makearchives.ex site-example.GNUmake

install : revisions.e install.ex
	euc install.ex
	strip install
	
eubin40tip-linux.tar eudoc40tip.tar : $(wildcard $(EU40DEV)/build/*) $(wildcard $(EU40DEV)/build/html/*) $(wildcard $(EU40DEV)/build/html/js/*)  $(wildcard $(EU40DEV)/build/html/images/*) | site.GNUmake
	eui makearchives.ex -d $(EU40DEV)
	
eubin40tip-linux.tar.xz : eubin40tip-linux.tar
	xz -9 eubin40tip-linux.tar

eudoc40tip.tar.xz : eudoc40tip.tar
	xz -9 eudoc40tip.tar

archives : eudoc40tip.tar.xz eubin40tip-linux.tar.xz
	
.DELETE_ON_ERROR : eubin

.ONESHELL : eubin eudoc40tip.tar

revisions.e : revisions.GNUmake
	echo 'public constant eu41revision = "'$(EU41REV)'"' | tee revisions.e

.PHONY : eubin
