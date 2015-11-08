include myLibs/common.e
include std/regex.e

constant pattern = regex:new("""changeset:   \d+:([0-9a-f]+)
branch:      ([_a-z0-9.-]+)""", MULTILINE & DOTALL)

sequence arguments = command_line()
sequence location = arguments[3]
sequence branch_name = arguments[4]
sequence changeset   = arguments[5]

sequence output = execCommand("hg -R " & location & " head")
sequence matches = regex:all_matches(pattern, output)

for i = 1 to length(matches) do
	sequence this_match = matches[i]
	if equal(this_match[3], branch_name) and equal(this_match[2], changeset) then
		puts(1, '1')
		abort(0)
	end if
end for

puts(1, "0")


