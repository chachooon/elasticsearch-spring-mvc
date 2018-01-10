#!/bin/sh
# Init script for {{{ name }}}
# Maintained by {{{ author }}}
# Generated by pleaserun.
# Implemented based on LSB Core 3.1:
#   * Sections: 20.2, 20.3
#
### BEGIN INIT INFO
# Provides:          {{{ name }}}
# Required-Start:    $remote_fs $syslog
# Required-Stop:     $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: {{{ one_line_description }}}
# Description:       {{{ description }}}
### END INIT INFO

PATH=/sbin:/usr/sbin:/bin:/usr/bin
export PATH

name={{#escaped}}{{#safe_filename}}{{{ name }}}{{/safe_filename}}{{/escaped}}
program={{#escaped}}{{{ program }}}{{/escaped}}
args={{{ escaped_args }}}
pidfile="/var/run/$name.pid"
user="{{{user}}}"
group="{{{group}}}"
chroot="{{{chroot}}}"
chdir="{{{chdir}}}"
nice="{{{nice}}}"
{{#limit_coredump}}limit_coredump="{{{limit_coredump}}}"
{{/limit_coredump}}{{#limit_cputime}}limit_cputime="{{{limit_cputime}}}"
{{/limit_cputime}}{{#limit_data}}limit_data="{{{limit_data}}}"
{{/limit_data}}{{#limit_file_size}}limit_file_size="{{{limit_file_size}}}"
{{/limit_file_size}}{{#limit_locked_memory}}limit_locked_memory="{{{limit_locked_memory}}}"
{{/limit_locked_memory}}{{#limit_open_files}}limit_open_files="{{{limit_open_files}}}"
{{/limit_open_files}}{{#limit_user_processes}}limit_user_processes="{{{limit_user_processes}}}"
{{/limit_user_processes}}{{#limit_physical_memory}}limit_physical_memory="{{{limit_physical_memory}}}"
{{/limit_physical_memory}}{{#limit_stack_size}}limit_stack_size="{{{limit_stack_size}}}"{{/limit_stack_size}}

# If this is set to 1, then when `stop` is called, if the process has
# not exited within a reasonable time, SIGKILL will be sent next.
# The default behavior is to simply log a message "program stop failed; still running"
KILL_ON_STOP_TIMEOUT=0

# When loading default and sysconfig files, we use `set -a` to make
# all variables automatically into environment variables.
set -a
[ -r {{{default_file}}} ] && . {{{default_file}}}
[ -r {{{sysconfig_file}}} ] && . {{{sysconfig_file}}}
set +a

[ -z "$nice" ] && nice=0

trace() {
  logger -t "/etc/init.d/{{{name}}}" "$@"
}

emit() {
  trace "$@"
  echo "$@"
}

start() {
  {{! I do not use 'su' here to run as a different user because the process 'su'
      stays as the parent, causing our pidfile to contain the pid of 'su' not the
      program we intended to run. Luckily, the 'chroot' program on OSX, FreeBSD, and Linux
      all support switching users and it invokes execve immediately after chrooting. }}

  # Ensure the log directory is setup correctly.
  if [ ! -d "{{{ log_directory }}}" ]; then 
    mkdir "{{{ log_directory }}}"
    chown "$user":"$group" "{{{ log_directory }}}"
    chmod 755 "{{{ log_directory }}}"
  fi

  {{#prestart}}
  if [ "$PRESTART" != "no" ] ; then
    # If prestart fails, abort start.
    prestart || return $?
  fi
  {{/prestart}}

  # Setup any environmental stuff beforehand
  {{{ulimit_shell}}}

  # Run the program!
  {{#nice}}nice -n "$nice" \{{/nice}}
  chroot --userspec "$user":"$group" "$chroot" sh -c "
    {{{ulimit_shell}}}
    cd \"$chdir\"
    exec \"$program\" $args
  " >> {{{ log_path_stdout }}} 2>> {{{ log_path_stderr }}} &

  # Generate the pidfile from here. If we instead made the forked process
  # generate it there will be a race condition between the pidfile writing
  # and a process possibly asking for status.
  echo $! > $pidfile

  emit "$name started"
  return 0
}

stop() {
  # Try a few times to kill TERM the program
  if status ; then
    pid=$(cat "$pidfile")
    trace "Killing $name (pid $pid) with SIGTERM"
    kill -TERM $pid
    # Wait for it to exit.
    for i in 1 2 3 4 5 ; do
      trace "Waiting $name (pid $pid) to die..."
      status || break
      sleep 1
    done
    if status ; then
      if [ "$KILL_ON_STOP_TIMEOUT" -eq 1 ] ; then
        trace "Timeout reached. Killing $name (pid $pid) with SIGKILL.  This may result in data loss."
        kill -KILL $pid
        emit "$name killed with SIGKILL."
      else
        emit "$name stop failed; still running."
      fi
    else
      emit "$name stopped."
    fi
  fi
}

status() {
  if [ -f "$pidfile" ] ; then
    pid=$(cat "$pidfile")
    if ps -p $pid > /dev/null 2> /dev/null ; then
      # process by this pid is running.
      # It may not be our pid, but that's what you get with just pidfiles.
      # TODO(sissel): Check if this process seems to be the same as the one we
      # expect. It'd be nice to use flock here, but flock uses fork, not exec,
      # so it makes it quite awkward to use in this case.
      return 0
    else
      return 2 # program is dead but pid file exists
    fi
  else
    return 3 # program is not running
  fi
}

force_stop() {
  if status ; then
    stop
    status && kill -KILL $(cat "$pidfile")
  fi
}

{{#prestart}}
prestart() {
  {{{ prestart }}}

  status=$?

  if [ $status -gt 0 ] ; then
    emit "Prestart command failed with code $status. If you wish to skip the prestart command, set PRESTART=no in your environment."
  fi
  return $status
}
{{/prestart}}

case "$1" in
  force-start|start|stop|force-stop|restart)
    trace "Attempting '$1' on {{{name}}}"
    ;;
esac

case "$1" in
  force-start)
    PRESTART=no
    exec "$0" start
    ;;
  start)
    status
    code=$?
    if [ $code -eq 0 ]; then
      emit "$name is already running"
      exit $code
    else
      start
      exit $?
    fi
    ;;
  stop) stop ;;
  force-stop) force_stop ;;
  status)
    status
    code=$?
    if [ $code -eq 0 ] ; then
      emit "$name is running"
    else
      emit "$name is not running"
    fi
    exit $code
    ;;
  restart)
    {{#prestart}}if [ "$PRESTART" != "no" ] ; then
      prestart || exit $?
    fi{{/prestart}}
    stop && start
    ;;
  *)
    echo "Usage: $SCRIPTNAME {start|force-start|stop|force-start|force-stop|status|restart}" >&2
    exit 3
  ;;
esac

exit $?
