All-in-One 32-bit Linux OpenEuphoria 4.1+4.0 archive with wxEuphoria/wxIDE

To install, download the archive from http://www.rapideuphoria.com/install_aio2.tgz.  Unpack the archive,
and type 'sudo ./install_AIO2'.

The installer is to be run as root on Debian-based systems (compiled on Linux Mint 17.0 32-bit).
 
Usage: sudo ./install_AIO2 [-n] [-4] [-8] [-p prefix]

The archive will install Open Euphoria 4.1 files to /usr/local/share/euphoria-4.1.0 and 
it will install Open Euphoria 4.0 files to /usr/local/share/euphoria-4.0-tip.  To avoid
duplication, files that are not part of the Open Euphoria project but are used with 
OpenEuphoria are installed in /usr/local/share/euphoria.

You will be prompted for whether your Linux is 32bit or 64bit unless you supply -4 or -8.  oThe
four is for four byte registers and the eight is for eight byte regiters.  The p option is to 
override the prefix.  

The -n is for testing.  As a side effect, the prefix is set to /tmp/test-install and the software
is installed there.  In this case you do not need sudoer's access and you can modify your PATH environment
variable to test things out before running as root.  The dependencies will not get installed automatically though.

Examples:t
'sudo ./install_AIO -8p/usr'
will install for a 64-bit system under the prefix /usr rather than /usr/local.

'./install_AIO -np/home/tom/progs'
will install under a user's home directory located at /home/tom/progs.  It will prompt for 32 or 64 bit.

Run 'eui' or 'eui41feb' to run the 4.1.0 version of the interpreter.  This version from February,
doesn't suffer from the bugs the recent revisions of 4.1.0 suffer from.  The translator in this version of 4.1.0 
does however suffer from a bug in the translator.

Run 'eui40tip' to run the 4.0 version of the interpreter and 'euc40tip' to run the 4.0 version of the translator.  
There are no major bugs in 4.0.	

Access the manual for 4.1 here : file:///usr/local/share/euphoria-4.1.0/docs/html/index.html

