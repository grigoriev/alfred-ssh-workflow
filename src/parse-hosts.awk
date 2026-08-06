# Turn ssh config text into tab-separated rows: alias, hostname, user, port.
# One row per alias. Wildcard and negated patterns are skipped.
function flush() {
  if (n > 0) {
    for (i = 1; i <= n; i++) {
      printf "%s\t%s\t%s\t%s\n", aliases[i], hostname, user, port
    }
  }
  n = 0; hostname = ""; user = ""; port = ""
}
{ key = tolower($1) }
key == "host" {
  flush()
  for (i = 2; i <= NF; i++) {
    if ($i ~ /[*?!]/) continue   # skip wildcard/negated patterns
    aliases[++n] = $i
  }
  next
}
n == 0 { next }
key == "hostname" { hostname = $2; next }
key == "user"     { user = $2; next }
key == "port"     { port = $2; next }
END { flush() }
