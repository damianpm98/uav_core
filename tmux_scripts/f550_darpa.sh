#!/bin/bash

PROJECT_NAME=darpa

MAIN_DIR=~/"bag_files"

# following commands will be executed first, in each window
pre_input="export ATHAME_ENABLED=0; mkdir -p $MAIN_DIR/$PROJECT_NAME; export DISPLAY=:1"

# define commands
# 'name' 'command'
input=(
  'Rosbag' 'waitForRos; roslaunch mrs_general record_stola_josef.launch project_name:='"$PROJECT_NAME"'
'
  'OptFlow' 'waitForRos; roslaunch mrs_optic_flow uav10.launch
'
  'Sensors' 'waitForRos; roslaunch mrs_general sensors_stola.launch
'
  'OrbSlam' 'waitForRos; roslaunch orb_slam stola_josef.launch
'
  'MRS_control' 'waitForRos; roslaunch mrs_uav_manager f550_new_esc.launch
'
	'MotorsOn' 'rosservice call /'"$UAV_NAME"'/control_manager/motors 1'
	'Takeoff' 'rosservice call /'"$UAV_NAME"'/uav_manager/takeoff'
  'GoTo' 'rosservice call /'"$UAV_NAME"'/control_manager/goto "goal: [0.0, 0.0, 1.5, 1.9]"'
  'GoToRelative' 'rosservice call /'"$UAV_NAME"'/control_manager/goto_relative "goal: [0.0, 0.0, 0.0, 0.0]"'
	'Land' 'rosservice call /'"$UAV_NAME"'/uav_manager/land'
  'Show_odom' 'waitForRos; rostopic echo /'"$UAV_NAME"'/odometry/slow_odom
'
  'Show_diag' 'waitForRos; rostopic echo /'"$UAV_NAME"'/odometry/diagnostics
'
  'Mav_diag' 'waitForRos; rostopic echo /'"$UAV_NAME"'/mavros_interface/diagnostics
'
	'KernelLog' 'tail -f /var/log/kern.log -n 100
'
  'roscore' 'roscore
'
  'Multimaster' 'waitForRos; roslaunch mrs_multimaster server.launch'
	'KILL_ALL' 'dmesg; tmux kill-session -t '
)

###########################
### DO NOT MODIFY BELOW ###
###########################

SESSION_NAME=mav

if [ -z ${TMUX} ];
then
  TMUX= tmux new-session -s "$SESSION_NAME" -d
  echo "Starting new session."
else
  echo "Already in tmux, leave it first."
  exit
fi

# get the iterator
ITERATOR_FILE="$MAIN_DIR/$PROJECT_NAME"/iterator.txt
if [ -e "$ITERATOR_FILE" ]
then 
  ITERATOR=`cat "$ITERATOR_FILE"`
  ITERATOR=$(($ITERATOR+1))
else
  echo "iterator.txt does not exist, creating it"
  touch "$ITERATOR_FILE"
  ITERATOR="0"
fi
echo "$ITERATOR" > "$ITERATOR_FILE"   

# create file for logging terminals' output
LOG_DIR="$MAIN_DIR/$PROJECT_NAME/"
SUFFIX=$(date +"%Y_%m_%d_%H_%M_%S")
SUBLOG_DIR="$LOG_DIR/"$ITERATOR"_"$SUFFIX""
TMUX_DIR="$SUBLOG_DIR/tmux"
mkdir -p "$SUBLOG_DIR"
mkdir -p "$TMUX_DIR"

# link the "latest" folder to the recently created one
rm "$LOG_DIR/latest"
rm "$MAIN_DIR/latest"
ln -sf "$SUBLOG_DIR" "$LOG_DIR/latest"
ln -sf "$SUBLOG_DIR" "$MAIN_DIR/latest"

# create arrays of names and commands
for ((i=0; i < ${#input[*]}; i++));
do
  ((i%2==0)) && names[$i/2]="${input[$i]}" 
	((i%2==1)) && cmds[$i/2]="${input[$i]}"
done

# run tmux windows
for ((i=0; i < ${#names[*]}; i++));
do
	tmux new-window -t $SESSION_NAME:$(($i+1)) -n "${names[$i]}"
done

# add pane splitter for mrs_status
tmux new-window -t $SESSION_NAME:$((${#names[*]}+1)) -n "mrs_status"

# clear mrs status file so that no clutter is displayed
truncate -s 0 /tmp/status.txt

# split all panes
pes=""
for ((i=0; i < ((${#names[*]}+2)); i++));
do
  pes=$pes"tmux split-window -d -t $SESSION_NAME:$(($i))"
  pes=$pes"tmux send-keys -t $SESSION_NAME:$(($i)) 'tail -F /tmp/status.txt'"
  pes=$pes"tmux select-pane -U -t $(($i))"
done

tmux send-keys -t $SESSION_NAME:$((${#names[*]}+1)) "${pes}"

sleep 6

# start loggers
for ((i=0; i < ${#names[*]}; i++));
do
	tmux pipe-pane -t $SESSION_NAME:$(($i+1)) -o "ts | cat >> $TMUX_DIR/$(($i+1))_${names[$i]}.log"
done

# send commands
for ((i=0; i < ${#cmds[*]}; i++));
do
	tmux send-keys -t $SESSION_NAME:$(($i+1)) "${pre_input};${cmds[$i]}"
done

pes="sleep 1;"
for ((i=0; i < ((${#names[*]}+2)); i++));
do
  pes=$pes"tmux select-window -t $SESSION_NAME:$(($i))"
  pes=$pes"tmux resize-pane -U -t $(($i)) 150"
  pes=$pes"tmux resize-pane -D -t $(($i)) 7"
done

pes=$pes"tmux select-window -t $SESSION_NAME:4"
pes=$pes"waitForRos; roslaunch mrs_status f550_darpa.launch >> /tmp/status.txt"

tmux send-keys -t $SESSION_NAME:$((${#names[*]}+1)) "${pes}"

tmux -2 attach-session -t $SESSION_NAME

clear
