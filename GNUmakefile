include revisions.GNUmake
EU40DEV=/home/shawn/development/modified/euphoria-4.0
EU41DEV=/home/shawn/development/modified/euphoria-4.1

install_AIO2.tgz : dependencies.txt README.md install_AIO2.ex euphoria-$(EU40REV).tar makearchive.ex install_AIO2 GNUmakefile revisions.GNUmake revisions.e
	tar -czf install_AIO2.tgz install_AIO2 dependencies.txt README.md install_AIO2.ex euphoria-$(EU40REV).tar makearchive.ex GNUmakefile revisions.GNUmake revisions.e

install_AIO2 : revisions.e install_AIO2.ex
	eubind install_AIO2.ex
	
euphoria-$(EU40REV).tar : makearchive.ex $(EU40DEV)
	eui40tip makearchive.ex $(EU40DEV)

euphoria-$(EU41REV).tar : makearchive.ex $(EU41DEV)
	eui40tip makearchive.ex $(EU41DEV)
	
revisions.e : revisions.GNUmake GNUmakefile istip.ex
	echo 'public constant eu40revision = "'$(EU40REV)'", eu41revision = "'$(EU41REV)'"' | tee revisions.e
	echo 'public constant eu40revision_is_tip = ' `eui -i /usr/local/share/euphoria-common/include istip.ex $(EU40DEV) 4.0 $(EU40REV)` >> revisions.e

