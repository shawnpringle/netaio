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

enum type boolean true, false=0 end type

sequence prefix = "/usr/local"
boolean  dry_run   = false

constant eucfgf =
{
"""[all]
-d E%d
-i %s/euphoria/include
-eudir %s
-i %s/include
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
-i %s/euphoria/include
-eudir %s
-i %s/include
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
constant old_aio_archive_format = "http://rapideuphoria.com/install_aio_linux_%d.tgz"
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
----------------------------  R O U T I N E S  -------------------------------
------------------------------------------------------------------------------
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
	die("Usage : %s %s [ -n ] [ -p /usr/local ] [ -32 ] [ -64 ]", cmd[1..2])
end procedure

------------------------------------------------------------------------------ 
------------------------------------------------------------------------------
----------------------------------   M A I N   -------------------------------
------------------------------------------------------------------------------
------------------------------------------------------------------------------
register_size = 0
boolean skip_count = 0
sequence InitialDir = current_dir()
void = chdir(info[PATH_DIR])
crash_file(InitialDir&SLASH&info[PATH_BASENAME]&".err")
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
					if file_exists(prefix) and not remove_directory(prefix, true) then
						remove_directory(prefix, true)
						sleep(0.1)
						if file_exists(prefix) then
							die("Cannot remove %s", {prefix})
						end if
					end if
					create_directory(prefix, 0t755, false)
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

-- determine register_size if not already set.
if register_size = 0 then
	while find(register_size,{32,64})=0 with entry do
	  display("Enter 32 or 64.")
	entry
	  register_size = floor(prompt_number("Enter the number of bits of your computer's processor:", {32,64}))
	end while
end if

-- make sure we have wget installed
if not file_exists("/usr/bin/wget") and not file_exists("/usr/local/bin/wget") then
	if dry_run then
		die("Need wget installed.",{})
	else
		installIfNot("wget")
	end if
end if
-- prepare prefix subdirs
------------------------------------------------------------------------------
constant targetBaseDirectory = prefix & "/share"
create_directory(prefix & "/bin", 0t755, true)
create_directory(prefix & "/lib", 0t755)
logMsg("Adding common directories for both versions of Euphoria")
create_directory(targetBaseDirectory & "/euphoria/include", 0t755, true)


------------------------------------------------------------------------------
--------------------------- D O W N L O A D S  -------------------------------
------------------------------------------------------------------------------
------------------------------------------------------------------------------

constant old_aio_location = sprintf(old_aio_archive_format, {register_size})
constant wxide_location   = "http://downloads.sourceforge.net/project/wxeuphoria/wxIDE/v0.8.0/wxide-0.8.0-linux-x86" & iff(register_size=64,"-64","") & ".tgz"
constant gtk3_location    = "https://sites.google.com/site/euphoriagtk/EuGTK4.9.9.tar.gz" 
constant wget_archives = { {old_aio_location,"eu41.tgz"}, 
						   {wxide_location, "" },
						   {gtk3_location, ""}	
}

for h = 1 to length(wget_archives) do
	sequence net_archive_name = wget_archives[h][1]
	sequence local_archive_name = filesys:filename(net_archive_name)
	sequence list = wget_archives[h][2]
	if system_exec("tar tf " & local_archive_name & ">/dev/null",2) != 0 and
		system_exec("wget -c " & net_archive_name,2) != 0 then
		die("Cannot download needed file : %s", {net_archive_name})
	end if
	if system_exec("tar xzf " & local_archive_name & ' ' & list,2) then
		die("Could not extract %s",{list})
	end if
end for




------------------------------------------------------------------------------
--------------------------------  G T K  -------------------------------------
------------------------------------------------------------------------------
------------------------------------------------------------------------------
create_directory(targetBaseDirectory & "/euphoria/include/gtk", 0t755, true)
constant gtk_es = dir(InitialDir & "/demos/Gtk*.e")
if atom(gtk_es) then
	die("Cannot list the gtk demos folder.", {})
end if
-- gtk_es a sequence
for i = 1 to length(gtk_es) do
	logMsg(sprintf("%s => %s", {InitialDir & SLASH & "demos" & SLASH & gtk_es[i][D_NAME],
		targetBaseDirectory & "/euphoria/include/gtk/" & gtk_es[i][D_NAME]}))
	copy_file(InitialDir & SLASH & "demos" & SLASH & gtk_es[i][D_NAME],
		targetBaseDirectory & "/euphoria/include/gtk/" & gtk_es[i][D_NAME])
end for
create_directory(targetBaseDirectory & "/EuGTK4.9.9/documentation", 0t755, true)
system("ln -s " & targetBaseDirectory & "/euphoria/include/gtk " & targetBaseDirectory & "/EuGTK4.9.9/include",2)
constant html_files = dir(InitialDir & "/demos/documentation/*.*")
for htmli = 1 to length(html_files) do
	copy_file(InitialDir & "/demos/documentation/" & html_files[htmli][D_NAME],
		targetBaseDirectory & "/EuGTK4.9.9/documentation/" & html_files[htmli][D_NAME])
end for

------------------------------------------------------------------------------
------------------------------- w x I D E  -----------------------------------
------------------------------------------------------------------------------
------------------------------------------------------------------------------

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
		if not copy_file(InitialDir & SLASH & filesys:filebase(wxide_location) & "/bin/" & library, prefix & "/lib/" & library) then
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
system("ln -s " & targetBaseDirectory & "/euphoria/include/wxeu " & wxide_share_dest_dir & "/include", 2)
create_directory(targetBaseDirectory & "/euphoria/include/wxeu", 0t755)
copy_file(wxide_archive_base & "/src/wxeu/wxeud.e", targetBaseDirectory & "/euphoria/include/wxeu/wxeud.e", true)
system("chmod a+rx " & targetBaseDirectory & "/euphoria/include/wxeu", 2)
s = execCommand("ldconfig " & prefix & "/lib")
if atom(s) then
	logMsg("Could not execute ldconfig.")
end if

------------------------------------------------------------------------------
------------------E U P H O R I A   4 . 1  -----------------------------------
------------------------------------------------------------------------------
------------------------------------------------------------------------------
sequence targetDirectory = targetBaseDirectory & "/euphoria-4.1.0"
atom fcfg
integer fb
if file_exists(targetDirectory) then
	logMsg(sprintf("Something already exists at \'%s\'.\nOpen Euphoria not (re)installed.", {targetDirectory}))
else
	logMsg("installing OpenEuphoria 4.1") 
	if not create_directory(targetDirectory, 0t755) then
		logMsg(sprintf("Cannot create directory \'%s\'", {targetDirectory}))  	
		abort(1)
	end if
	s = execCommand("tar -xf "&InitialDir&SLASH&"eu41.tgz -C "&targetDirectory)
	if atom(s) then
		logMsg("unable to run tar")
		abort(1)
	end if
	logMsg(s)
	fcfg = open(targetDirectory&SLASH&"bin"&SLASH&"eu.cfg", "w", true)
	if fcfg = -1 then
		logMsg("configuration file cannot be created.")
		abort(1)
	end if
	printf(fcfg, eucfgf[2], register_size & {prefix} & repeat(targetDirectory,6))
end if
remove_directory(targetBaseDirectory & "/euphoria-4.1.0/include/wxeu", true)
-- short cut for 4.1
logMsg("Creating shortcut binaries")
fb = open(prefix & "/bin/eui41feb", "w")
if fb = -1 then
    die("Cannot create euc41feb",{})
end if
puts(fb,
	"#!/bin/sh\n"&
	targetBaseDirectory & "/euphoria-4.1.0/bin/eui $@\n"
	)
close(fb)

fb = open(prefix & "/bin/euc41feb", "w")
if fb = -1 then
    die("Cannot create euc41feb",{})
end if
puts(fb,
	"#!/bin/sh\n"&
	targetBaseDirectory & "/euphoria-4.1.0/bin/euc $@\n"
	)
close(fb)

------------------------------------------------------------------------------
------------------E U P H O R I A   4 . 0  -----------------------------------
------------------------------------------------------------------------------
------------------------------------------------------------------------------
targetDirectory = targetBaseDirectory & "/euphoria-721157c2f5ef"
remove_directory(targetDirectory, true)
-- install OpenEuphoria 4.0
if not file_exists(targetDirectory) then
	logMsg("installing OpenEuphoria 4.0")

	s = execCommand("tar -xf " & InitialDir&SLASH&"euphoria-721157c2f5ef.tar -C " & targetBaseDirectory)
	if atom(s) then
		logMsg("unable to run tar")
		abort(1)
	end if
	if length(s) then
		logMsg("tar:" & s)
	end if
	
	fcfg = open(targetDirectory&SLASH&"bin/eu.cfg", "w", true)
	if fcfg = -1 then
		logMsg(sprintf("configuration file \'%s\' cannot be created.",{targetDirectory&SLASH&"bin/eu.cfg"}))
		abort(1)
	end if
	printf(fcfg, eucfgf[1], register_size & {prefix} & repeat(targetDirectory,5))
	close(fcfg)
end if
if not file_exists(targetBaseDirectory & SLASH & "euphoria-4.0-tip") then
	s = execCommand("ln -s " & targetDirectory & " " & targetBaseDirectory & SLASH & "euphoria-4.0-tip")
	if atom(s) then
		logMsg("ln : Cannot produce symlink")
		abort(1)
	else
		logMsg(sprintf("linking : %s to %s...", {targetDirectory, targetBaseDirectory & SLASH & "euphoria-4.0-tip"}))
	end if
	logMsg(s)
else
	logMsg("euphoria-4.0-tip link already exists.")
end if
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

-------------------------------------------------------------------------

------------------------------------------------------------------------------
----------------------------- MYLIBS and EUSLIBS -----------------------------
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- MUST BE DONE AFTER 4.1, these come with the former aio archive.
move_file(targetBaseDirectory & "/euphoria-4.1.0/include/myLibs", targetBaseDirectory & "/euphoria/include/myLibs")
move_file(targetBaseDirectory & "/euphoria-4.1.0/include/euslibs", targetBaseDirectory & "/euphoria/include/euslibs")

system("chmod a+rx " & targetBaseDirectory & "/euphoria/include/myLibs", 2)
system("chmod a+rx " & targetBaseDirectory & "/euphoria/include/euslibs", 2)

-------------------------------------------------------------------------


logMsg("setting execution bits on shortcuts")
if system_exec("chmod 755 /" & prefix & "/bin/eu[ic]40tip",2) or
	system_exec("chmod 755 /" & prefix & "/bin/eu[ic]41feb",2) then
	logMsg("unable to set execute permission on all shortcuts")
end if

logMsg("Setting default Euphoria to Euphoria 4.1 Feb, 2015...")
s = execCommand("ln -s " & prefix & "/bin/eui41feb " & prefix & "/bin/eui")
s = execCommand("ln -s " & prefix & "/bin/euc41feb " & prefix & "/bin/euc")
sequence eubins = {"eubind", "eudis", "eudist", "euloc", "eushroud", "eutest", "eucoverage"}
for i = 1 to length(eubins) do
	sequence eubin = eubins[i]
	s = execCommand("ln -s " & targetBaseDirectory & "/euphoria-4.1.0/bin/" & eubin & " " & prefix & "/bin/" & eubin)
end for
move_file(targetBaseDirectory & "/euphoria-4.1.0/bin/creole", targetBaseDirectory & "/bin/creole")
move_file(targetBaseDirectory & "/euphoria-4.1.0/bin/eudoc", targetBaseDirectory & "/bin/eudoc")
delete_file(targetBaseDirectory & "/euphoria-4.1.0/bin/wxide.bin")
delete_file(targetBaseDirectory & "/euphoria-4.1.0/bin/wxide")


-- install dependencies apt-get supports.
------------------------------------------------------------------------------
---------------------------- A P T   G E T  ----------------------------------
------------------------------------------------------------------------------
------------------------------------------------------------------------------
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

