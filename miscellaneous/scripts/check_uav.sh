#!/bin/bash

RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
NC='\e[39m' # No Color

# #{ hostname_check()
hostname_check () {
  ret_val=0

  hostname=$( cat /etc/hostname )

  echo -e "/etc/hostname is: $hostname"
  echo -e "UAV_NAME is: $UAV_NAME"
  echo -e "checking if UAV_NAME matches hostname ... \c"
  if [ "$UAV_NAME" = "$hostname" ]
  then
    echo -e "${GREEN}match${NC}"
  else
    echo -e "${RED}not matching${NC}"
    echo -e "${YELLOW}Your /etc/hostname and UAV_NAME should be the same!${NC}"
    ret_val=1
  fi
  return $ret_val
}

# #}

# #{ netplan_check()

netplan_check () {

  ret_val=0

  netplan=$( netplan get )
  wlan0_address="$(netplan get wifis.wlan0.addresses | cut -c3-)"
  eth0_address="$(netplan get ethernets.eth0.addresses | cut -c3-)"
  uav_number="${hostname//[!0-9]/}"  #strip all non-numeric chars from hostname, should leave us just with the number of the uav. E.G. -> uav31 -> 31
  expected_wlan_ip="192.168.69.1$uav_number/24"
  expected_eth_ip="10.10.20.1$uav_number/24"

  echo -e "Checking netplan:"

# #{ wlan0

echo -e "Looking for wlan0 interface ... \c"
if [ -z "$(echo "$netplan" | grep wlan0)" ]
then
  echo -e "${RED}missing${NC}"
  echo -e "${YELLOW}Run uav_core/miscellaneous/scripts/fix_network_interface_names.sh${NC}"
  ret_val=1
else
  echo -e "${GREEN}found${NC}"
fi

echo -e "Looking for wlan0 netplan address ... \c"
if [ -z "$wlan0_address" ]
then
  echo -e "${RED}missing${NC}"
  echo -e "${YELLOW}Set your wlan0 IP address in netplan${NC}"
  ret_val=1
else
  echo -e "${GREEN}found${NC} $wlan0_address"
fi

echo -e "expected wlan0 ip address: $expected_wlan_ip ... \c"
if [ "$expected_wlan_ip" = "$wlan0_address" ]
then
  echo -e "${GREEN}match${NC}"
else
  echo -e "${RED}not matching${NC}"
  echo -e "${YELLOW}Correct your wlan0 ip address!${NC}"
  ret_val=1
fi

# #}

# #{ eth0

echo -e "Looking for eth0 interface ... \c"
if [ -z "$(echo "$netplan" | grep eth0)" ]
then
  echo -e "${RED}missing${NC}"
  echo -e "${YELLOW}Run uav_core/miscellaneous/scripts/fix_network_interface_names.sh${NC}"
  ret_val=1
else
  echo -e "${GREEN}found${NC}"
fi

echo -e "Looking for eth0 netplan address ... \c"
if [ -z "$eth0_address" ]
then
  echo -e "${RED}missing${NC}"
  echo -e "${YELLOW}Set your eth0 IP address in netplan${NC}"
  ret_val=1
else
  echo -e "${GREEN}found${NC} $eth0_address"
fi

echo -e "expected eth0 ip address: $expected_eth_ip ... \c"
if [ "$expected_eth_ip" = "$eth0_address" ]
then
  echo -e "${GREEN}match${NC}"
else
  echo -e "${RED}not matching${NC}"
  echo -e "${YELLOW}Correct your eth0 ip address!${NC}"
  ret_val=1
fi

# #}

return $ret_val

}
# #}

# #{ hosts_check()

hosts_check () {

  ret_val=0

  hosts=$( cat /etc/hosts )
  hostname=$( cat /etc/hostname )
  wlan0_address_noslash=$(echo "$wlan0_address" | cut -f1 -d"/")

  echo -e "Checking /etc/hosts:"

  echo -e "127.0.0.1 localhost ... \c"
  if [ -z "$(echo "$hosts" | grep 127.0.0.1 | grep localhost)" ]
  then
    echo -e "${RED}missing${NC}"
    echo -e "${YELLOW}add this line into /etc/hosts:${NC}"
    echo -e "${YELLOW}127.0.0.1 localhost${NC}"
    ret_val=1
  else
    echo -e "${GREEN}found${NC}"
  fi

  echo -e "127.0.1.1 $hostname ... \c"
  if [ -z "$(echo "$hosts" | grep 127.0.1.1 | grep $hostname)" ]
  then
    echo -e "${RED}missing${NC}"
    echo -e "${YELLOW}add this line into /etc/hosts:${NC}"
    echo -e "${YELLOW}127.0.1.1 $hostname${NC}"
    ret_val=1
  else
    echo -e "${GREEN}found${NC}"
  fi

  echo -e "$wlan0_address_noslash $hostname ... \c"
  if [ -z "$(echo "$hosts" | grep $wlan0_address_noslash | grep $hostname)" ]
  then
    echo -e "${RED}missing${NC}"
    echo -e "${YELLOW}add this line into /etc/hosts:${NC}"
    echo -e "${YELLOW}$wlan0_address_noslash	$hostname${NC}"
    ret_val=1
  else
    echo -e "${GREEN}found${NC}"
  fi

  echo -e "looking for entries with $wlan0_address_noslash ... \c"
  lines_with_address=$(echo "$hosts" | grep -w $wlan0_address_noslash)
  num_lines_with_address=$(echo "$lines_with_address" | wc -l)
  if [ -z "${lines_with_address}" ]
  then
    num_lines_with_address=0
  fi

  if [[ $num_lines_with_address -eq 1 ]]
  then
    echo -e "${GREEN}found 1 entry${NC}, this is correct"
  else
    echo -e "${RED}found $num_lines_with_address ${NC}entries:"
    echo -e "${YELLOW}$lines_with_address${NC}"
    echo -e "${YELLOW}There should only be 1 entry with $wlan0_address_noslash address${NC}"
    ret_val=1
  fi

  return $ret_val

}
# #}

# #{ dev_check()

dev_check () {

  ret_val=0

  echo -e "Checking /dev"
  echo -e "Checking for pixhawk ... \c"
  pixhawk=$(ls /dev | grep pixhawk)

  if [ -z "${pixhawk}" ]
  then
    echo -e "${RED}missing${NC}"
    echo -e "${YELLOW}add pixhawk to udev rules and make sure it is connected!${NC}"
    ret_val=1
  else
    echo -e "${GREEN}found${NC}"
  fi

  if ! [ -z "$(echo "$SENSORS" | grep rplidar)" ]
  then
    rplidar=$(ls /dev | grep rplidar)
    echo -e "Checking for rplidar ... \c"
    if [ -z "${rplidar}" ]
    then
      echo -e "${RED}missing${NC}"
      echo -e "${YELLOW}add rplidar to udev rules and make sure it is connected!${NC}"
      ret_val=1
    else
      echo -e "${GREEN}found${NC}"
    fi
  fi
  return $ret_val
}

# #}

# #{ swap_check()
swap_check () {
  ret_val=0
  echo -e "Checking swap size:"

  num_threads=$(grep -c ^processor /proc/cpuinfo)

  swap=$(grep Swap /proc/meminfo | grep SwapTotal)
  swap="${swap//[!0-9]/}"  #strip all non-numeric chars from hostname, should leave us just with the number of the uav. E.G. -> uav31 -> 31

  ram=$(grep MemTotal /proc/meminfo)
  ram="${ram//[!0-9]/}"  #strip all non-numeric chars from hostname, should leave us just with the number of the uav. E.G. -> uav31 -> 31

  total_mem=$(echo "scale=2; (($ram + $swap) / 1048576)" | bc -l)
  req_mem=$(echo "scale=2; $num_threads * 2.5" | bc -l)

  echo -e "Total swap + RAM size: $total_mem GB"
  echo -e "Recommended size: $req_mem GB ... \c"

  if (( $(echo "$total_mem > $req_mem" |bc -l) ))
  then
    echo -e "${GREEN}pass${NC}"
  else
    echo -e "${RED}fail${NC}"
    echo -e "${YELLOW}Increase you swap size, you can run out of memory when you compile the system${NC}"
    ret_val=1
  fi

  return $ret_val
}

# #}

# #{ workspace_check()
# $1 - workspace which should be checked
# $2 - if you provide 2 workspaces, the script will check that the first workspace is extending the second one

workspace_check () {
  ret_val=0
  curr_dir=$PWD
  workspace=$1

  echo -e "looking for $workspace ... \c"
  if [[ -d "$HOME/$workspace" ]]
  then
    echo -e "${GREEN}found${NC}"
    cd "$HOME/$workspace"

    echo -e "checking $workspace ... \c"
    workspace_valid=$(catkin locate | grep ERROR)

    if [ -z "${workspace_valid}" ]
    then
      echo -e "${GREEN}valid${NC}"
    else
      echo -e "${RED}$workspace is not a valid ROS workspace${NC}"
      echo -e "${YELLOW}run the mrs_uav_system install script!${NC}"
      ret_val=1
    fi

  else
    echo -e "${RED}missing${NC}"
    echo -e "${YELLOW}run the mrs_uav_system install script!${NC}"
    ret_val=1
  fi
# check workspace extension
  if [[ $# -eq 2 ]]; then
    should_extend=$2
    echo -e "checking $workspace is extending $should_extend ... \c"
    is_extending=$(catkin config | grep Extending | grep $2)
    if [ -z "${is_extending}" ]
    then
      echo -e "${RED}$workspace is not extending $should_extend${NC}"
      echo -e "${YELLOW}set up the workspaces correctly!${NC}"
      ret_val=1
    else
      echo -e "${GREEN}valid${NC}"
    fi
  fi

# check for the march=native flag
    echo -e "checking $workspace is not using -march=native ... \c"
    march_native=$(catkin config | grep "Additional CMake Args" | grep "march=native")
    if [ -z "${march_native}" ]
    then
      echo -e "${GREEN}not using${NC}"
    else
      echo -e "${RED}found${NC}"
      echo -e "${YELLOW}$workspace has the -march=native flag enabled${NC}"
      echo -e "${YELLOW}This flag is no longer used in the MRS system, remove it${NC}"
      ret_val=1
    fi

  return $ret_val
}

  # #}

  echo -e "\n----------- Hostname check start -----------"
  hostname_check
  if [[ $? -eq 0 ]]
  then
    echo -e "----------- ${GREEN}Hostname check passed${NC} -----------"
  else
    echo -e "----------- ${RED}Hostname check failed${NC} -----------"
  fi

  echo -e "\n----------- Netplan check start -----------"
  netplan_check
  if [[ $? -eq 0 ]]
  then
    echo -e "----------- ${GREEN}Netplan check passed${NC} -----------"
  else
    echo -e "----------- ${RED}Netplan check failed${NC} -----------"
  fi

  echo -e "\n----------- Hosts check start -----------"
  hosts_check
  if [[ $? -eq 0 ]]
  then
    echo -e "----------- ${GREEN}Hosts check passed${NC} -----------"
  else
    echo -e "----------- ${RED}Hosts check failed${NC} -----------"
  fi

  echo -e "\n----------- Dev check start -----------"
  dev_check
  if [[ $? -eq 0 ]]
  then
    echo -e "----------- ${GREEN}Dev check passed${NC} -----------"
  else
    echo -e "----------- ${RED}Dev check failed${NC} -----------"
  fi

  echo -e "\n----------- Swap check start -----------"
  swap_check
  if [[ $? -eq 0 ]]
  then
    echo -e "----------- ${GREEN}Swap check passed${NC} -----------"
  else
    echo -e "----------- ${RED}Swap check failed${NC} -----------"
  fi

  echo -e "\n----------- Workspace check start -----------"
  workspace_check mrs_workspace
  workspace_check modules_workspace mrs_workspace
  if [[ $? -eq 0 ]]
  then
    echo -e "----------- ${GREEN}Workspace check passed${NC} -----------"
  else
    echo -e "----------- ${RED}Workspace check failed${NC} -----------"
  fi