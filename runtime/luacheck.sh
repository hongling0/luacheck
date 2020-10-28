#!/bin/bash
export LUACHECKROOT=$(
	cd $(dirname $0)
	pwd
)
cd ${LUACHECKROOT} && ${LUACHECKROOT}/lua ${LUACHECKROOT}/luacheck.lua --codes --ranges --std=lua54 $@