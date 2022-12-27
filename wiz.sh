#!/bin/bash

local PORT=38899
declare -A lights

function wiz() {
  local ip=''
  local location=$(tolower $1)
  local command=$(tolower $2)
  local name=$(tolower $3)
  __assign_lights $location
  case $command in
    'set')
      ip=$(__wiz-light-ip-for $name)
      ;;
    'set-all')
      __wiz-light-set-all "${@:3}"
      return
      ;;
    'get')
      ip=$(__wiz-light-ip-for $name)
      ;;
    'get-all')
      __wiz-light-info-all
      return
      ;;
    *)
      echo >&2 "Error: must provide set, set-all, get, or get-all"
      return
  esac

  #if they provided incorrect light name then return error
  if [[ $ip == *"Error"* ]]; then
      echo $ip
      return
  fi

  #at this point we know it's either set or get for individual and we have valid ip
  case $command in
    'set')
      __wiz-light-set $ip "${@:4}"
      ;;
    'get')
      __wiz-light-info-for $name
      ;;
  esac
}

function __wiz-light-info-raw() {
  echo '{"method":"getPilot","params":{}}' | socat - UDP-DATAGRAM:255.255.255.255:38899,broadcast
}

function __wiz-light-info-all() {
  results=$(mktemp)
  for key ("${(@k)lights}"); do
    result=$(mktemp)
    info=$(__wiz-light-info-for $key)
    local id=$(echo $info | jq -r '.id')
    local ip=$(echo $info | jq -r '.ip')
    local state=$(echo $info | jq -r '.state')
    local scene=$(echo $info | jq -r '.scene')
    local rgb=$(echo $info | jq -r '.rgb')
    local cw=$(echo $info | jq -r '.cw')
    local dimming=$(echo $info | jq -r '.dimming')
    cat <<-EOF > "$result"
    {
      "id":       "$id",
      "ip":       "$ip",
      "state":    "$state",
      "scene":    "$scene",
      "rgb":      "$rgb",
      "cw":       "$cw",
      "dimming":  "$dimming"
    }
EOF
    jq . "${result}" >> $results
  done

  jq -s . "${results}"
}

function __wiz-light-info-for() {
  ip=$(__wiz-light-ip-for $1)
  name=$1
  cmd='{"method":"getPilot","params":{}}'
  results=$(echo $cmd | nc -u -w 1 $ip $PORT)
  sceneId="$(echo $results | jq '.result.sceneId')"
  [[ "$(echo $results | jq '.result.state')" == "true" ]] && state="on" || state="off"
  [[ "$(echo $results | jq '.result.r')" != "null" ]] && r="$(echo $results | jq '.result.r')" || r="0"
  [[ "$(echo $results | jq '.result.g')" != "null" ]] && g="$(echo $results | jq '.result.g')" || g="0"
  [[ "$(echo $results | jq '.result.b')" != "null" ]] && b="$(echo $results | jq '.result.b')" || b="0"
  [[ "$(echo $results | jq '.result.c')" != "null" ]] && c="$(echo $results | jq '.result.c')" || c="0"
  [[ "$(echo $results | jq '.result.w')" != "null" ]] && w="$(echo $results | jq '.result.w')" || w="0"
  [[ "$(echo $results | jq '.result.dimming')" != "null" ]] && dimming="$(echo $results | jq '.result.dimming')" || dimming="0"
  scene=$(__get_scene_name_from_id $sceneId)

  body=$(mktemp)
  cat <<-EOF > "$body"
  {
    "id":       "$name",
    "ip":       "$ip",
    "state":    "$state",
    "scene":    "$scene",
    "rgb":      "$r $g $b",
    "cw":       "$c $w",
    "dimming":  "$dimming"
  }
EOF

  jq . "${body}"
}

function __wiz-light-set() {
  ip=$1
  cmd=""

  case $2 in
    on)
      cmd='{"method":"setPilot","params":{"state":true}}'
      ;;
    off)
      cmd='{"method":"setPilot","params":{"state":false}}'
      ;;
    rgb)
      r=0
      g=0
      b=0
      if [ ! -z "$3" ] ; then r=$3; fi
      if [ ! -z "$4" ] ; then g=$4; fi
      if [ ! -z "$5" ] ; then b=$5; fi
      cmd='{"method":"setPilot","params":{"r":'"$r"',"g":'"$g"',"b":'"$b"'}}'
      ;;
    *)
      scene=$(__get_scene_id_from_name $2)
      cmd='{"method":"setPilot","params":{"sceneId":'"$scene"'}}'
      ;;
  esac

  results=$(echo $cmd | nc -u -w 1 $ip $PORT)
  err=$results | jq '.error.message'

  if [ ! -z $err ]; then echo $err; else echo "success for $1"; fi
}

function __wiz-light-set-all() {
  for key ("${(@k)lights}"); do
    ip=$(__wiz-light-ip-for $key)
    __wiz-light-set $ip "$@"
  done
}

function __wiz-light-ip-for() {
  mac=$(__get_mac_from_name $1)
  if [ -z $mac ]; then
    echo "Error: $1 not in list of lights"
    return
  fi

  ip=$(arp -a | grep $mac | awk '{print $2}' | sed 's/[()]//g')

  echo $ip
}

function __get_scene_id_from_name() {
  local name=$(tolower $1)
  for key ("${(@k)wiz_scenes}"); do
    if [[ $key == $name ]]; then
      echo $wiz_scenes[$key]
    fi
  done
}

function __get_scene_name_from_id() {
  local id=$1
  for key ("${(@k)wiz_scenes}"); do
    if [[ $wiz_scenes[$key] == $id ]]; then
      echo $key
    fi
  done
}

function __get_mac_from_name() {
  local name=$(tolower $1)
  for key ("${(@k)lights}"); do
    if [[ $key == $name ]]; then
      echo $lights[$key]
    fi
  done
}

typeset -A wiz_scenes
wiz_scenes=(
  "null"         "0" 
  "ocean"        "1" 
  "romance"      "2"
  "sunset"       "3"
  "party"        "4"
  "fireplace"    "5"
  "cozy"         "6"
  "forest"       "7"
  "pastel"       "8"
  "wake"         "9"
  "bedtime"     "10"
  "warm"        "11"
  "daylight"    "12"
  "cool"        "13"
  "night"       "14"
  "focus"       "15"
  "relax"       "16"
  "true"        "17"
  "tv"          "18"
  "plant"       "19"
  "spring"      "20"
  "summer"      "21"
  "fall"        "22"
  "deepdive"    "23"
  "jungle"      "24"
  "mojito"      "25"
  "club"        "26"
  "christmas"   "27"
  "halloween"   "28"
  "candlelight" "29"
  "golden"      "30"
  "pulse"       "31"
  "steampunk"   "32"
)

typeset -A wiz_home_macs
wiz_home_macs=(
  "nightstand_l" "19:db:56:ea:63:82"
  "nightstand_r" "a1:23:26:e4:aa:dc"
  "kitchen"	 "20:89:95:36:a5:a6"
  "living"	 "fe:51:b5:cd:7e:28"
)

typeset -A wiz_office_macs
wiz_office_macs=(
  "andrew"  "87:f4:ae:fb:c8:b5"
  "ben"     "a6:2d:b0:72:ab:5b"
  "kevin"   "33:1f:e8:42:27:13"
  "jj"      "7b:7e:1e:54:c5:76"
)

function __assign_lights() {
  lights=()
  location=$(tolower $1)
  case $location in
    "office")
      for key value in ${(kv)wiz_office_macs}; do
       lights[$key]=$value
      done
      ;;
    "home")
      for key value in ${(kv)wiz_home_macs}; do
       lights[$key]=$value
      done
      ;;
    *)
      echo "Error: location must be 'office' or 'home'"
      return
      ;;
  esac
}

