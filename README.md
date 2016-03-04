#All-in-One Linux OpenEuphoria Installer#

The installer installs dependencies for Euphoria and its GUI wrappers.  It installs OpenEuphoria 4.0.6 development and 4.1.0 development binaries with EuGTK and wxEuphoria wrappers

##Euphoria binaries##

Euphoria binaries include an interpreter for running the source; a translator which converts the Euphoria code into C;
a binder which creates a binary quickly from sources; and a unit tester and coverage utility 

##Euphoria 4.0##

Euphoria 4.0.6 is the stable branch and the bugs that are present in this code base has to do with failure to issue warnings to the user for code that looks wrong but might be right.  You can run the interpreter with 'eui40' and its translator 'euc40'.  The translator translates to C, and then calls the C compiler to compile the c code into an executable.

##Euphoria 4.1##

Euphoria 4.1.0 is the experimental branch and the bugs that are present in this code base include the defects in Euphoria 4.0 and incorrect behavior.  You can run the interpreter with 'eui41' and its translator 'euc41'.  The translator translates to C, and then calls the C compiler to compile the c code into an executable. 

##Using the Installer##

If do not have a Euphoria Interpreter of version 4.0 or greater, download this installer from
http://www.rapideuphoria.com/install_aio2.tgz.  That archive will include a translated 
copy of install.ex.

The installer is to be run as root on Debian-based systems (compiled on Linux Mint 17.0 32-bit).

Usage: `install` \[`-0`\] \[`-1`\] \[`-4`\] \[`-8`\] \[`-n`\] \[`-p/usr/bin`\]

If no target directory is specified, OpenEuphoria will be installed in /usr/local/euphoria-4.1.0.

- \-0 Installs with Euphoria 4.0 as default
- \-1 Installs with Euphoria 4.1 as default
- \-4 Installs 32-bit binaries
- \-8 Istallas 64-bt binaries
- \-n Installs to /tmp/test-install rather than /usr/local and lets you run as non-root
- \-p Allows you to specify where you wish to install.

###The \-p switch###

It is recommended by various standards to install programs into /usr/local.  Binaries go into /usr/local/bin and other files into /usr/local/share/ under sub directories.  This is the default.  If you use /usr/local or /usr/ you wont have to manually change your PATH variable.  If you don't have root access, you can combine \-n and \-p to install to your home directory.  If your username is user that might be, \-np/home/user/euphoria.

