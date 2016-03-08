include myLibs/common.e
include std/filesys.e
include aio.e

constant args = command_line()
integer argi = 3 
sequence source = ""
while argi < length(args) do
    sequence arg = args[argi]
    sequence next = args[argi+1]
    if equal(arg,"-d") then
        source = next
    end if
    argi += 1
end while

if equal(source,"") then
    puts(2,  args[2] & ": usage :  " & args[2] & " -d source\n")
    abort(1)
end if

sequence destination = current_dir()
chdir(source)
sequence summary = execCommand("hg sum")
integer sl, cl
sl = find(' ', summary)
cl = find(':', summary, sl)
sl = find(' ', summary, cl)
if sl < cl then
    puts(2, args[2] & ": Cannot find revision string\n")
    abort(1)
end if
sequence changeset = summary[cl+1..sl-1]
chdir("source")
object testlogs = dir( "build/" & changeset & ".html" )
if atom(testlogs) then
    testlogs = dir("build/test-report.html")
    if sequence(testlogs) then
        move_file("build/test-report.html", "build/" & changeset & ".html")
    end if
end if
object bins = dir("build/*")
if sequence(bins) and sequence(testlogs) then
    for bini = 1 to length(bins) do
        if find('d', bins[bini][D_ATTRIBUTES]) then
            continue
        end if
        if compare(bins[bini][D_YEAR..D_SECOND], testlogs[1][D_YEAR..D_SECOND]) > 0 then
            testlogs = 0
        end if
    end for
end if
-- don't rebuild if the tests have been done already.
if atom(testlogs) then
    -- first test, must not get here...
    delete_file("build/test-report.html")
    system("sh configure --prefix /tmp/test-install",2)
    system("make all tools test",2)
    move_file("build/test-report.html", "build/" & changeset & ".html")
end if

system("tar -cf " & destination & "/" & filename(eubintar40_url) & "  build/" & changeset & ".html " & `build/eubind build/eudis build/eub build/eushroud build/eutest build/ecp.dat build/eu.a build/euc build/eudbg.a build/eui build/eudist build/eucoverage`)

system("tar -cf " & destination & "/" & filename(eudoctar40_url) & " build/html/* build/html/*/*",2)

chdir(destination)
delete_file("eubin40tip-linux.tar.xz")
system("xz -9 eubin40tip-linux.tar", 2)

delete_file("eudoc40tip.tar.xz")
system("xz -9 eudoc40tip.tar")
