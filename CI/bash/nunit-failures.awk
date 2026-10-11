# Print name, message and stack trace of each failed NUnit test-case. POSIX awk.
# Runs after nunit-summary.awk validated the document. Streams one record per
# '<' (see nunit-summary.awk); CDATA sections may span records.
BEGIN { RS="<" }
function decode(value) {
 gsub(/&lt;/, "<", value)
 gsub(/&gt;/, ">", value)
 gsub(/&quot;/, "\"", value)
 gsub(/&apos;/, "\047", value)
 gsub(/&amp;/, "\\&", value)
 return value
}
# Keep the first <message> and <stack-trace> of the case, like the NUnit console.
function add(value) {
 # Unity on Windows writes CRLF; only Git Bash awk drops the CR on read.
 gsub(/\r/, "", value)
 if(field=="message") message=message value
 else if(field=="stack-trace") stack=stack value
}
function finish_case() {
 if(inCase && caseFailed) { printf "\n-- %s --\n%s\n%s\n", name, message, stack; found++ }
 inCase=0; field=""
}
function cdata(text, n) {
 n=index(text,"]]>")
 if(!n) { add(text); inCdata=1; return }
 add(substr(text,1,n-1)); add(decode(substr(text,n+3))); inCdata=0
}
NR==1 { next }
inCdata { add("<"); cdata($0); next }
substr($0,1,8)=="![CDATA[" { cdata(substr($0,9)); next }
!match($0,/^([^"'>]|"[^"]*"|'[^']*')*>/) { next }
{
 tag=substr($0,1,RLENGTH-1); text=substr($0,RLENGTH+1)
 if(tag ~ /^test-case[ \t\r\n]/) {
  finish_case()
  inCase=1; caseFailed=(tag ~ /[ \t\r\n]result="Failed"/)
  name="(unknown test)"; message=""; stack=""; split("", taken)
  if(match(tag,/[ \t\r\n]fullname="[^"]*"/)) name=decode(substr(tag,RSTART+11,RLENGTH-12))
  if(tag ~ /\/$/) finish_case()
 } else if(tag=="/test-case") finish_case()
 else if(inCase && (tag=="message" || tag=="stack-trace") && !taken[tag]++) field=tag
 else if(tag=="/message" || tag=="/stack-trace") field=""
 add(decode(text))
}
END {
 finish_case()
 if(!found) print "\nFailure details were not attached to a test-case; inspect the complete XML result."
}
