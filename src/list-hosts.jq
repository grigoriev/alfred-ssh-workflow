# Filter and format ssh hosts into Alfred Script Filter items in one pass.
# Inputs: --arg q (query) and --arg icon (icon path). Input is the host array.
def target:
  "ssh "
  + (if .user != "" then .user + "@" else "" end)
  + (if .hostname != "" then .hostname else .alias end)
  + (if .port != "" then ":" + .port else "" end);
def hit($q): $q == "" or
  (([.alias, .hostname, .user] | join(" ") | ascii_downcase)
    | contains($q | ascii_downcase));
[ .[]
  | select(hit($q))
  | { uid: .alias, title: .alias, arg: .alias, valid: true,
      icon: { path: $icon }, subtitle: target } ]
