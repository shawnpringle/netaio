include std/filesys.e 
include std/error.e 
include std/io.e as io
include std/pipeio.e as pipe
include std/get.e as get
include std/dll.e
include std/filesys.e
include std/search.e

constant cmd = command_line()
constant info = pathinfo(cmd[2])
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
 
public procedure logMsg(sequence msg) 
  puts(f_debug, msg & "\n") 
  flush(f_debug) 
  puts(1, msg & "\n") 
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
  sequence archive_exists = {}
  sequence local_archive_name
  for k = 32 to 64 by 32 do
	 sequence net_archive_name = sprintf(filesys:filename(archive_format), {k})
	 archive_exists = append(archive_exists, file_exists(net_archive_name))
	 if archive_exists[$] then
	 	local_archive_name = filesys:filename(net_archive_name)
	 end if
  end for
  if find(1, archive_exists) = 0 then
  	logMsg(sprintf("Please download either \""& archive_format & "\" or \"" & archive_format & "\" to this directory and run again.",  {32, 64})) 
	abort(1)
  end if
  execCommand("tar xzf " & local_archive_name & " eu41.tgz" )
  sequence targetDirectory = "/usr/local/euphoria-4.1.0"
  if length(cmd) < 3 then
    logMsg( "Usage: install_AIO [<target directory>]")
    logMsg( "Using default target directory: /usr/local/euphoria-4.1.0")
  else 
    targetDirectory = cmd[3]
  end if
  
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

  if file_exists(targetDirectory) then
  	logMsg(sprintf("Something already exists at \'%s\'.\nOpen Euphoria not (re)installed.", {targetDirectory}))
	abort(1)  	
  end if

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
 
  
  
  -- update environment variables 
  if include_lines("/etc/bash.bashrc", { 
    "export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:"&targetDirectory&"/bin",  
    "export EUDIR="&targetDirectory,
    "export EUINC="&targetDirectory&"/include/" 
  }) = -1 then
    logMsg("Failed to append lines to /etc/bash.bashrc") 
    abort(1)
  end if
 
  -- apply environment variables 
  s = execCommand(". "&SLASH&"/etc/bash.bashrc")
  if atom(s) then
  	logMsg("unable to apply environment variables.")
  	abort(1)
  end if
  logMsg(s)
