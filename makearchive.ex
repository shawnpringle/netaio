include std/filesys.e 
include std/error.e 
include std/io.e as io
include std/pipeio.e as pipe
include std/get.e as get
include std/dll.e
include std/filesys.e
include std/search.e
include std/regex.e
include std/utils.e

global type true_type(integer x)
	return x = true
end type

global true_type truth

include install.e
constant install_root   = getenv("HOME") & SLASH & "tip-install" & SLASH
constant install_prefix = "usr/local"

set_prefix( install_prefix )

procedure help_die()
	printf(io:STDERR, "Error in syntax : %s source_directory destination\n", {cmd[2]})
	abort(1)
end procedure

procedure my_close(integer fh)
    if fh > io:STDERR then
    	printf(io:STDERR, "Closing file %d\n", {fh})
        close(fh)
    end if
end procedure

------------------------------------------------------------------------------ 
 
public procedure logMsg(sequence msg) 
  puts(f_debug, msg & "\n") 
  flush(f_debug) 
  puts(1, msg & "\n") 
end procedure 
 
------------------------------------------------------------------------------ 
 
public function execCommand(sequence cmd, integer input = pipe:STDOUT) 
  sequence s = "" 
  object z = pipe:create() 
  object p = pipe:exec(cmd, z) 
  if atom(p) then 
    printf(2, "Failed to exec() with error %x\n", pipe:error_no()) 
    pipe:kill(p) 
	return -1 
  end if 
  object c = pipe:read(p[input], 256) 
  while sequence(c) and length(c) do 
    s &= c 
    if atom(c) then 
	  printf(2, "Failed on read() with error %x\n", pipe:error_no()) 
      pipe:kill(p) 
	  return -1 
    end if 
    c = pipe:read(p[input], 256) 
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

function program_exists(sequence program_name)
	return not equal(locate_file(program_name, getenv("PATH")), program_name)
end function


------------------------------------------------------------------------------

type enum boolean true, false=0 end type

-- length of standard registers on this computer in bits
constant register_size = 32

constant eucfgf = 
"""[all]
-d E%d
-eudir %s
-i %s/include
[translate]
-gcc 
-con 
-com %s
-lib %s/bin/eu.a
[bind]
-eub %s/bin/eub
"""
constant cmd = command_line()
if length(cmd) != 3 then
	help_die()
end if
constant source_directory = canonical_path(cmd[3])
constant info = pathinfo(cmd[2])
object   void = 0

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
  
constant InitialDir = current_dir() & '/'
crash_file(InitialDir&"install40tip.err")

constant is_tip = true
constant replace_eui = true
boolean install_docs = false
if program_exists("creole") and program_exists("eudoc") then
	install_docs = true
end if

void = chdir(source_directory & SLASH & "source")
puts(1, source_directory & "/.hg" )
if file_exists(source_directory & SLASH & ".hg") then
	system("hg pull",2)
	system("hg update -r 4.0",2)
else
	logMsg("Cannot determine whether this source is up to date.")
	abort(1)
end if


if not file_exists("config.gnu") then
  puts(io:STDERR, "Configuring source code...")
  execCommand("sh configure")
end if
puts(io:STDERR, "making all targets... please wait...")
if not file_exists(source_directory & "/source/build/eui") then
	system("make all",2)
end if
if install_docs then
	system("make htmldoc", 2)
	if program_exists("pdflatex") then
		system("make pdfdoc",2)
	else
		write_file(source_directory & "/source/build/euphoria.pdf", "", TEXT_MODE)
	end if
end if
puts(io:STDERR, "done\n")

function get_revision_string()
  sequence version_regex = regex:new("Id: \\d+:([a-f0-9]+)", MULTILINE)
  sequence version_output = execCommand("./build/eui --version", pipe:STDERR)
  sequence version_matches = regex:matches(version_regex, version_output)
  if sequence(version_matches) and length(version_matches) = 2 then
	  return version_matches[2]
  end if
  return 0
end function

sequence euphoria_revision = get_revision_string()
printf(io:STDERR, "Detected version string is %s\n", {euphoria_revision})

function bobslash(sequence s)
	if length(s) and equal(s[$], '/') then
		s = s[1..$-1]
	end if
	return s
end function

constant euphoria_versioned_directory = sprintf("share/euphoria-%s", {euphoria_revision})                       
constant euphoria_directory           = "share/euphoria"
create_directory(install_root & SLASH & install_prefix & SLASH & euphoria_versioned_directory,0t755,true)
system("ln -s " & install_root & SLASH & install_prefix & SLASH & euphoria_versioned_directory & SLASH &
	"  " & install_root & SLASH & install_prefix & SLASH & euphoria_directory,2)
install_make("install")
delete_file(install_root & SLASH & install_prefix & SLASH & euphoria_directory)

constant bin_dir = euphoria_versioned_directory & "/bin"
install_create_directory(bin_dir, 0t755, true)
sequence eubins = { "eui", "euc", "eub", "eu.a" , "eudbg.a" }

for eubini = 1 to length(eubins) do
	sequence eubin = eubins[eubini]
	install_copy( source_directory & "/source/build/" & eubin, bin_dir, iff(ends(".a", eubin),0t644,0t755) )
	delete_file( install_root & SLASH & install_prefix & SLASH & "bin" & SLASH & eubin )
	delete_file( install_root & SLASH & install_prefix & SLASH & "lib" & SLASH & eubin )
end for
install_copy(source_directory & "/bin/ecp.dat", bin_dir, 0t644)
chdir(install_root & SLASH & install_prefix)
system("tar -cf " & InitialDir & "euprogs.tar bin",2)
chdir(install_root & SLASH & install_prefix & SLASH & "share")
system("tar -cf " & InitialDir & sprintf("euphoria-%s.tar euphoria-%s", repeat(euphoria_revision,2)),2)
remove_directory(install_root,true)
