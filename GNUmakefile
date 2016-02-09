include revisions.GNUmake
EU40DEV=/home/shawn/development/modified/euphoria-4.0
EU41DEV=/home/shawn/development/modified/euphoria-4.1

install_AIO2.tgz : dependencies.txt README.md install.ex makearchive.ex install GNUmakefile revisions.GNUmake revisions.e
	tar -czf install_AIO2.tgz install dependencies.txt README.md install.ex makearchive.ex GNUmakefile revisions.GNUmake revisions.e

install : revisions.e install.ex
	euc install.ex
	strip install
	
revisions.e : revisions.GNUmake GNUmakefile
	echo 'public constant eu40revision = "'$(EU40REV)'", eu41revision = "'$(EU41REV)'"' | tee revisions.e
	echo 'public constant eu40revision_is_tip = 1' >> revisions.e

