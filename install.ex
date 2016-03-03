-- work on download_40tip() now...

-- Conventions:
-- Comments lines can be arbitrarily long, so it is a good idea to use an editor that supports soft line breaks with word wrapping.   Indent width is 4, and tab width is 4.
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
include std/regex.e
include std/datetime.e
constant version_pattern = regex:new("(\\d+\\.)*\\d+")
constant work_dir = "/tmp/aio"
enum type boolean true, false=0 end type
constant bintar40_url = "http://rapideuphoria.com/a946f8564442.tar.xz"
integer test_frequency = DAYS
constant old_aio_archive_format = "http://rapideuphoria.com/install_aio_linux_%d.tgz"
constant gtk3_location    = "https://sites.google.com/site/euphoriagtk/EuGTK4.11.5.tar.gz" 
type proper_filename(sequence s)
	for i = 1 to length(s) do
		if find(s[i]," {}[]|><'*?\\\"") then
			-- bad character
			return false
		end if
	end for
	return true
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
-lib %s/lib/eu.a
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
 
procedure logMsg(sequence msg, sequence args = {}) 
  puts(f_debug, msg & "\n") 
  flush(f_debug) 
  puts(1, msg & "\n") 
end procedure 

procedure die(sequence msg, sequence args)
	logMsg(sprintf(msg, args))
	abort(1)
end procedure

procedure remove_directory(proper_filename directory, boolean b)
	system("rm -fr " & directory,2)
end procedure

function create_symlink(proper_filename src, proper_filename dest)
        return delete_file(dest) = 1 and system_exec("ln -s " & src & " " & dest) = 0
end function

function wget(proper_filename url)
	integer status = system_exec("wget -c " & url, 2)
	if status != 0 then
		return status
	end if
	return filesys:filename(url)
end function

------------------------------------------------------------------------------ 
 
function execCommand(sequence cmd) 
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
 
function isInstalled(proper_filename package) 
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
	die("Usage : %s %s [ -n ] [ -p /usr/local ] [ -4 ] [ -8 ] [ -0 ] [ -1 ]\n" & 
		" -n      : dry-run (installs with non privledged user, sets prefix to /tmp/test-install\n" &
		" -p path : sets the prefix to path\n" &
		" -4      : sets binary required setting to 32 bits\n" &
		" -8      : sets binary required setting to 64 bits\n" &
		" -0      : sets the default Euphoria to Euphoria 4.0\n" &
		" -1      : sets the default Euphoria to Euphoria 4.1\n"
	, cmd[1..2])
end procedure

include std/net/url.e
include std/filesys.e as fs

procedure void( object x )
end procedure

type interval_unit(integer u)
	return find(u,YEARS & MONTHS & WEEKS & DAYS & HOURS & MINUTES & SECONDS) != 0
end type

function file_age(sequence ff, interval_unit unit)
		sequence fdate = datetime:new(ff[D_YEAR], ff[D_MONTH], ff[D_DAY], ff[D_HOUR], ff[D_MINUTE], ff[D_SECOND])
		integer seconds = datetime:diff(fdate, datetime:now())
		atom t = seconds
		if unit = YEARS then
			unit = DAYS
			t /= 365.25
		elsif t = MONTHS then
			unit = DAYS
			t /= (365.25/12)
		end if
		switch unit with fallthru do
			case WEEKS then
				t /= 7
			case DAYS then
				t /= 24
			case HOURS then
				t /= 60
			case MINUTES then
				t /= 60
			case SECONDS then
				return t
		end switch
end function


function get_content_url(sequence url, sequence link_labels, interval_unit unit = DAYS)
	sequence parse_data = url:parse(url)
	sequence path = parse_data[4]
	sequence local_file_name = filesys:filename(path)
	object file_listing = dir(local_file_name)
	boolean use_local = false
	if sequence(file_listing) then
		-- check time stamp if a day old delete
		sequence ff = file_listing[1]
		use_local = file_age(ff, unit) <= 1
	end if
	if not use_local then
		delete_file( local_file_name )
		void( wget(url) )
	end if
	object content = read_file(local_file_name)
	if atom(content) then
		return 0
	end if
	sequence out = {}
	for i = 1 to length(link_labels) do
		sequence link_label = link_labels[1] 
		integer four_location = match(link_label, content)
		integer ahref_location = rmatch("<a href=\"", content, four_location)
		integer url_begin = ahref_location+9
		integer dq_end = find('\"', content, url_begin)
		out = append(out, parse_data[1] & "://" & parse_data[2] & content[url_begin..dq_end-1])
	end for
	return out
end function

-- Create a very up to date Euphoria 4.0 install
-- This routine downloads the a fixed set of binaries which are updated monthly from The Rapid Euphoria Archive and the rest is the latest sources.  Together these components make an install whose includes, and sources are to the day new and the binaries are to the month new.  The binaries URL must be updated each time the binaries are updated but the sources are dynamically chosen to be the newest in the 4.0 branch.
function download_install_40tip_fails()
	delete_file(work_dir)
	create_directory(work_dir)
	-- get URL of the page of the tip of the 4.0 branch from the repository
	object four_url = get_content_url("http://scm.openeuphoria.org/hg/euphoria/branches", {"4.0"})
	if atom(four_url) then
		return true
	end if
	-- get URL of the bzip2 file of the 4.0 tip sourcse
	object bzip2_url = get_content_url(four_url[1], {"bz2"})
	if atom(bzip2_url) then
		return true
	end if
	-- download if we do not have it or if what we have is older than one day.  The following file name is often tip.tar.bz2 but it isn't always that.
	sequence bzip2_filename = filesys:filename(bzip2_url[1])
	object bzip2_file_list = dir(filesys:filename(bzip2_url[1]))
	boolean download = atom(bzip2_file_list) 
	if not download then
		download = file_age(bzip2_file_list[1], DAYS) > 1
	end if
	if download then
		void( delete_file(bzip2_file_list[1][D_NAME]) )
	end if
	if download
		or system_exec("tar -xjf " & bzip2_filename & " -C " & work_dir,2) != 0 then
			void( wget(bzip2_url[1]) )
        	void( system_exec("tar -xjf " & bzip2_filename & " -C " & work_dir,2) )
	end if
	
	-- Now extract what was downloaded to work_dir ... /euphria-changeset/
	object listing = execCommand("tar -tjf " & bzip2_filename & " -C " & work_dir)
	if atom(listing) then
		return true
	end if
	integer nl_loc = find(10, listing)
	sequence euphoria_directory_name = listing[1..nl_loc-1]
	integer sl_loc = find('/', listing)
	if sl_loc != 0 then
		euphoria_directory_name = euphoria_directory_name[1..sl_loc-1]
	end if
	integer dash_loc = find('-', euphoria_directory_name)
	if dash_loc = 0 then
		return true
	end if
	sequence euphoria_version = euphoria_directory_name[dash_loc+1..$]
	delete_file(prefix & "/share/euphoria")
	create_symlink(prefix & "/share/" & euphoria_directory_name, prefix & "/share/euphoria" )
	create_directory(prefix & "/share/" & euphoria_directory_name)
	
	sequence bintar_name = filesys:filename(bintar40_url)
	if not file_exists(bintar_name) then 
		void( wget(bintar40_url) )
	end if
	system("tar xf " & bintar_name & " -C " & work_dir & "/" & euphoria_directory_name & "/source", 2)
	
	sequence save_dir = current_dir()
	chdir(work_dir & '/' & euphoria_directory_name & "/source")
	create_directory(prefix & "/share/euphoria/lib")
	system("sh configure --without-euphoria  --prefix " & prefix, 2)
	system("make -k install", 2)
	-- the user doesn't need this
	delete_file(prefix & "/bin/" & "buildcpdb.ex")
	-- nor this
	delete_file(prefix & "/bin/bench.ex")
	-- This file is not useful in this bin...
	delete_file(prefix & "/share/euphoria/bin/ecp.dat")
	-- but it is useful in this include directory.
	move_file(prefix & "/bin/ecp.dat", prefix & "/share/" & euphoria_directory_name & "/include/ecp.dat", true)
	sequence bin_files = `ed.ex  eubind  eucoverage.ex  euloc.ex` &
							` bugreport.ex  eub    euc   eui   eushroud`
	integer start_letter = 1, sp_loc
	loop do
		sp_loc = find(' ', bin_files, start_letter)
		if sp_loc = 0 then
			sp_loc = length(bin_files)+1
		end if
		sequence bin_name = bin_files[start_letter..sp_loc-1]
		move_file(prefix & "/bin/" & bin_name, prefix & "/share/euphoria/bin/" & bin_name, true)
		create_symlink(prefix & "/share/euphoria/bin/" & bin_name, prefix & "/bin/" & bin_name)
		start_letter = find(0, bin_files = ' ', sp_loc)
		until sp_loc > length(bin_files)
	end loop

	integer fcfg = open(prefix & "/share/euphoria/bin/eu.cfg", "w", true)
	if fcfg = -1 then
		logMsg(sprintf("configuration file \'%s\' cannot be created.",{prefix & "/share/euphoria/bin/eu.cfg"}))
		return true
	end if
	printf(fcfg, eucfgf[1], 32 & {prefix & "/share/" & euphoria_directory_name, prefix & "/share/"} & repeat(prefix & "/share/" & euphoria_directory_name,4))
	
	-- moving to make these into symlinks.	
	-- It is convenient for users who want to secify -eudbg to have it in /usr/local/lib
	system("ranlib " & prefix & "/lib/eu.a " & prefix & "/lib/eudbg.a",2)
	move_file(prefix & "/lib/eu.a", prefix & "/share/euphoria/lib/eu.a")
	move_file(prefix & "/lib/eudbg.a", prefix & "/share/euphoria/lib/eudbg.a")
	create_symlink(prefix & "/share/euphoria/lib/eu.a", prefix & "/lib/eu.a")
	create_symlink(prefix & "/share/euphoria/lib/eudbg.a", prefix & "/lib/eudbg.a")
	
	sequence targetBaseDirectory = prefix & "/share"
	sequence targetDirectory = prefix & "/share/" & euphoria_directory_name
	logMsg("Setting this version of Euphoria as 4.0 with a symbolic link...")
	delete_file(targetBaseDirectory & SLASH & "euphoria-4.0")
	if not file_exists(targetBaseDirectory & SLASH & "euphoria-4.0") then
		if create_symlink(targetDirectory, targetBaseDirectory & SLASH & "euphoria-4.0") then
			logMsg("ln : Cannot produce symlink")
			return true
		end if
	else
		logMsg("euphoria-4.0 link already exists.")
	end if
	
	
	-- These must be scripts that call other binaries rather than symbolic links because the program will reference eu.cfg from its path.  In the case of a symbolic link it, would be /usr/local/bin.  In this case other versions installed would be using the same eu.cfg file and thus the same include directory and the same binder and the same libraries.  In the case of the script, the binaries will reference eu.cfg from /usr/local/share/euphoria-version-value/bin and thus all of the resources that it must work with will be what it works with. 
	logMsg("Creating shortcut scripts for 4.0...")
	fb = open(SLASH & prefix & "/bin/eui40", "w")
	if fb = -1 then
		logMsg("Cannot create eui40")
		return true
	end if
	puts(fb,
		"#!/bin/sh\n"&
		targetBaseDirectory & "/euphoria-4.0/bin/eui $@\n"
		)
	close(fb)
	
	fb = open(prefix & "/bin/euc40", "w")
	if fb = -1 then
		logMsg("Cannot create euc40")
		return true
	end if
	puts(fb,
		"#!/bin/sh\n"&
		targetBaseDirectory & "/euphoria-4.0/bin/euc $@\n"
		)
	close(fb)
	
	fb = open(SLASH & prefix & "/bin/eub40", "w")
	if fb = -1 then
		logMsg("Cannot create eui40")
		return true
	end if
	puts(fb,
		"#!/bin/sh\n"&
		targetBaseDirectory & "/euphoria-4.0/bin/eub $@\n"
		)
	close(fb)
	
	fb = open(SLASH & prefix & "/bin/eubind40", "w")
	if fb = -1 then
		logMsg("Cannot create eui40")
		return true
	end if
	puts(fb,
		"#!/bin/sh\n"&
		targetBaseDirectory & "/euphoria-4.0/bin/eubind $@\n"
		)
	close(fb)
	
	fb = open(SLASH & prefix & "/bin/eushroud40", "w")
	if fb = -1 then
		logMsg("Cannot create eui40")
		return true
	end if
	puts(fb,
		"#!/bin/sh\n"&
		targetBaseDirectory & "/euphoria-4.0/bin/eushroud $@\n"
		)
	close(fb)
	
	logMsg("setting execution bits on shortcuts")
	if system_exec("chmod 755 " & prefix & "/bin/eu[icb]40 " & prefix & "/bin/eubind40 " & prefix & "/bin/eushroud40",2) then
		logMsg("unable to set execute permission on all shortcuts")
		return true
	end if
	
	chdir(save_dir)
	return false
end function
	
------------------------------------------------------------------------------ 
register_size = 0
sequence default_euphoria = ""
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
					create_directory(prefix, 0t755, false)
					create_directory(prefix & "/lib", 0t755)
					create_directory(prefix & "/bin", 0t755)
					create_directory(prefix & "/share", 0t755)
					while not file_exists(prefix & "/lib") or not file_exists(prefix & "/bin") or not file_exists(prefix & "/share") do
						sleep(0.1)
					end while
				case '8','4' then
					register_size = (opt-'0')*8
				case '0' then
					default_euphoria = "4.0"
				case '1' then
					default_euphoria = "4.1"
				case else
					printf(io:STDERR, "Invalid option -%s\n", {opt})
					cmdl_help()
					abort(1)
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

if sequence(getenv("HOME")) and file_exists(getenv("HOME") & "/demos") then
        die("The directory %s exists.  Please move or remove the directory.", {getenv("HOME") & "/demos"})
end if

if register_size = 0 then
	while find(register_size,{32,64})=0 with entry do
	  display("Enter 32 or 64.")
	  register_size = 0
	entry
	  register_size = floor(prompt_number("Enter the number of bits of your computer's processor:", {32,64}))
	end while
end if


if length(default_euphoria) = 0 then
	while find(default_euphoria,{"4.0","4.1"})=0 with entry do
		display("Enter 4.0 or 4.1")
	entry
		default_euphoria = prompt_string("Choose default EUPHORIA for your system.  eui can mean eui40 or eui41 you can always call with "
		& "eui40 or eui41 if you want to use something other than your default.")
	end while
end if


constant gtk3_offsets =  regex:find(version_pattern, gtk3_location)
if not isInstalled("wget") then
	if dry_run then
		die("Need wget installed.",{})
	else
		installIfNot("wget")
	end if
end if

constant InitialDir = current_dir()
void( chdir(info[PATH_DIR]) )



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
	create_symlink(targetBaseDirectory & "/euphoria/bin/" & eubin, prefix & "/bin/" & eubin)
end for

atom fb, fcfg
proper_filename targetDirectory, net_archive_name, local_archive_name
proper_filename  archive_version

--eu41--------------------------------------------------------
constant aio_archive_format = "http://rapideuphoria.com/install_aio_linux_%d.tgz"
-- Get eu41.tgz
net_archive_name = sprintf(aio_archive_format, {register_size})
local_archive_name = filesys:filename(net_archive_name)
if system_exec("tar -xzf " & local_archive_name & " eu41.tgz",2)
	and
	(sequence(wget(net_archive_name)) and system_exec("tar -xzf " & local_archive_name & " eu41.tgz",2)) then
		die("Cannot download needed file : " & aio_archive_format,{register_size})
end if

targetDirectory = targetBaseDirectory & "/euphoria-" & eu41revision

if file_exists(targetDirectory) then
	logMsg(sprintf("Something already exists at \'%s\'.\nReinstalling....", {targetDirectory}))
	remove_directory(targetDirectory, true)
end if
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

create_symlink(targetBaseDirectory & "/euphoria-" & eu41revision, targetBaseDirectory & "/euphoria-4.1")

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
logMsg("Setting this Euphoria 4.1 version to to be eui41 euc41 etc...")
create_symlink(targetBaseDirectory & "/euphoria-4.1", targetBaseDirectory & "/euphoria")

--eu40--------------------------------------------------------
if download_install_40tip_fails() then
	logMsg("Install of 4.0 tip has failed.  Please contact Shawn Pringle <shawn.pringle@gmail.com>")
	abort(1)
end if

--wxide-------------------------------------------------------
archive_version = "0.8.0"
constant wxide_version = archive_version, wxide_archive_version = wxide_version
if register_size = 32 then
	net_archive_name = "http://downloads.sourceforge.net/project/wxeuphoria/wxIDE/v0.8.0/wxide-0.8.0-linux-x86.tgz"
else
	net_archive_name = "http://downloads.sourceforge.net/project/wxeuphoria/wxIDE/v0.8.0/wxide-0.8.0-linux-x86-64.tgz"
end if
local_archive_name = filesys:filename(net_archive_name)
if system_exec("tar -xzf " & local_archive_name,2)
	and
	(sequence(wget(net_archive_name)) and system_exec("tar -xzf " & local_archive_name,2)) then
		die("Cannot download needed file : %s",{local_archive_name})
end if
logMsg("installing WXIDE") 
constant wxide_location   = "http://downloads.sourceforge.net/project/wxeuphoria/wxIDE/v0.8.0/wxide-0.8.0-linux-x86" & iff(register_size=64,"-64","") & ".tgz"
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
if not copy_file(wxide_archive_base & "/bin/wxide.bin", prefix & "/bin/wxide", true) then
	die("Unable to copy %s/bin/wxide.bin to %s/bin/wxide", {wxide_archive_base, prefix})
end if
s = execCommand("chmod 755 "& prefix &"/bin/wxide")
integer wxide_last_slash = rfind( '/', wxide_location )
integer wxide_dash_linux = match("-linux", wxide_location, wxide_last_slash )
constant wxide_share_dest_dir = targetBaseDirectory & "/" & wxide_location[wxide_last_slash+1..wxide_dash_linux-1]
create_directory(wxide_share_dest_dir & "/docs", 0t755, true)
copy_file(wxide_archive_base & "/docs/docs.css", wxide_share_dest_dir & "/docs/docs.css")
copy_file(wxide_archive_base & "/docs/wxide.html", wxide_share_dest_dir & "/docs/wxide.html")
create_symlink(targetBaseDirectory & "/euphoria-common/include/wxeu", wxide_share_dest_dir & "/include")
create_directory(targetBaseDirectory & "/euphoria-common/include/wxeu", 0t755)
copy_file(wxide_archive_base & "/src/wxeu/wxeud.e", targetBaseDirectory & "/euphoria-common/include/wxeu/wxeud.e", true)
system("chmod a+rx " & targetBaseDirectory & "/euphoria-common/include/wxeu", 2)
s = execCommand("ldconfig " & prefix & "/lib")
if atom(s) then
	logMsg("Could not execute ldconfig.")
end if

type truth_type(integer x) 
	return not equal(x,0)
end type

truth_type truth

--gtk---------------------------------------------------------
net_archive_name = gtk3_location
local_archive_name = filesys:filename(net_archive_name) -- "EuGTK4.11.3.tar.gz"
archive_version = gtk3_location[gtk3_offsets[1][1]..gtk3_offsets[1][2]]
constant gtk_archive_version = archive_version
if system_exec("tar xzf " & local_archive_name,2) != 0 and 
	(sequence(wget(net_archive_name)) or system_exec("tar xzf " & local_archive_name,2)) != 0 then
	die("Cannot download needed file : %s", {net_archive_name})
end if
logMsg("installing EuGTK")
constant gtk_es = dir(InitialDir & "/demos/Gtk*.e")
if atom(gtk_es) then
	die("Cannot list the gtk demos folder.", {})
end if
-- gtk_es is a sequence
create_directory(targetBaseDirectory & "/euphoria-common/include", 0t755, true)
create_directory(targetBaseDirectory & "/EuGTK" & archive_version & "/documentation", 0t755, true)
create_directory(targetBaseDirectory & "/EuGTK" & archive_version & "/include", 0t755, true)
for i = 1 to length(gtk_es) do
	copy_file(InitialDir & SLASH & "demos" & SLASH & gtk_es[i][D_NAME],
		targetBaseDirectory & "/EuGTK" & archive_version & "/include/" & gtk_es[i][D_NAME])
	create_symlink(targetBaseDirectory & "/EuGTK" & archive_version & "/include/" & gtk_es[i][D_NAME], 
		targetBaseDirectory & "/euphoria-common/include/" & gtk_es[i][D_NAME])
end for
constant html_files = dir(InitialDir & "/demos/documentation/*.*")
for htmli = 1 to length(html_files) do
	sequence html_file = html_files[htmli]
	if find('d', html_file[D_ATTRIBUTES]) and html_file[D_NAME][1] != '.' then
		die("Unhandled directory in GTK documentation.",{})
	end if
	copy_file(InitialDir & "/demos/documentation/" & html_file[D_NAME],
		targetBaseDirectory & "/EuGTK" & archive_version & "/documentation/" & html_file[D_NAME])
end for

--logMsg("Copying libraries and binaries...")
move_file(targetBaseDirectory & "/euphoria-4.1/include/myLibs", targetBaseDirectory & "/euphoria-common/include/myLibs")
move_file(targetBaseDirectory & "/euphoria-4.1/include/euslibs", targetBaseDirectory & "/euphoria-common/include/euslibs")
-- the following file is in the archive has permissions with group and other allow-read bits cleared.
system("chmod a+r " & targetBaseDirectory & "/euphoria-common/include/myLibs/mywxGrid.e", 2)
system("chmod a+rx " & targetBaseDirectory & "/euphoria-common/include/myLibs", 2)
system("chmod a+rx " & targetBaseDirectory & "/euphoria-common/include/euslibs", 2)
delete_file(targetBaseDirectory & "/euphoria")
logMsg("Setting default Euphoria to " & default_euphoria)
create_symlink(targetBaseDirectory & "/euphoria-" & default_euphoria, targetBaseDirectory & "/euphoria")
logMsg("Installation Completed.")
printf(io:STDOUT, """ 
The installation is now complete.  You can open the documentation for Euphoria 4.0 at:
   file://%s/euphoria-4.0/docs/html/index.html
You can open the documentation for Euphoria 4.1 at:
   file://%s/euphoria-4.1/docs/html/index.html
You can open the EuGtk documentation at:
   file://%s/EuGTK""" & gtk_archive_version & """/documentation/README.html
You can open the WXIDE documentation at:
   file://%s/wxide-""" & wxide_version & """/docs/wxide.html

For an introduction to Euphoria in general see: file://%s/euphoria-4.1/docs/euphoria/html/intro.html
    
Use Euphoria 4.0, by calling "eui40" for the interpreter and "euc40" for the translator.
    
""", repeat(targetBaseDirectory, 5))
