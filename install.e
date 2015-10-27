include std/filesys.e
include std/error.e

sequence delete_stack = {}
constant install_root = getenv("HOME") & "/tip-install/"
sequence prefix = "usr/local"

type truth_t(object x)
	return equal(x,1)
end type
truth_t truth
type enum boolean true,false=0 end type

public procedure set_prefix(sequence pprefix)
	if pprefix[$] = '/' then
		pprefix = pprefix[1..$-1]
	end if
	if pprefix[1] = '/' then
		pprefix = pprefix[2..$]
	end if
	prefix = pprefix
end procedure

public procedure install_copy(sequence src_path_name, sequence dest_dir, atom perm = -1)
	truth = file_exists(src_path_name)
	sequence dest_path_name = dest_dir & SLASH & filesys:filename(src_path_name)
	delete_stack = append(delete_stack, dest_path_name)
	copy_file(src_path_name, install_root & SLASH & prefix & SLASH & dest_path_name)
	if perm != -1 then
		system(sprintf("chmod %o %s", {perm, install_root & SLASH & prefix & SLASH & dest_path_name}),2)
	end if
end procedure

public procedure install_link(sequence src_path_name, sequence dest_path_name)
	delete_stack = append(delete_stack, prefix & SLASH & dest_path_name)
	system("ln -s " & SLASH & prefix & SLASH & src_path_name & " " & install_root & SLASH & prefix & SLASH & dest_path_name, 2)
end procedure

public function install_open(sequence dest_path_name)
	delete_stack = append(delete_stack, prefix & SLASH & dest_path_name)
	create_directory(install_root & SLASH & prefix & SLASH & filesys:dirname(dest_path_name), 0t755, true)
	atom ifd = open(install_root & SLASH & prefix & SLASH & dest_path_name, "w")
	if ifd = -1 then
		crash(sprintf("Cannot open %s for writing.", {install_root & SLASH & prefix & SLASH & dest_path_name}))
		abort(1)
	end if
	return delete_routine(ifd, routine_id("my_close"))
end function

public procedure install_make(sequence command)
	system("DESTDIR=" & install_root & " make " & command,2)
end procedure

public procedure install_create_directory(sequence name, integer perm, boolean make_parents)
	create_directory(install_root & SLASH & prefix & SLASH & name, perm, make_parents)
	delete_stack = append(delete_stack, SLASH & prefix & SLASH & name)
end procedure

public procedure install_make_executables(sequence file)
	system("chmod a+x " & install_root & SLASH & prefix & SLASH & file, 2)
end procedure
