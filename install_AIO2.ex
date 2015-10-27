include std/filesys.e 
include std/error.e 
include std/io.e as io
include std/pipeio.e as pipe
include std/get.e as get
include std/dll.e
include std/filesys.e
include std/search.e
include std/console.e



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
	die("Usage : %s %s [ -n ] [ -p /usr/local ] [ -32 ] [ -64 ]", cmd[1..2])
end procedure


------------------------------------------------------------------------------ 
constant archive_format = "http://rapideuphoria.com/install_aio_linux_%d.tgz"
register_size = 0
boolean skip_count = 0
sequence options = {}
for cmdi = 3 to length(cmd) do
	if begins("-", cmd[cmdi]) then
		object next = 0
		for cmdij = 2 to length(cmd[cmdi]) do
			integer opt = cmd[cmdi][cmdij]
			if opt = 'p' then
				next = {cmd[cmdi][cmdi+1..$]}
				if length(next[1]) = 0 then
					if cmdi = length(cmd) then
						cmdl_help()
					else
						next = cmd[cmdi+1]
					end if
				end if
				if find(next, {"/usr/local", "/usr", "/opt"}) = false then
					logMsg("Option to -p should be one of /usr/local, /usr, or /opt")
				end if
				prefix = next
			end if
			switch opt do
				case 'n' then
					dry_run = true
					if find(prefix, {"/usr/local", "/usr", "/opt"}) then
						prefix = "/tmp/test-install"
						remove_directory(prefix, true)
						create_directory(prefix, 0t755, false)
					end if
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

sequence archive_exists = {}
sequence local_archive_name
sequence net_archive_name
if register_size = 0 then
	for k = 32 to 64 by 32 do
		net_archive_name = sprintf(filesys:filename(archive_format), {k})
		archive_exists = append(archive_exists, file_exists(net_archive_name))
		if archive_exists[$] then
			register_size = k
		end if
	end for
end if
if not find(true, archive_exists) then
	if not register_size then
		while find(register_size,{32,64})=0 with entry do
		  display("Enter 32 or 64.")
		entry
		  register_size = floor(prompt_number("Enter the number of bits of your computer's processor:", {32,64}))
		end while
	end if
	net_archive_name = sprintf(filesys:filename(archive_format), {register_size})
	system("wget " & net_archive_name,2)
else
	net_archive_name = sprintf(filesys:filename(archive_format), {register_size})
end if
local_archive_name = filesys:filename(net_archive_name)
execCommand("tar xzf " & local_archive_name & " eu41.tgz" )
sequence targetBaseDirectory = prefix & "/share"
sequence targetDirectory = targetBaseDirectory & "/euphoria-4.1.0"
sequence InitialDir = current_dir()
void = chdir(info[PATH_DIR])
crash_file(InitialDir&SLASH&info[PATH_BASENAME]&".err")

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
	s = execCommand("tar -xvf "&InitialDir&SLASH&"eu41.tgz -C "&targetDirectory)
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


create_directory(prefix & "/bin", 0t755, true)
move_file(targetDirectory & "bin/wxide.bin", prefix & "/bin/wxide")
delete_file(targetDirectory & "bin/wxide")

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

logMsg("Adding common directories for both versions of Euphoria")
create_directory(targetBaseDirectory & "/euphoria/include", 0t755, 1)
move_file(targetBaseDirectory & "/euphoria-4.1.0/include/wxeu", targetBaseDirectory & "/euphoria/include/wxeu")
move_file(targetBaseDirectory & "/euphoria-4.1.0/include/myLibs", targetBaseDirectory & "/euphoria/include/myLibs")
move_file(targetBaseDirectory & "/euphoria-4.1.0/include/euslibs", targetBaseDirectory & "/euphoria/include/euslibs")

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
system("chmod 755 /" & prefix & "/bin/eu[ic]40tip",2)
system("chmod 755 /" & prefix & "/bin/eu[ic]41feb",2)


logMsg("Setting default Euphoria to Euphoria 4.1 Feb, 2015...")
s = execCommand("ln -s " & prefix & "/bin/eui41feb " & prefix & "/bin/eui")
s = execCommand("ln -s " & prefix & "/bin/euc41feb " & prefix & "/bin/euc")
