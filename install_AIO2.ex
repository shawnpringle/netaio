include std/filesys.e 
include std/error.e 
include std/io.e as io
include std/pipeio.e as pipe
include std/get.e as get
include std/dll.e
include std/filesys.e
include std/search.e
include std/console.e
include std/utils.e
include std/os.e
include revisions.e


enum type boolean true, false=0 end type

type spaceless(sequence s)
	return not find(' ',s)
end type

sequence prefix = "/usr/local"
boolean  dry_run   = false

constant eucfgf =
{
"""[all]
-d E%d
-i %s/include
-i %s/euphoria-common/include
-eudir %s
[translate]
-gcc 
-con 
-com %s
-lib %s/bin/eu.a
[bind]
-eub %s/bin/eub
""",
"""[all]
-d E%d
-i %s/include
-i %s/euphoria-common/include
-eudir %s
[translate]
-gcc 
-con 
-com %s
-lib-pic %s/bin/euso.a
-lib %s/bin/eu.a
[bind]
-eub %s/bin/eub
"""
}
constant cmd = command_line()
			
constant info = pathinfo(cmd[2])
integer register_size -- length of standard registers on this computer in bits
object   void = 0 

atom  f_debug = open(info[PATH_BASENAME]&".log", "w", true)
if f_debug =-1 then
	f_debug = open("/dev/null", "w")
  	logMsg("Unable to create log file.")
  	if f_debug = -1 then
  		logMsg("Installer is for Linux systems only.")
  		abort(1)
  	end if
end if
------------------------------------------------------------------------------ 
 
public procedure logMsg(sequence msg, sequence args = {}) 
  puts(f_debug, msg & "\n") 
  flush(f_debug) 
  puts(1, msg & "\n") 
end procedure 

procedure die(sequence msg, sequence args)
	logMsg(sprintf(msg, args))
	abort(1)
end procedure

------------------------------------------------------------------------------ 
 
public function execCommand(sequence cmd) 
  sequence s = "" 
  object z = pipe:create() 
  object p = pipe:exec(cmd, z) 
  if atom(p) then 
    printf(2, "Failed to exec() with error %x\n", pipe:error_no()) 
    pipe:kill(p) 
	return -1 
  end if 
  object c = pipe:read(p[pipe:STDOUT], 256) 
  while sequence(c) and length(c) do 
    s &= c 
    if atom(c) then 
	  printf(2, "Failed on read with error %x\n", pipe:error_no()) 
      pipe:kill(p) 
	  return -1 
    end if 
    c = pipe:read(p[pipe:STDOUT], 256) 
  end while 
  --Close pipes and make sure process is terminated 
  pipe:kill(p) 
  return s 
end function 
 
------------------------------------------------------------------------------ 
 
function isInstalled(sequence package) 
  sequence s = execCommand("dpkg-query -s " & package & " | grep Status") 
  if length(s) and match("ok installed", s) then 
    return 1 
  else 
    return 0 
  end if 
end function 
 
------------------------------------------------------------------------------ 
 
procedure installIfNot(sequence package) 
  if isInstalled(package) then 
    logMsg(package & " already installed") 
  else 
    logMsg("apt-get install -y " & package) 
    sequence s = execCommand("apt-get install -y " & package) 
    logMsg(s) 
  end if 
end procedure

function include_lines(sequence file_name, sequence lines_to_include)
	sequence file_data = read_file(file_name)
	integer i = 1 while i <= length(lines_to_include) do
		if match(lines_to_include,file_data) != 0 then
			lines_to_include = remove(lines_to_include, i)
		else
			i += 1
		end if
	end while
	return append_lines(file_name, lines_to_include)
end function

procedure cmdl_help()
	die("Usage : %s %s [ -n ] [ -p /usr/local ] [ -4 ] [ -8 ]", cmd[1..2])
end procedure


------------------------------------------------------------------------------ 
register_size = 0
boolean skip_count = 0
sequence options = {}
for cmdi = 3 to length(cmd) do
	if begins("-", cmd[cmdi]) then
		object next = 0
		for cmdij = 2 to length(cmd[cmdi]) do
			if skip_count then
				skip_count = false
				continue
			end if
			integer opt = cmd[cmdi][cmdij]
			switch opt do
				case 'p' then
					next = cmd[cmdi][cmdij+1..$]
					if length(next) = 0 then
						if cmdi = length(cmd) then
							cmdl_help()
						else
							next = cmd[cmdi+1]
							skip_count = true
						end if
					end if
					prefix = next
					exit
				case 'n' then
					dry_run = true
					prefix = "/tmp/test-install"
					system("rm -fr /tmp/test-install/*",2)
					create_directory(prefix, 0t755, false)
					create_directory(prefix & "/lib", 0t755)
					create_directory(prefix & "/bin", 0t755)
					create_directory(prefix & "/share", 0t755)
					while not file_exists(prefix & "/lib") or not file_exists(prefix & "/bin") or not file_exists(prefix & "/share") do
						sleep(0.1)
					end while
					case '8','4' then
					register_size = (opt-'0')*8
				case else
					die("Invalid option -%s", {opt})
			end switch
		end for
	else
		cmdl_help()
	end if
end for

-- verify user is root 
object s = execCommand("id -u")
if atom(s) then
	logMsg("id -u command failed.")
	abort(1)
end if
s = get:value(s)
if s[1] != GET_SUCCESS or s[2] != 0 and not dry_run then 
	logMsg("User was not root.")
    abort(1)
end if

if register_size = 0 then
	while find(register_size,{32,64})=0 with entry do
	  display("Enter 32 or 64.")
	  register_size = 0
	entry
	  register_size = floor(prompt_number("Enter the number of bits of your computer's processor:", {32,64}))
	end while
end if

constant old_aio_archive_format = "http://rapideuphoria.com/install_aio_linux_%d.tgz"
constant old_aio_location = sprintf(old_aio_archive_format, {register_size})
constant wxide_location   = "http://downloads.sourceforge.net/project/wxeuphoria/wxIDE/v0.8.0/wxide-0.8.0-linux-x86" & iff(register_size=64,"-64","") & ".tgz"
constant gtk3_location    = "https://sites.google.com/site/euphoriagtk/EuGTK4.9.9.tar.gz" 
constant wget_archives = { {old_aio_location,"eu41.tgz"}, 
						   {wxide_location, "" },
						   {gtk3_location, ""}	
}
if not isInstalled("wget") then
	if dry_run then
		die("Need wget installed.",{})
	else
		installIfNot("wget")
	end if
end if

constant InitialDir = current_dir()
void = chdir(info[PATH_DIR])


crash_file(InitialDir&SLASH&info[PATH_BASENAME]&".err")

-- install dependencies 
s = read_lines(InitialDir&SLASH&"dependencies.txt")
if atom(s) then
	logMsg("dependencies.txt not readable.")
	abort(1)
end if
for i = 1 to length(s) do
	if dry_run then
		logMsg("Pretending to install " & s[i])
	else
		installIfNot(s[i])
	end if
end for

logMsg("Adding common directories for both versions of Euphoria")
sequence targetBaseDirectory = prefix & "/share"
create_directory(targetBaseDirectory & "/euphoria-common/include", 0t755, true)
create_directory(prefix & "/bin", 0t755, true)
sequence eubins = {"eui", "euc", "creole", "eubind", "eudis", "eudist", "eudoc", "euloc", "eushroud", "eutest"}
for i = 1 to length(eubins) do
	sequence eubin = eubins[i]
	s = execCommand("ln -s " & targetBaseDirectory & "/euphoria/bin/" & eubin & " " & prefix & "/bin/" & eubin)
end for

atom fb, fcfg
spaceless targetDirectory, net_archive_name, local_archive_name
--eu41--------------------------------------------------------
----                                                      ----
----              EEEE  U  U       4 4  1                 ----
----              EE    U  U       444  1                 ----
----              EEEE  UUUU         4  1                 ----
--------------------------------------------------------------
constant aio_archive_format = "http://rapideuphoria.com/install_aio_linux_%d.tgz"
-- Get eu41.tgz
net_archive_name = sprintf(aio_archive_format, {register_size})
local_archive_name = filesys:filename(net_archive_name)
if system_exec("tar -xzf " & local_archive_name & " eu41.tgz",2)
	and
	(system_exec("wget -c " & net_archive_name,2) and system_exec("tar -xzf " & local_archive_name & " eu41.tgz",2)) then
		die("Cannot download needed file : " & aio_archive_format,{register_size})
end if

targetDirectory = targetBaseDirectory & "/euphoria-" & eu41revision

if file_exists(targetDirectory) then
	logMsg(sprintf("Something already exists at \'%s\'.\nOpen Euphoria not (re)installed.", {targetDirectory}))
else
	logMsg("installing OpenEuphoria 4.1") 
	if not create_directory(targetDirectory, 0t755) then
		logMsg(sprintf("Cannot create directory \'%s\'", {targetDirectory}))  	
		abort(1)
	end if
	if system_exec("tar -xf "&InitialDir&SLASH&"eu41.tgz -C "&targetDirectory,2) then
		logMsg("unable to run tar")
		abort(1)
	end if
	fcfg = open(targetDirectory&SLASH&"bin"&SLASH&"eu.cfg", "w")
	if fcfg = -1 then
		logMsg("configuration file cannot be created.")
		abort(1)
	end if
	printf(fcfg, eucfgf[2], register_size & {targetDirectory, targetBaseDirectory} & repeat(targetDirectory,5))
end if

system(sprintf("ln -s %s/euphoria-%s %s/euphoria-4.1", {targetBaseDirectory, eu41revision, targetBaseDirectory}))

logMsg("Creating shortcut scripts for 4.1")
create_directory(prefix & "/bin", 0t755)
fb = open(prefix & "/bin/eui41", "w")
if fb = -1 then
    die("Cannot create %s/bin/euc41",{prefix})
end if
puts(fb,
	"#!/bin/sh\n"&
	targetBaseDirectory & "/euphoria-4.1/bin/eui $@\n"
	)
close(fb)

fb = open(prefix & "/bin/euc41", "w")
if fb = -1 then
    die("Cannot create euc41",{})
end if
puts(fb,
	"#!/bin/sh\n"&
	targetBaseDirectory & "/euphoria-4.1/bin/euc $@\n"
	)
close(fb)
if system_exec("chmod 755 /" & prefix & "/bin/eu[ic]41",2) then
	die("unable to set execute permission on all shortcuts", {})
end if
logMsg("Setting default Euphoria to Euphoria 4.1 Feb, 2015...")
system("ln -s " & targetBaseDirectory & "/euphoria-4.1 " & targetBaseDirectory & "/euphoria",2)

--eu40--------------------------------------------------------
----                                                      ----
----              EEEE  U  U       4 4  000               ----
----              EE    U  U       444  0 0               ----
----              EEEE  UUUU         4  000               ----
--------------------------------------------------------------
targetDirectory = targetBaseDirectory & "/euphoria-" & eu40revision
remove_directory(targetDirectory, true)
-- install OpenEuphoria 4.0
if not file_exists(targetDirectory) then
	logMsg("installing OpenEuphoria 4.0")

	if system_exec("tar -xf " & InitialDir&SLASH&"euphoria-" & eu40revision &".tar -C " & targetBaseDirectory,2) then
		die("tar: error running tar.", {})
	end if
	
	fcfg = open(targetDirectory&SLASH&"bin/eu.cfg", "w", true)
	if fcfg = -1 then
		logMsg(sprintf("configuration file \'%s\' cannot be created.",{targetDirectory&SLASH&"bin/eu.cfg"}))
		abort(1)
	end if
	printf(fcfg, eucfgf[1], register_size & {targetDirectory, targetBaseDirectory} & repeat(targetDirectory,4))
end if


if eu40revision_is_tip then
	logMsg("Setting this version of Euphoria as the TIP of 4.0 with a symbolic link...")
	delete_file(targetBaseDirectory & SLASH & "euphoria-4.0-tip")
	if not file_exists(targetBaseDirectory & SLASH & "euphoria-4.0-tip") then
		if system_exec("ln -s " & targetDirectory & " " & targetBaseDirectory & SLASH & "euphoria-4.0-tip") then
			logMsg("ln : Cannot produce symlink")
			abort(1)
		end if
	else
		logMsg("euphoria-4.0-tip link already exists.")
	end if
	logMsg("Creating shortcut scripts for 4.0...")
	fb = open(SLASH & prefix & "/bin/eui40tip", "w")
	if fb = -1 then
		die("Cannot create eui40tip",{})
	end if
	puts(fb,
		"#!/bin/sh\n"&
		targetBaseDirectory & "/euphoria-4.0-tip/bin/eui $@\n"
		)
	close(fb)
	
	fb = open(prefix & "/bin/euc40tip", "w")
	if fb = -1 then
		die("Cannot create euc40tip",{})
	end if
	puts(fb,
		"#!/bin/sh\n"&
		targetBaseDirectory & "/euphoria-4.0-tip/bin/euc $@\n"
		)
	close(fb)
	
	logMsg("setting execution bits on shortcuts")
	if system_exec("chmod 755 /" & prefix & "/bin/eu[ic]40tip",2) then
		logMsg("unable to set execute permission on all shortcuts")
	end if

end if


logMsg("Setting this version of Euphoria as 4.0 with a symbolic link...")
delete_file(targetBaseDirectory & SLASH & "euphoria-4.0")
if not file_exists(targetBaseDirectory & SLASH & "euphoria-4.0") then
	if system_exec("ln -s " & targetDirectory & " " & targetBaseDirectory & SLASH & "euphoria-4.0") then
		logMsg("ln : Cannot produce symlink")
		abort(1)
	end if
else
	logMsg("euphoria-4.0 link already exists.")
end if
logMsg("Creating shortcut scripts for 4.0...")
fb = open(SLASH & prefix & "/bin/eui40", "w")
if fb = -1 then
	die("Cannot create eui40",{})
end if
puts(fb,
	"#!/bin/sh\n"&
	targetBaseDirectory & "/euphoria-4.0/bin/eui $@\n"
	)
close(fb)

fb = open(prefix & "/bin/euc40", "w")
if fb = -1 then
    die("Cannot create euc40",{})
end if
puts(fb,
	"#!/bin/sh\n"&
	targetBaseDirectory & "/euphoria-4.0/bin/euc $@\n"
	)
close(fb)

logMsg("setting execution bits on shortcuts")
if system_exec("chmod 755 /" & prefix & "/bin/eu[ic]40",2) then
	logMsg("unable to set execute permission on all shortcuts")
end if


--wxide-------------------------------------------------------
----                                                      ----
----              W     W X   X  III DDDD EEEE            ----
----               W W W    X     I   D D EE              ----
----                W W   X   X  III DDDD EEEE            ----
--------------------------------------------------------------
-- Get wxIDE
if register_size = 32 then
	net_archive_name = "http://downloads.sourceforge.net/project/wxeuphoria/wxIDE/v0.8.0/wxide-0.8.0-linux-x86.tgz"
else
	net_archive_name = "http://downloads.sourceforge.net/project/wxeuphoria/wxIDE/v0.8.0/wxide-0.8.0-linux-x86-64.tgz"
end if
local_archive_name = filesys:filename(net_archive_name)
if system_exec("tar -xzf " & local_archive_name,2)
	and
	(system_exec("wget -c " & net_archive_name,2) and system_exec("tar -xzf " & local_archive_name,2)) then
		die("Cannot download needed file : %s",{local_archive_name})
end if
logMsg("installing WXIDE") 
constant wxide_archive_base = InitialDir & SLASH & filesys:filebase(wxide_location)
-- intall wxeu binary wrapper
-- check to make sure we have really installed ALL dependencies

constant libraries = dir(wxide_archive_base & "/bin")
for li = 1 to length(libraries) do
	sequence library = libraries[li][D_NAME]
	if match(".so.", library) then
		s = execCommand(sprintf("ldd %s/bin/%s | grep -v /.* +=> /.*", {wxide_archive_base, library}))
		if atom(s) then
			continue
		end if
		if length(s) then
			logMsg(s)
			die("Missing library, please report log to http://www.github.com/shawnpringle/netaio or \n"&
				"the EUForum http://www.openeuphoria.com/forum/index.wc", {})
		end if
		if not copy_file(InitialDir & SLASH & filesys:filebase(wxide_location) & "/bin/" & library, prefix & "/lib/" & library, 1) then
			die("Could not install %s into %s/lib", {library, prefix})
		end if
	end if
end for
if not copy_file(wxide_archive_base & "/bin/wxide.bin", prefix & "/bin/wxide") then
	die("Unable to copy %s/bin/wxide.bin to %s/bin/wxide", {wxide_archive_base, prefix})
end if
s = execCommand("chmod 755 "& prefix &"/bin/wxide")
integer wxide_last_slash = rfind( '/', wxide_location )
integer wxide_dash_linux = match("-linux", wxide_location, wxide_last_slash )
constant wxide_share_dest_dir = targetBaseDirectory & "/" & wxide_location[wxide_last_slash..wxide_dash_linux-1]
create_directory(wxide_share_dest_dir & "/docs", 0t755, true)
copy_file(wxide_archive_base & "/docs/docs.css", wxide_share_dest_dir & "/docs/docs.css")
copy_file(wxide_archive_base & "/docs/wxide.html", wxide_share_dest_dir & "/docs/wxide.html")
system("ln -s " & targetBaseDirectory & "/euphoria-common/include/wxeu " & wxide_share_dest_dir & "/include", 2)
create_directory(targetBaseDirectory & "/euphoria-common/include/wxeu", 0t755)
copy_file(wxide_archive_base & "/src/wxeu/wxeud.e", targetBaseDirectory & "/euphoria-common/include/wxeu/wxeud.e", true)
system("chmod a+rx " & targetBaseDirectory & "/euphoria-common/include/wxeu", 2)
s = execCommand("ldconfig " & prefix & "/lib")
if atom(s) then
	logMsg("Could not execute ldconfig.")
end if

--gtk---------------------------------------------------------
----                                                      ----
----                G     TTT  K  K                       ----
----               G  GG   T   KKK                        ----
----                GGG    T   K  K                       ----
--------------------------------------------------------------
net_archive_name = "https://sites.google.com/site/euphoriagtk/EuGTK4.9.9.tar.gz"
local_archive_name = "EuGTK4.9.9.tar.gz"
if system_exec("tar xzf " & local_archive_name,2) and 
	(system_exec("wget -c " & net_archive_name, 2) or system_exec("tar xzf " & local_archive_name,2)) then
	die("Cannot download needed file : %s", {net_archive_name})
end if
system("mv demos ~",2)
logMsg("installing EuGTK")
constant gtk_es = dir(InitialDir & "/demos/Gtk*.e")
if atom(gtk_es) then
	die("Cannot list the gtk demos folder.", {})
end if
-- gtk_es is a sequence
create_directory(targetBaseDirectory & "/euphoria-common/include/gtk", 0t755, true)
for i = 1 to length(gtk_es) do
	copy_file(InitialDir & SLASH & "demos" & SLASH & gtk_es[i][D_NAME],
		targetBaseDirectory & "/euphoria-common/include/gtk/" & gtk_es[i][D_NAME])
end for
create_directory(targetBaseDirectory & "/EuGTK4.9.9/documentation", 0t755, true)
system("ln -s " & targetBaseDirectory & "/euphoria-common/include/gtk " & targetBaseDirectory & "/EuGTK4.9.9/include",2)
constant html_files = dir(InitialDir & "/demos/documentation/*.*")
for htmli = 1 to length(html_files) do
	sequence html_file = html_files[htmli]
	if find('d', html_file[D_ATTRIBUTES]) and html_file[D_NAME][1] != '.' then
		die("Unhandled directory in GTK documentation.",{})
	end if
	copy_file(InitialDir & "/demos/documentation/" & html_file[D_NAME],
		targetBaseDirectory & "/EuGTK4.9.9/documentation/" & html_file[D_NAME])
end for


--logMsg("Copying libraries and binaries...")
move_file(targetBaseDirectory & "/euphoria-4.1/include/myLibs", targetBaseDirectory & "/euphoria-common/include/myLibs")
move_file(targetBaseDirectory & "/euphoria-4.1/include/euslibs", targetBaseDirectory & "/euphoria-common/include/euslibs")
system("chmod a+rx " & targetBaseDirectory & "/euphoria-common/include/myLibs", 2)
system("chmod a+rx " & targetBaseDirectory & "/euphoria-common/include/euslibs", 2)

logMsg("Installation Completed.")
printf(io:STDOUT, """ 
The installation is now complete.  You can open the documentation for Euphoria 4.0 at:
   file://%s/euphoria-4.0/docs/html/index.html
You can open the documentation for Euphoria 4.1 at:
   file://%s/euphoria-4.1/docs/html/index.html
You can open the EuGtk documentation at:
   file://%s/EuGTK4.9.9/documentation/README.html
You can open the WXIDE documentation at:
   file://%s/wxide-0.8.0/docs/wxide.html

For an introduction to Euphoria in general see: file://%s/euphoria-4.0/docs/euphoria/html/intro.html

""", repeat(targetBaseDirectory, 5))
