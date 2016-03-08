include std/text.e
include std/os.e

function  platform_name()
        switch platform() do
		case LINUX then
			return "LINUX"
		case WINDOWS then
			return "WINDOWS"
		case else
		        puts(2, "Unsupported platform")
		        abort(1)
        end switch
end function


public constant eubintar40_url = "http://rapideuphoria.com/eubin40tip-" & lower(platform_name()) & ".tar.xz"
public constant eudoctar40_url = "http://rapideuphoria.com/eudoc40tip.tar"
