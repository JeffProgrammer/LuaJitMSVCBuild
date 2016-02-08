@rem Script to build LuaJIT with MSVC.
@rem Copyright (C) 2005-2015 Mike Pall. See Copyright Notice in luajit.h
@rem Edited by Jeff Hutchinson Copyright (c) 2016. Same License as LuaJIT
@rem
@rem Either open a "Visual Studio .NET Command Prompt"
@rem (Note that the Express Edition does not contain an x64 compiler)
@rem -or-
@rem Open a "Windows SDK Command Shell" and set the compiler environment:
@rem     setenv /release /x86
@rem   -or-
@rem     setenv /release /x64
@rem
@rem Then cd to this directory and run this script.
@rem
@rem Jeff Edits:
@rem to build static CRC luaJIT libraries, type the following:
@rem msvcbuild static debug
@rem msvcbuild static ndebug

@rem Jeff: Store the current state, since we have to change to support windows XP in VS2015
@set oldInclude=%INCLUDE%
@set oldPath=%PATH%
@set oldLIB=%LIB%
@set oldCL=%CL%
@set oldLink=%LINK%

@rem Force VS140_xp toolset
@rem TODO: X64 support for XP/Server2003
@set INCLUDE=%ProgramFiles(x86)%\Microsoft SDKs\Windows\7.1A\Include;%INCLUDE%
@set PATH=%ProgramFiles(x86)%\Microsoft SDKs\Windows\7.1A\Bin;%PATH%
@set LIB=%ProgramFiles(x86)%\Microsoft SDKs\Windows\7.1A\Lib;%LIB%
@set CL=/D_USING_V140_SDK71_;%CL%
@set LINK=/SUBSYSTEM:CONSOLE,5.01 %LINK%

@rem Jeff: Check to make sure we have 2 command line arguments.
@if "%2" neq "" goto :GOOD
@echo You must set 2 command line args.
@echo First arg is static or dll
@echo Second arg is debug or ndebug
@goto :END

:GOOD
@rem Jeff: We are good to go with the script. Now show the args.
@rem And continue the program.
@echo Param 1: "%1"
@echo Param 2: "%2"

@echo off
rem Jeff: Set variable to use if we're static and debug
if "%2" == "debug" (
	if "%1" == "static" (
		echo Setting Debug Static Runtime /MTd
		set LJCRT=/MTd
	) else (
		echo Setting Debug DLL Runtime /MDd
		set LJCRT=/MDd		
	)
	set libDLLName=lua51_d.dll
	set libLibName=lua51_d.lib
) else (
	if "%1" == "static" (
		echo Setting Non-Debug Static Runtime /MT
		set LJCRT=/MT
	) else (
		echo Setting Non-Debug DLL Runtime /MD
		set LJCRT=/MD		
	)
	set libDLLName=lua51.dll
	set libLibName=lua51.lib
)
@echo on

@if not defined INCLUDE goto :FAIL

@setlocal
@set LJCOMPILE=cl /nologo /c /O2 /W3 /D_CRT_SECURE_NO_DEPRECATE
@set LJLINK=link /nologo
@set LJMT=mt /nologo
@set LJLIB=lib /nologo /nodefaultlib
@set DASMDIR=..\dynasm
@set DASM=%DASMDIR%\dynasm.lua
@set LJDLLNAME=%libDLLName%
@set LJLIBNAME=%libLibName%
@set ALL_LIB=lib_base.c lib_math.c lib_bit.c lib_string.c lib_table.c lib_io.c lib_os.c lib_package.c lib_debug.c lib_jit.c lib_ffi.c

%LJCOMPILE% host\minilua.c
@if errorlevel 1 goto :BAD
%LJLINK% /out:minilua.exe minilua.obj
@if errorlevel 1 goto :BAD
if exist minilua.exe.manifest^
  %LJMT% -manifest minilua.exe.manifest -outputresource:minilua.exe

@set DASMFLAGS=-D WIN -D JIT -D FFI -D P64
@set LJARCH=x64
@minilua
@if errorlevel 8 goto :X64
@set DASMFLAGS=-D WIN -D JIT -D FFI
@set LJARCH=x86
:X64
minilua %DASM% -LN %DASMFLAGS% -o host\buildvm_arch.h vm_x86.dasc
@if errorlevel 1 goto :BAD

%LJCOMPILE% /I "." /I %DASMDIR% host\buildvm*.c
@if errorlevel 1 goto :BAD
%LJLINK% /out:buildvm.exe buildvm*.obj
@if errorlevel 1 goto :BAD
if exist buildvm.exe.manifest^
  %LJMT% -manifest buildvm.exe.manifest -outputresource:buildvm.exe

buildvm -m peobj -o lj_vm.obj
@if errorlevel 1 goto :BAD
buildvm -m bcdef -o lj_bcdef.h %ALL_LIB%
@if errorlevel 1 goto :BAD
buildvm -m ffdef -o lj_ffdef.h %ALL_LIB%
@if errorlevel 1 goto :BAD
buildvm -m libdef -o lj_libdef.h %ALL_LIB%
@if errorlevel 1 goto :BAD
buildvm -m recdef -o lj_recdef.h %ALL_LIB%
@if errorlevel 1 goto :BAD
buildvm -m vmdef -o jit\vmdef.lua %ALL_LIB%
@if errorlevel 1 goto :BAD
buildvm -m folddef -o lj_folddef.h lj_opt_fold.c
@if errorlevel 1 goto :BAD

@rem Jeff: Changed from %1 to %2 as we specify second param as debug
@if "%2" neq "debug" goto :NODEBUG
@rem Let's output that we are doing a debug build
@echo Performing debug build.

@set LJCOMPILE=%LJCOMPILE% /Zi
@set LJLINK=%LJLINK% /debug
:NODEBUG
@if "%1"=="amalg" goto :AMALGDLL
@if "%1"=="static" goto :STATIC
@echo NON STATIC BUILD
@rem Jeff: CRT detection
%LJCOMPILE% %LJCRT% /DLUA_BUILD_AS_DLL lj_*.c lib_*.c
@if errorlevel 1 goto :BAD
%LJLINK% /DLL /out:%LJDLLNAME% lj_*.obj lib_*.obj
@if errorlevel 1 goto :BAD
@goto :MTDLL
:STATIC
@rem Jeff: Added CRT here
@echo COMPILING STATIC BUILD
%LJCOMPILE% %LJCRT% lj_*.c lib_*.c
@if errorlevel 1 goto :BAD
%LJLIB% /OUT:%LJLIBNAME% lj_*.obj lib_*.obj
@if errorlevel 1 goto :BAD
@goto :MTDLL
:AMALGDLL
@rem Jeff: CRT detection
%LJCOMPILE% %LJCRT% /DLUA_BUILD_AS_DLL ljamalg.c
@if errorlevel 1 goto :BAD
%LJLINK% /DLL /out:%LJDLLNAME% ljamalg.obj lj_vm.obj
@if errorlevel 1 goto :BAD
:MTDLL
if exist %LJDLLNAME%.manifest^
  %LJMT% -manifest %LJDLLNAME%.manifest -outputresource:%LJDLLNAME%;2

%LJCOMPILE% luajit.c
@if errorlevel 1 goto :BAD
%LJLINK% /out:luajit.exe luajit.obj %LJLIBNAME%
@if errorlevel 1 goto :BAD
if exist luajit.exe.manifest^
  %LJMT% -manifest luajit.exe.manifest -outputresource:luajit.exe

@del *.obj *.manifest minilua.exe buildvm.exe
@echo.
@echo === Successfully built LuaJIT for Windows/%LJARCH% ===

@goto :END
:BAD
@echo.
@echo *******************************************************
@echo *** Build FAILED -- Please check the error messages ***
@echo *******************************************************
@goto :END
:FAIL
@echo You must open a "Visual Studio .NET Command Prompt" to run this script
:END

@rem Jeff: Reset Paths to the old state
@set INCLUDE=%oldInclude%
@set PATH=%oldPath%
@set LIB=%oldLIB%
@set CL=%oldCL%
@set LINK=%oldLink%