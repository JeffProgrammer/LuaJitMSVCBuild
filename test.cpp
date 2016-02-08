// Copyright (c) 2016 Jeff Hutchinson
// LICENSE: MIT

#include <iostream>

extern "C" {
	#include <lua.h>
	#include <lauxlib.h>
	#include <lualib.h>
};

int main() {
	lua_State *lua = lua_open();
	luaopen_base(lua);
	luaopen_table(lua);
	luaopen_io(lua);
	luaopen_string(lua);
	luaopen_math(lua);

	luaL_dostring(lua, "print(1 + 2);");

#ifdef _WIN32
	system("PAUSE");
#endif

	lua_close(lua);
	return 0;
}