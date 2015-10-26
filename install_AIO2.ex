include std/filesys.e 
include std/error.e 
include std/io.e as io
include std/pipeio.e as pipe
include std/get.e as get
include std/dll.e
include std/filesys.e
include std/search.e
include std/console.e



enum true
constant prefix = "/usr/local"

constant eucfgf = 
"""[all]
-d E%d
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
constant cmd = command_line()
constant info = pathinfo(cmd[2])
integer register_size -- length of standard registers on this computer in bits
object   void = 0 
procedure my_close(integer fh)
    if fh > io:STDERR then
    	printf(io:STDERR, "Closing file %d\n", {fh})
    	crash("premature file closing")
        close(fh)
    end if
end procedure

atom  f_debug = open(info[PATH_BASENAME]&".log", "w")
if f_debug =-1 then
	f_debug = open("/dev/null", "w")
  	logMsg("Unable to create log file.")
  	if f_debug = -1 then
  		logMsg("Installer is for Linux systems only.")
  		abort(1)
  	end if
else
    f_debug = delete_routine(f_debug, routine_id("my_close"))
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

------------------------------------------------------------------------------ 
constant archive_format = "http://rapideuphoria.com/install_aio_linux_%d.tgz"
register_size = 0
sequence archive_exists = {}
sequence local_archive_name

for k = 32 to 64 by 32 do
	sequence net_archive_name = sprintf(filesys:filename(archive_format), {k})
	archive_exists = append(archive_exists, file_exists(net_archive_name))
	if archive_exists[$] then
		register_size = k
		local_archive_name = filesys:filename(net_archive_name)
	end if
end for
if not find(true, archive_exists) then
	while find(register_size,{32,64})=0 with entry do
	  display("Enter 32 or 64.")
	entry
	  register_size = floor(prompt_number("Enter the number of bits of your computer's processor:", {32,64}))
	end while
	system(sprintf("wget " & archive_format, {register_size}),2) 
end if
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
if s[1] != GET_SUCCESS or s[2] != 0 then 
logMsg("User was not root.")
--    abort(1)
end if

-- install dependencies 
s = read_lines(InitialDir&SLASH&"dependencies.txt")
if atom(s) then
	logMsg("dependencies.txt not readable.")
	abort(1)
end if
for i = 1 to length(s) do
	installIfNot(s[i])
end for

atom fcfg
integer fb
if file_exists(targetDirectory) then
	logMsg(sprintf("Something already exists at \'%s\'.\nOpen Euphoria not (re)installed.", {targetDirectory}))
else
	-- install OpenEuphoria 4.1 
	if not create_directory(targetDirectory, 0t755) then
		logMsg(sprintf("Cannot create directory \'%s\'", targetDirectory))  	
		abort(1)
	end if
	s = execCommand("tar -xvf "&InitialDir&SLASH&"eu41.tgz -C "&targetDirectory)
	if atom(s) then
		logMsg("unable to run tar")
		abort(1)
	end if
	logMsg(s)
	fcfg = open(targetDirectory&SLASH&"bin"&SLASH&"eu.cfg", "w", 0t644)
	if fcfg = -1 then
		logMsg("configuration file cannot be created.")
		abort(1)
	end if
	fcfg = delete_routine(fcfg, routine_id("my_close"))
	printf(fcfg, eucfgf, register_size & repeat(targetDirectory,6))
end if


fb = open(prefix & "/bin/eui41feb", "w", 0t755)
if fb = -1 then
    die("Cannot create euc41feb",{})
end if
puts(fb,
	"#!/bin/sh\n"&
	targetBaseDirectory & "/euphoria-4.1.0/bin/euc $@\n"
	)


fb = open(prefix & "/bin/euc41feb", "w", 0t755)
if fb = -1 then
    die("Cannot create euc41feb",{})
end if
puts(fb,
	"#!/bin/sh\n"&
	targetBaseDirectory & "/euphoria-4.1.0/bin/euc $@\n"
	)


fb = open(prefix & "/bin/eui40tip", "w", 0t755)
if fb = -1 then
	die("Cannot create eui40tip",{})
end if
puts(fb,
	"#!/bin/sh\n"&
	targetBaseDirectory & "/euphoria-4.0-tip/bin/eui $@\n"
	)


fb = open(prefix & "/bin/euc40tip", "w", 0t755)
if fb = -1 then
    die("Cannot create euc40tip",{})
end if
puts(fb,
	"#!/bin/sh\n"&
	targetBaseDirectory & "/euphoria-4.0-tip/bin/euc $@\n"
	)



targetDirectory = targetBaseDirectory & "/euphoria-721157c2f5ef"
-- install OpenEuphoria 4.0
if not create_directory(targetDirectory, 0t755) then
	logMsg(sprintf("Cannot create directory \'%s\'", targetDirectory))
	abort(1)
end if
s = execCommand("tar -xf " & InitialDir&SLASH&"euphoria-721157c2f5ef.tar -C " & targetDirectory)
if atom(s) then
	logMsg("unable to run tar")
	abort(1)
end if
logMsg(s)

fcfg = open(targetDirectory&SLASH&"bin/eu.cfg", "w", 0t644)
if fcfg = -1 then
	logMsg("configuration file cannot be created.")
	abort(1)
end if
fcfg = delete_routine(fcfg, routine_id("my_close"))
printf(fcfg, eucfgf, register_size & repeat(targetDirectory,6))

if file_exists(targetBaseDirectory & SLASH & "euphoria-4.0-tip") then
	delete_file(targetBaseDirectory & SLASH & "euphoria-4.0-tip")
end if
s = execCommand("ln -s " & targetDirectory & " " & targetBaseDirectory & SLASH & "euphoria-4.0-tip")
if atom(s) then
	logMsg("Cannot produce symlink")
	abort(1)
end if
logMsg(s)
