sed -i 's/if(USE_BUNDLED_LIBUV)/if(FALSE)/' third-party/CMakeLists.txt

cat << "EOF" | patch -p1
diff -uNr neovim-master.orig/third-party/cmake/BuildLuajit.cmake neovim-master/third-party/cmake/BuildLuajit.cmake
--- neovim-master.orig/third-party/cmake/BuildLuajit.cmake	2020-06-06 16:37:51.000000000 +0300
+++ neovim-master/third-party/cmake/BuildLuajit.cmake	2020-06-07 17:37:57.494702634 +0300
@@ -29,6 +29,7 @@
       -DTARGET=${_luajit_TARGET}
       -DUSE_EXISTING_SRC_DIR=${USE_EXISTING_SRC_DIR}
       -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/DownloadAndExtractFile.cmake
+    PATCH_COMMAND "${LIBLUAJIT_PATCH_COMMAND}"
     CONFIGURE_COMMAND "${_luajit_CONFIGURE_COMMAND}"
     BUILD_IN_SOURCE 1
     BUILD_COMMAND "${_luajit_BUILD_COMMAND}"
@@ -42,6 +43,9 @@
   endif()
 endfunction()
 
+set(LIBLUAJIT_PATCH_COMMAND COMMAND git -C ${DEPS_BUILD_DIR}/src/luajit apply
+    --ignore-whitespace ${CMAKE_CURRENT_SOURCE_DIR}/patches/luajit-tmpdir.patch)
+
 check_c_compiler_flag(-fno-stack-check HAS_NO_STACK_CHECK)
 if(CMAKE_SYSTEM_NAME MATCHES "Darwin" AND HAS_NO_STACK_CHECK)
   set(NO_STACK_CHECK "CFLAGS+=-fno-stack-check")
diff -uNr neovim-master.orig/third-party/patches/luajit-tmpdir.patch neovim-master/third-party/patches/luajit-tmpdir.patch
-- neovim-master.orig/third-party/patches/luajit-tmpdir.patch	1970-01-01 03:00:00.000000000 +0300
+++ neovim-master/third-party/patches/luajit-tmpdir.patch	2020-06-07 17:32:07.584702884 +0300
@@ -0,0 +1,29 @@
+diff -uNr LuaJIT-2.1.0-beta3/src/lib_os.c LuaJIT-2.1.0-beta3.mod/src/lib_os.c
+--- LuaJIT-2.1.0-beta3/src/lib_os.c	2017-05-01 22:03:01.000000000 +0300
++++ LuaJIT-2.1.0-beta3.mod/src/lib_os.c	2020-06-07 16:58:03.086422851 +0300
+@@ -81,9 +81,9 @@
+   return 0;
+ #else
+ #if LJ_TARGET_POSIX
+-  char buf[15+1];
++  char buf[sizeof("/data/data/com.termux/files/usr")+16];
+   int fp;
+-  strcpy(buf, "/tmp/lua_XXXXXX");
++  strcpy(buf, "/data/data/com.termux/files/usr/tmp/lua_XXXXXX");
+   fp = mkstemp(buf);
+   if (fp != -1)
+     close(fp);
+diff -uNr LuaJIT-2.1.0-beta3/src/lj_trace.c LuaJIT-2.1.0-beta3.mod/src/lj_trace.c
+--- LuaJIT-2.1.0-beta3/src/lj_trace.c	2017-05-01 22:03:01.000000000 +0300
++++ LuaJIT-2.1.0-beta3.mod/src/lj_trace.c	2020-06-07 16:58:42.242740925 +0300
+@@ -107,8 +107,8 @@
+   lj_assertX(startpc >= proto_bc(pt) && startpc < proto_bc(pt) + pt->sizebc,
+        "trace PC out of range");
+   lineno = lj_debug_line(pt, proto_bcpos(pt, startpc));
+   if (!fp) {
+-    char fname[40];
+-    sprintf(fname, "/tmp/perf-%d.map", getpid());
++    char fname[sizeof("/data/data/com.termux/files/usr")+40];
++    sprintf(fname, "/data/data/com.termux/files/usr/tmp/perf-%d.map", getpid());
+     if (!(fp = fopen(fname, "w"))) return;
+     setlinebuf(fp);
+   }
diff -uNr neovim-master.orig/third-party/cmake/BuildLuarocks.cmake neovim-master/third-party/cmake/BuildLuarocks.cmake
--- neovim-master.orig/third-party/cmake/BuildLuarocks.cmake	2020-06-06 16:37:51.000000000 +0300
+++ neovim-master/third-party/cmake/BuildLuarocks.cmake	2020-06-07 17:22:47.334703285 +0300
@@ -200,9 +200,7 @@
       list(APPEND LUV_DEPS libuv_host)
     endif()
     set(LUV_ARGS "CFLAGS=-O0 -g3 -fPIC")
-    if(USE_BUNDLED_LIBUV)
-      list(APPEND LUV_ARGS LIBUV_DIR=${HOSTDEPS_INSTALL_DIR})
-    endif()
+    list(APPEND LUV_ARGS LIBUV_DIR=/data/data/com.termux/files/usr)
     SET(LUV_PRIVATE_ARGS LUA_COMPAT53_INCDIR=${DEPS_BUILD_DIR}/src/lua-compat-5.3)
     add_custom_command(OUTPUT ${ROCKS_DIR}/luv
       COMMAND ${LUAROCKS_BINARY}
EOF
