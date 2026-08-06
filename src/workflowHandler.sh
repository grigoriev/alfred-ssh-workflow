#!/bin/bash

RESULTS=()
RERUN=""
VARIABLES=()

###############################################################################
# Ask Alfred to re-run the script filter after N seconds (0.1 - 5.0)
#
# $1 delay in seconds
###############################################################################
setRerun() {
  RERUN="$1"
}

###############################################################################
# Set an Alfred variable, passed back to the script on the next run
#
# $1 key
# $2 value
###############################################################################
addVariable() {
  VARIABLES+=("$1"$'\t'"$2")
}

################################################################################
# Adds a result to the result array
#
# $1 uid
# $2 arg
# $3 title
# $4 subtitle
# $5 icon
# $6 valid (pass "no" for a non-actionable item; anything else is valid)
# $7 autocomplete
# $8 cmd modifier subtitle (optional, shown when ⌘ is held)
# $9 cmd modifier arg (optional; the arg used when ⌘⏎ selects the item)
###############################################################################
addResult() {
  # Router subcommands set ARG_PREFIX so a selected item's arg routes back
  # through the "net" keyword (e.g. "Off" becomes "wifi Off").
  local ARG="$2"
  if [ -n "$ARG_PREFIX" ] && [ -n "$ARG" ]; then
    ARG="$ARG_PREFIX$ARG"
  fi

  # A ⌘ modifier routes its own arg the same way as the item arg.
  local MODARG="$9"
  if [ -n "$ARG_PREFIX" ] && [ -n "$MODARG" ]; then
    MODARG="$ARG_PREFIX$MODARG"
  fi

  local ITEM="{"
  if [ -n "$1" ]; then
    ITEM+="\"uid\":\"$(jsonEncode "$1")\","
  fi
  ITEM+="\"title\":\"$(jsonEncode "$3")\","
  ITEM+="\"subtitle\":\"$(jsonEncode "$4")\","
  ITEM+="\"arg\":\"$(jsonEncode "$ARG")\","
  ITEM+="\"icon\":{\"path\":\"$(jsonEncode "$5")\"},"
  if [ "$6" = "no" ]; then
    ITEM+="\"valid\":false,"
  else
    ITEM+="\"valid\":true,"
  fi
  if [ -n "$7" ]; then
    ITEM+="\"autocomplete\":\"$(jsonEncode "$7")\","
  fi
  if [ -n "$MODARG" ]; then
    ITEM+="\"mods\":{\"cmd\":{\"valid\":true,\"arg\":\"$(jsonEncode "$MODARG")\",\"subtitle\":\"$(jsonEncode "$8")\"}},"
  fi
  ITEM="${ITEM%,}}"
  RESULTS+=("$ITEM")
}

###############################################################################
# Prints the feedback json to stdout (Alfred Script Filter format)
###############################################################################
getJSONResults() {
  local OUT="{"

  if [ -n "$RERUN" ]; then
    OUT+="\"rerun\":$RERUN,"
  fi

  if [ "${#VARIABLES[@]}" -gt 0 ]; then
    OUT+="\"variables\":{"
    local J=0 PAIR KEY VAL
    for PAIR in "${VARIABLES[@]}"; do
      KEY="${PAIR%%$'\t'*}"
      VAL="${PAIR#*$'\t'}"
      if [ "$J" -gt 0 ]; then
        OUT+=","
      fi
      OUT+="\"$(jsonEncode "$KEY")\":\"$(jsonEncode "$VAL")\""
      J=$((J + 1))
    done
    OUT+="},"
  fi

  OUT+="\"items\":["
  local I=0 R
  for R in "${RESULTS[@]}"; do
    if [ "$I" -gt 0 ]; then
      OUT+=","
    fi
    OUT+="$R"
    I=$((I + 1))
  done
  OUT+="]}"
  printf '%s\n' "$OUT"
}

###############################################################################
# Escapes a string for embedding in a JSON string literal
###############################################################################
jsonEncode() {
  local S="$1"
  S="${S//\\/\\\\}"
  S="${S//\"/\\\"}"
  S="${S//$'\n'/\\n}"
  S="${S//$'\t'/\\t}"
  S="${S//$'\r'/\\r}"
  printf '%s' "$S"
}

###############################################################################
# Save key=value to the workflow properties
#
# $1 key
# $2 value
# $3 non-volatile 0/1
# $4 filename (optional, filename will be "settings" if not specified)
###############################################################################
setPref() {
  if [ "$3" = "0" ]; then
    local PREFDIR="$alfred_workflow_data"
  else
    local PREFDIR="$alfred_workflow_cache"
  fi

  if [ ! -d "$PREFDIR" ]; then
    mkdir -p "$PREFDIR"
  fi

  if [ -z "$4" ]; then
    local PREFFILE="${PREFDIR}/settings"
  else
    local PREFFILE="${PREFDIR}/$4"
  fi

  if [ ! -f "$PREFFILE" ]; then
    touch "$PREFFILE"
  fi

  local KEY_EXISTS=$(grep -c "^$1=" "$PREFFILE")
  if [ "$KEY_EXISTS" != "0" ]; then
    local TMP=$(grep -ve "^$1=" "$PREFFILE")
    echo "$TMP" > "$PREFFILE"
  fi
  echo "$1=$2" >> "$PREFFILE"
  }

###############################################################################
# Read a value for a given key from the workflow preferences
#
# $1 key
# $2 non-volatile 0/1
# $3 filename (optional, filename will be "settings" if not specified)
###############################################################################
getPref() {
  if [ "$2" = "0" ]; then
    local PREFDIR="$alfred_workflow_data"
  else
    local PREFDIR="$alfred_workflow_cache"
  fi

  if [ ! -d "$PREFDIR" ]; then
    return
  fi

  if [ -z "$3" ]; then
    local PREFFILE="${PREFDIR}/settings"
  else
    local PREFFILE="${PREFDIR}/$3"
  fi

  if [ ! -f "$PREFFILE" ]; then
    return
  fi

  local VALUE=$(sed "/^\#/d" "$PREFFILE" | grep "^$1=" | tail -n 1 | cut -d "=" -f2-)
  echo "$VALUE"
}
