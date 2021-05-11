#!/bin/bash

########################
# Load demo magic
########################

function getopts {
  return 1
}

TT_SCRIPT_DIR=`dirname $0`
. $TT_SCRIPT_DIR/demo-magic.sh

########################
# Configure demo magic
########################

TYPE_SPEED=100

#
# custom prompt
#
# see http://www.tldp.org/HOWTO/Bash-Prompt-HOWTO/bash-prompt-escape-sequences.html for escape sequences
#
DEMO_PROMPT="${GREEN}➜ ${CYAN}\W "

#
# custom colors
#
DEMO_CMD_COLOR="\033[0;37m"
DEMO_COMMENT_COLOR="\033[0;32m"

########################
# Start termitorial
########################

TT_START_TIME=$SECONDS

#
# directory and files settings
#
TT_DIR=${TT_DIR:-$PWD}
TT_PROGRESS_FILE="$TT_DIR/.tutorial-progress"
TT_STATES_FILE="$TT_DIR/.tutorial-states"
touch $TT_PROGRESS_FILE
touch $TT_STATES_FILE
. $TT_STATES_FILE

#
# color settings
#
TT_COLOR_EXCERPT="\033[0;34m"
TT_COLOR_POINTER="\033[0;32m"
TT_COLOR_QUESTION="\033[0;36m"
TT_COLOR_PROMPT="\033[0;37m"
TT_COLOR_FINISH="\033[0;36m"
TT_COLOR_ACTIVE="\033[0;37m"
TT_COLOR_UNKNOWN="\033[0;33m"
TT_COLOR_RESET="\033[0m"

#
# command settings
#
TT_INCLUDE_CMD='.*'
TT_EXCLUDE_CMD=

trap on_exit exit

function on_exit {
  elapsed_time=$(($SECONDS - $TT_START_TIME))
  log::info "Total elapsed time: $elapsed_time seconds"
}

function log::info {
  # Cyan
  printf "${TT_COLOR_POINTER}➜ \033[0;36mINFO ${TT_COLOR_RESET}$@\n"
}

function log::warn {
  # Yellow
  printf "${TT_COLOR_POINTER}➜ \033[0;33mWARN ${TT_COLOR_RESET}$@\n"
}

function log::error {
  # Red
  printf "${TT_COLOR_POINTER}➜ \033[0;31mERRO ${TT_COLOR_RESET}$@\n"
}

function tutorial::launch {
  # load custom shell scripts
  local file
  for file in `ls $TT_DIR/*.sh 2>/dev/null`; do . $file; done

  # launch one or more lessons
  local lesson=$1
  if [[ -f $TT_DIR/$lesson.md ]]; then
    # launch lesson using path to file
    tutorial::launch-lesson $lesson
  elif [[ -d $TT_DIR/$lesson ]]; then
    # launch tutorial and lessons using path to directory
    local files=($(find $TT_DIR/$lesson -name "*.md" -type f | sort))
    for file in ${files[@]}; do
      lesson=${file#"$TT_DIR/"}
      lesson=${lesson%".md"}
      tutorial::launch-lesson $lesson
    done
  else
    log::error "The specified tutorial '$1' can not be found."
    exit 1
  fi
}

function tutorial::launch-lesson {
  # mark the previous active lesson as questionable
  sed -e "s#^*#?#g" $TT_PROGRESS_FILE > $TT_PROGRESS_FILE.tmp
  mv $TT_PROGRESS_FILE{.tmp,}

  # mark the current lesson as active
  local lesson=$1
  local file=$TT_DIR/$1.md
  if cat $TT_PROGRESS_FILE | grep -q -e "^.\? $file"; then
    sed -e "s#^? $file#* $file#g" \
        -e "s#^v $file#* $file#g" \
        -e "s#^  $file#* $file#g" \
      $TT_PROGRESS_FILE > $TT_PROGRESS_FILE.tmp
    mv $TT_PROGRESS_FILE{.tmp,}
  else
    echo "* $file" >> $TT_PROGRESS_FILE
  fi

  # start to parse lesson file
  if tutorial::parse-file $file; then
    # mark the current lesson as finished
    sed -e "s#^* $file#v $file#g" $TT_PROGRESS_FILE > $TT_PROGRESS_FILE.tmp
    mv $TT_PROGRESS_FILE{.tmp,}
  else
    log::error "The lesson '$lesson' cannot continue."
    exit 1
  fi
}

function tutorial::parse-file {
  # read lines into array
  local file=$1
  local line
  local lines=()
  while IFS= read -r line || [ -n "$line" ]; do
    lines+=("$line");
  done < $file
  lines+=("")

  # parse line by line
  local category
  local print_excerpt='not_started'
  for line in "${lines[@]}"; do
    if [[ $line =~ ^# ]]; then
      category='title'
    elif [[ $line =~ ^\`\`\`shell ]]; then
      category='code-shell'
      continue
    elif [[ $line =~ ^\`\`\` ]]; then
      [[ $category =~ code* ]] && category='' || category='code'
      continue
    elif [[ $line =~ ^\<!-- && ! $category =~ code* ]]; then
      category='code-invisible'
      continue
    elif [[ $line =~ --\>$ && $category == code-invisible ]]; then
      category=
      continue
    elif [[ -n $line && ! $category =~ code* ]]; then
      category='text'
    elif [[ -z $line ]]; then
      category='newline'
    fi

    case $category in
    title)
      # print title
      pi "$line"
      category=
      ;;
    text)
      # handle links
      line=$(echo "$line" | sed -e 's%!*\[\([^]]*\)\](\([^)]*\))%\1 (See \2)%g')

      # print text
      if [[ $print_excerpt == 'not_started' || $print_excerpt == 'in_progress' ]]; then
        # print excerpt
        print_excerpt='in_progress'
        DEMO_CMD_COLOR=$TT_COLOR_EXCERPT pi "$line"
      else
        # print normal text
        DEMO_CMD_COLOR=$TT_COLOR_RESET pi "$line"
      fi
      ;;
    code)
      # print code
      echo "$line"
      ;;
    code-shell)
      # print and execute shell command
      pe "$line"
      ;;
    code-invisible)
      # execute shell command
      eval "$line" || return $?
      ;;
    newline)
      # print new line
      DEMO_CMD_COLOR=$TT_COLOR_RESET pi ""

      # pause
      if [[ $print_excerpt != 'not_started' && $NO_WAIT == false ]]; then
        echo -e -n "${TT_COLOR_POINTER}➜ ${TT_COLOR_RESET}Press Enter key to continue..."
        read -rs
        echo
      fi

      if [[ $print_excerpt == 'in_progress' ]]; then
        print_excerpt='finished'
      fi
      ;;
    esac
  done
}

function pi {
  NO_WAIT=true p "$@"
}

function eval {
  if [[ -z $1 || ( $1 =~ $TT_INCLUDE_CMD && ! $1 =~ $TT_EXCLUDE_CMD ) ]]; then
    command eval $@
  else
    DEMO_CMD_COLOR=$TT_COLOR_RESET pi "command not found: $1"
  fi
}

function quit {
  TT_IN_CMD_LOOP=0
  TT_INCLUDE_CMD='.*'
  TT_EXCLUDE_CMD=
}

function tutorial::exec {
  while [[ $# -gt 0 ]]; do
    case "$1" in
    --include)
      TT_INCLUDE_CMD="quit|$2"
      shift
      shift
      ;;
    --exclude)
      TT_EXCLUDE_CMD=$2
      shift
      shift
      ;;
    *)
      shift
      ;;
    esac
  done

  echo -e "${TT_COLOR_POINTER}➜ ${TT_COLOR_RESET}You are in interactive mode where you can type and execute shell commands."
  echo -e "${TT_COLOR_POINTER}➜ ${TT_COLOR_RESET}Type 'quit' to exit and go forward."

  TT_IN_CMD_LOOP=1
  while [[ $TT_IN_CMD_LOOP == 1 ]]; do
    cmd
  done
}

function tutorial::depends {
  local lesson
  for lesson in $@; do
    local file="$TT_DIR/$lesson.md"
    if ! cat $TT_PROGRESS_FILE | grep -q -e "^v $file"; then
      log::error "The prerequisite lesson '$lesson' needs to be finished at first."
      return 1
    fi
  done
}

function var::input {
  local text=$1
  local var=$2

  echo -n -e "${TT_COLOR_QUESTION}? ${TT_COLOR_PROMPT}${text}${TT_COLOR_RESET}"

  local val=$(eval "echo \$$var")
  if [[ -n $val ]]; then
    echo -n -e "($val): "
  else
    echo -n -e ": "
  fi

  read -r val
  if [[ -n $val ]]; then
    eval "$var=$val"
  fi
}

function var::input-required {
  var::input "$@"

  local var=$2
  while [[ -z $(eval "echo \$$var") ]]; do
    var::input "$@"
  done
}

function var::store {
  local var=$1
  local val=$(eval "echo \$$var")
  if cat $TT_STATES_FILE | grep -q -e "^$var="; then
    sed -e "s#^$var=.*#$var=$val#g" $TT_STATES_FILE > $TT_STATES_FILE.tmp
    mv $TT_STATES_FILE{.tmp,}
  else
    echo "$var=$val" >> $TT_STATES_FILE
  fi
}

function tutorial::list {
  local files=($(find $TT_DIR/$lesson -name "*.md" -type f | sort))
  local file
  local line
  local state
  local lesson
  for file in ${files[@]}; do
    lesson=${file#"$TT_DIR/"}
    lesson=${lesson%".md"}

    line=`cat $TT_PROGRESS_FILE | grep -e "${lesson}.md$"`
    if [[ -n $line ]]; then
      state=${line:0:1}
    else
      state=''
    fi

    case $state in
    "*")
      echo -e "${TT_COLOR_ACTIVE} ➞  $lesson${TT_COLOR_RESET}"
      ;;
    "v")
      echo -e "${TT_COLOR_FINISH}[✓] $lesson${TT_COLOR_RESET}"
      ;;
    "?")
      echo -e "${TT_COLOR_UNKNOWN}[?] $lesson${TT_COLOR_RESET}"
      ;;
    *)
      echo -e "[ ] $lesson"
      ;;
    esac
  done
}

function usage {
  echo -e ""
  echo -e "Usage: $0 [options] [TUTORIAL_PATH|LESSON_PATH]"
  echo -e ""
  echo -e "\tWhere options is one or more of:"
  echo -e "\t-c\tShow command number on each line"
  echo -e "\t-d\tDebug mode. Disables simulated typing"
  echo -e "\t-h\tPrints Help text"
  echo -e "\t-l\tList all lessons with their states"
  echo -e "\t-n\tNo wait"
  echo -e "\t-w\tWaits max the given amount of seconds before proceeding with demo (e.g. '-w5')"
  echo -e ""
}

POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case $1 in
    -c)
      SHOW_CMD_NUMS=true
      shift
      ;;
    -d)
      unset TYPE_SPEED
      shift
      ;;
    -h)
      usage
      exit
      ;;
    -l)
      tutorial::list
      exit
      ;;
    -n)
      NO_WAIT=true
      shift
      ;;
    -w*)
      PROMPT_TIMEOUT=${1#-w}
      shift
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done

tutorial::launch "${POSITIONAL[@]}"
