# WIZ Light Local API

## Setup
Add `source ~/path-to/wiz.sh` to your `.profile`

The WIZ lights do not seem to have a publicly available API to control your lights with. However, you can send JSON payloads via UDP to individual IP addresses of each light on port 38899. You can use `socat` to grab all the of the MAC addresses and current light information for the WIZ lights on your local network by running the following command: `__wiz-light-info-raw | jq`. You can cross reference that information with your app to hydrate the vahashmap of lights. I have WIZ lights at home and the office so I have two hash maps. 

## Examples
The `wiz` function is invoked as such: `wiz [location] [action] [light] params`

- `wiz office get jj` //should return light information formatted with `jq` about the jj light in the office location
- `wiz office get-all` // should return all light information in the office location
- `wiz home set nightstand_l rgb 0 0 255` // should change the left nightstand at home to blue
- `wiz home set-all bedtime` // should set all the lights at home to the bedtime scene
- `wiz office set-all rgb 255` // should set all the office lights to red. g and b are assumed 0

### happy wiz'ing

