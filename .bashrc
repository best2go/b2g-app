#!/usr/bin/env bash

export PS1='\h:\w\$ '

alias ll='LC_COLLATE=C ls -alF'
alias sf='bin/console'
alias xsf='XDEBUG_CONFIG="remote_enable=1 remote_host=host.docker.internal profiler_enable=0" sf'
alias xphp='XDEBUG_CONFIG="remote_enable=1 remote_host=host.docker.internal profiler_enable=0" php'

if [ -f ~/.bashrc.local ]; then
    . ~/.bashrc.local
fi
