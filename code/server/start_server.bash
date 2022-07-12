#!/usr/bin/env bash

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"

# ALLARGS=( "$@" )

cd "$DIR"

nthread=`grep -Eo "SCHEDULER_MAX_CPU *= *[0-9]*" config/Config.jl | tail -n1 | grep -Eo "[0-9]*"`

if [[ -f config/config.secret.jl ]]
then
  if [[ `grep -Eo "SCHEDULER_MAX_CPU *= *[0-9]*" config/config.secret.jl | wc -l` -eq 1 ]]
  then
    nthread=`grep -Eo "SCHEDULER_MAX_CPU *= *[0-9]*" config/config.secret.jl | grep -Eo "[0-9]*"`
  fi
fi
# nthread=`echo "20+$nthread" | bc`
echo "Clasnip server with $nthread threads."
julia --project=. --threads=$nthread -i --banner=no --color=yes start_server.jl "$@"
