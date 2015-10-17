include std/filesys.e 
include std/error.e 
include std/io.e as io
include std/pipeio.e as pipe
include std/get.e as get
include std/net/http.e as http
include std/dll.e
include std/filesys.e
include std/search.e

constant cmd = command_line()
constant info = pathinfo(cmd[2])
object   void = 0 
sequence InitialDir 
procedure my_close(integer fh)
	if fh > 3 then
		close(fh)
	end if
end procedure

integer  f_debug = open(info[PATH_BASENAME]&".log", "w")
if f_debug =-1 then
	f_debug = io:STDERR
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
------------------------------------------------------------------------------ 
  constant archive_format = "http://rapideuphoria.com/install_aio_linux_%d.tgz"
  constant net_archive_name = sprintf(archive_format, {sizeof(C_POINTER)*8})
  create_directory("AIO-tmp")
  constant local_archive_name = "AIO-tmp" & SLASH & filesys:filename(net_archive_name)
  if not file_exists(local_archive_name) then
  	logMsg( "Missing archive...downloading" )
	object archive_data = http_get( net_archive_name )
	--object archive_data = read_file("/tmp/" & filesys:filename(net_archive_name))
	if atom(archive_data) then
		logMsg( "Unable to download.  No Internet?")
		
		abort(1)
	end if
	write_file(local_archive_name, archive_data[2])
  end if
  execCommand("tar xzf " & local_archive_name )
  delete_file("install_AIO")
  --delete_file("readme.txt")
  delete_file("dependencies.txt")
  delete_file("eu41.tgz")
  -- write_file("readme.txt", match_replace("install_AIO",read_file("readme.txt"),"net_install"))
  sequence targetDirectory = "/usr/local/euphoria-4.1.0" 
  if length(cmd) < 3 then
    logMsg( "Usage: install_AIO [<target directory>]")
    logMsg( "Using default target directory: /usr/local/euphoria-4.1.0") 
  else 
    targetDirectory = cmd[3]
  end if
  void = chdir(info[PATH_DIR])
  InitialDir = current_dir()
  f_debug = open(InitialDir&SLASH&info[PATH_BASENAME]&".log", "w") 
  crash_file(InitialDir&SLASH&info[PATH_BASENAME]&".err")
 
  -- verify user is root 
  sequence s = execCommand("id -u")
  s = get:value(s)
  if s[1] != GET_SUCCESS or s[2] != 0 then 
    logMsg("User was not root.")   
    abort(1)
  end if
 
  -- install dependencies 
  s = read_lines(InitialDir&SLASH&"dependencies.txt") 
  for i = 1 to length(s) do
    installIfNot(s[i])
  end for
 
  -- install OpenEuphoria 4.1 
  if not create_directory(targetDirectory) then
  	logMsg(sprintf("Cannot create directory \'%s\'", targetDirectory))  	
  	abort(1)
  end if
  s = execCommand("tar -xvf "&InitialDir&SLASH&"eu41.tgz -C "&targetDirectory) 
  logMsg(s)
 
  -- update environment variables 
  if append_lines("/etc/bash.bashrc", { 
    "export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:"&targetDirectory&"/bin",  
    "export EUDIR="&targetDirectory,
    "export EUINC="&targetDirectory&"/include/" 
  }) = -1 then
    logMsg("Failed to append lines to /etc/bash.bashrc") 
    abort(1)
  end if
 
  -- apply environment variables 
  s = execCommand(". "&SLASH&"/etc/bash.bashrc")
  logMsg(s)
