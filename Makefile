.PHONY:clean
.PHONY:default
RUNTIME=runtime
RUNTIME_CLIB=$(RUNTIME)/luaclib
RUNTIME_LIB=$(RUNTIME)/lualib
SHARED:=-fPIC --shared
LUA_PATH=3rd/lua
CFLAGS=-g -O2 -Wall -I$(LUA_PATH)

default: luacheck 3rd

$(RUNTIME_CLIB):
	mkdir -p $(RUNTIME_CLIB)

$(RUNTIME_LIB):
	mkdir -p $(RUNTIME_LIB)

LANES_SRC=$(wildcard 3rd/lanes/src/*.c)
$(RUNTIME_CLIB)/lanes.so: $(LANES_SRC) | $(RUNTIME_CLIB)
	$(CC) -std=gnu99 $(CFLAGS) $(SHARED) -lpthread $^ -o $@ -Wimplicit-function-declaration

$(RUNTIME_LIB)/lanes.lua:3rd/lanes/src/lanes.lua | $(RUNTIME_LIB)
	cp $< $@

$(RUNTIME_CLIB)/lfs.so:3rd/luafilesystem/src/lfs.c | $(RUNTIME_CLIB)
	$(CC) -std=gnu99 $(CFLAGS) $(SHARED)  $^ -o $@ -Waggregate-return -Wcast-align -Wmissing-prototypes -Wnested-externs -Wshadow -Wwrite-strings -pedantic

$(RUNTIME_LIB)/argparse.lua:3rd/argparse/src/argparse.lua | $(RUNTIME_LIB)
	cp $< $@

$(RUNTIME)/lua: $(LUA_PATH)/lua
	cp $< $@

$(LUA_PATH)/lua:
	make -C $(LUA_PATH)

3rd: $(RUNTIME_CLIB)/lanes.so $(RUNTIME_LIB)/lanes.lua $(RUNTIME_LIB)/argparse.lua $(RUNTIME_CLIB)/lfs.so $(RUNTIME)/lua

luacheck: $(RUNTIME_LIB)/luacheck

$(RUNTIME_LIB)/luacheck: | $(RUNTIME_LIB)
	cp src/luacheck $(RUNTIME_LIB)/luacheck -r

clean:
	rm -rf $(RUNTIME_LIB)
	rm -rf $(RUNTIME_CLIB)
	rm -rf $(RUNTIME)/lua
	make -C $(LUA_PATH) clean

.PHONY: default clean