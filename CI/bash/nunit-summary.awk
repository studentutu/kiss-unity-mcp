# Validate the XML structure emitted by Unity/NUnit before trusting its summary.
# Intentionally reject DTDs; never resolve external entities. POSIX awk.
# Streams one record per '<': attribute values and character data never hold a
# raw '<', so each record is one tag plus the text after it. Comments, CDATA and
# processing instructions may span records. Linear in the file size; never
# buffer the document and slice it per tag (quadratic: minutes on 2 MB results).
BEGIN { RS="<" }
function die() { failed=1; exit 1 }
function attributes(text,root, key,q,val) {
 while(text !~ /^[ \t\r\n]*$/) {
  sub(/^[ \t\r\n]+/,"",text)
  if(!match(text,/^[A-Za-z_:][A-Za-z0-9_.:-]*/)) die()
  key=substr(text,1,RLENGTH); text=substr(text,RLENGTH+1)
  if(seenAttribute[key]++) die()
  sub(/^[ \t\r\n]*/,"",text); if(substr(text,1,1)!="=") die()
  text=substr(text,2); sub(/^[ \t\r\n]*/,"",text)
  q=substr(text,1,1); if(q!="\"" && q!="\047") die()
  text=substr(text,2); if(!index(text,q)) die()
  val=substr(text,1,index(text,q)-1); text=substr(text,index(text,q)+1)
  if(root) attr[key]=val
  if(length(text) && text !~ /^[ \t\r\n]/) die()
 }
 for(key in seenAttribute) delete seenAttribute[key]
}
function chardata(text) { if(depth==0 && text !~ /^[ \t\r\n]*$/) die() }
# Consume `markup` up to its terminator; the remainder is character data.
function skip_markup(text, n) {
 n=index(text,terminator); if(!n) return
 chardata(substr(text,n+length(terminator))); terminator=""
}
NR==1 { chardata($0); next }
terminator!="" { skip_markup($0); next }
substr($0,1,3)=="!--" { terminator="-->"; skip_markup(substr($0,4)); next }
substr($0,1,8)=="![CDATA[" { if(!depth) die(); terminator="]]>"; skip_markup(substr($0,9)); next }
substr($0,1,1)=="?" { terminator="?>"; skip_markup(substr($0,2)); next }
substr($0,1,1)=="!" { die() }
{
 if(!match($0,/^([^"'>]|"[^"]*"|'[^']*')*>/)) die()
 tag=substr($0,1,RLENGTH-1); text=substr($0,RLENGTH+1)
 closing=(substr(tag,1,1)=="/"); if(closing) tag=substr(tag,2)
 empty=(tag ~ /\/$/); if(empty) tag=substr(tag,1,length(tag)-1)
 if(!match(tag,/^[A-Za-z_:][A-Za-z0-9_.:-]*/)) die()
 name=substr(tag,1,RLENGTH); rest=substr(tag,RLENGTH+1)
 if(closing) {
  if(empty || rest !~ /^[ \t\r\n]*$/ || !depth || stack[depth]!=name) die()
  depth--
 } else {
  if(rest!="" && rest !~ /^[ \t\r\n]/) die()
  if(!depth) { if(rootSeen++ || name!="test-run") die(); attributes(rest,1) }
  else attributes(rest,0)
  if(name=="test-case") cases++
  if(!empty) stack[++depth]=name
 }
 chardata(text)
}
END {
 if(failed) exit 1
 if(terminator!="" || depth || !rootSeen) die()
 split("total passed failed inconclusive skipped",keys," ")
 for(i=1;i<=5;i++) if(attr[keys[i]] !~ /^[0-9]+$/) die()
 if(attr["total"]+0 != cases+0 || attr["total"]+0 != attr["passed"]+attr["failed"]+attr["inconclusive"]+attr["skipped"]) die()
 if(attr["result"] !~ /^(Passed|Failed|Inconclusive|Skipped)(\([A-Za-z]+\))?$/) die()
 # Unity Test Framework 1.6 emits composite labels such as Failed(Child).
 sub(/\(.*/, "", attr["result"])
 printf "<test-run result=\"%s\"",attr["result"]
 for(i=1;i<=5;i++) printf " %s=\"%s\"",keys[i],attr[keys[i]]
 print ">"
}
