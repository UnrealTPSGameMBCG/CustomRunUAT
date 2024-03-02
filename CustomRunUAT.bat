rem ## Unreal Engine AutomationTool setup script 
rem ## Modified to force build UAT from source
rem ##
rem ## This script is expecting to exist in the Engine/Build/BatchFiles directory.  It will not work correctly
rem ## if you copy it to a different location and run it.

setlocal EnableExtensions
echo Running AutomationTool...

rem Uppercase the drive letter
set DRIVE_LETTER=%~d0
FOR %%Z IN (A B C D E F G H I J K L M N O P Q R S T U V W X Y Z) DO (
	IF /I %DRIVE_LETTER%==%%Z: SET DRIVE_LETTER=%%Z:
)

set SCRIPT_DIR=%DRIVE_LETTER%%~p0
set UATExecutable=AutomationTool.dll
set UATDirectory=Binaries\DotNET\AutomationTool

rem ## Change the CWD to /Engine. 
pushd "%SCRIPT_DIR%..\..\"
if not exist Build\BatchFiles\CustomRunUAT.bat goto Error_BatchFileInWrongLocation


rem Unset some env vars that are set when running from VisualStudio that can cause it to look outside of the bundled .net
set VisualStudioDir=
set VSSKUEDITION=
rem Unset some others that don't cause errors, but could cause subtle differences between in-VS runs vs out-of-VS runs
set PkgDefApplicationConfigFile=
set VSAPPIDDIR=
set VisualStudioEdition=
set VisualStudioVersion=


set MSBUILD_LOGLEVEL=quiet
set FORCECOMPILE_UAT=
set NOCOMPILE_UAT=0
set SET_TURNKEY_VARIABLES=1

rem ## Check for any arguments handled by this script, being sensitive to any characters that are treated as delimiters by cmd.exe.
:ParseArguments
set ARGUMENT=%1
if not defined ARGUMENT goto ParseArguments_Done
set ARGUMENT=%ARGUMENT:"=%
if /I "%ARGUMENT%" == "-msbuild-verbose" set MSBUILD_LOGLEVEL=normal
if /I "%ARGUMENT%" == "-compile" set FORCECOMPILE_UAT=FORCE
if /I "%ARGUMENT%" == "-nocompileuat" set NOCOMPILE_UAT=1
if /I "%ARGUMENT%" == "-noturnkeyvariables" set SET_TURNKEY_VARIABLES=0
shift
goto ParseArguments
:ParseArguments_Done

rem ## Verify that dotnet is present
call "%SCRIPT_DIR%GetDotnetPath.bat"
if errorlevel 1 goto Error_NoDotnetSDK

rem ## Use the pre-compiled UAT scripts if -nocompile is specified in the command line
if %NOCOMPILE_UAT%==1 goto RunPrecompiled

:: mike: we don't want precompiled by default, we need to build our own
::rem ## If we're running in an installed build, default to precompiled
::if exist Build\InstalledBuild.txt goto RunPrecompiled

:: mike: COP: I don't understand why this was originally in the RunUAT.bat
::rem ## check for force precompiled
::if not "%ForcePrecompiledUAT%"=="" goto RunPrecompiled

:: mike: COP: processing these cases below. Original version is left for reference
::rem ## check if the UAT projects are present. if not, we'll just use the precompiled ones.
::if not exist Source\Programs\AutomationTool\AutomationTool.csproj goto RunPrecompiled
::if not exist Source\Programs\AutomationToolLauncher\AutomationToolLauncher.csproj goto RunPrecompiled
rem ## mike: check if the UAT projects are present. if not, inform the user
if not exist Source\Programs\AutomationTool\AutomationTool.csproj (
    echo MYMSG: Source\Programs\AutomationTool\AutomationTool.csproj does not exist. Exiting.
	goto Exit_Failure
)
if not exist Source\Programs\AutomationToolLauncher\AutomationToolLauncher.csproj (
    echo MYMSG: Source\Programs\AutomationToolLauncher\AutomationToolLauncher.csproj does not exist. Exiting.
	goto Exit_Failure
)

call "%SCRIPT_DIR%BuildUAT.bat" %MSBUILD_LOGLEVEL% %FORCECOMPILE_UAT%
if errorlevel 1 goto Error_UATCompileFailed
echo MYMSG: BuildUAT.bat finished without errors

:: mike: this script does not support compiling UAT (using "-compile") and running the just compiled UAT from the same call
:: therefore exit if this call was with "-compile"
:: call CustomRunUAT.bat in your script again if it's intended
if %FORCECOMPILE_UAT%==FORCE goto Exit

goto DoRunUAT

:RunPrecompiled

if not exist %UATDirectory%\%UATExecutable% goto Error_NoFallbackExecutable
echo MYMSG: Executable version of UAT is found. It will run now...
goto DoRunUAT

rem ## Run AutomationTool
:DoRunUAT
pushd %UATDirectory%
dotnet %UATExecutable% %*
popd
set RUNUAT_ERRORLEVEL=%ERRORLEVEL%

if %SET_TURNKEY_VARIABLES% == 0 goto SkipTurnkey

rem ## Turnkey needs to update env vars in the calling process so that if it is run multiple times the Sdk env var changes are in effect
if EXIST "%SCRIPT_DIR%..\..\Intermediate\Turnkey\PostTurnkeyVariables.bat" (
	rem ## We need to endlocal so that the vars in the batch file work. NOTE: Working directory from pushd will be UNDONE here, but since we are about to quit, it's okay. UAT errorlevel is preserved beyond the endlocal
	endlocal & set RUNUAT_ERRORLEVEL=%RUNUAT_ERRORLEVEL%
	echo Updating environment variables set by a Turnkey sub-process
	call "%SCRIPT_DIR%..\..\Intermediate\Turnkey\PostTurnkeyVariables.bat"
	del "%SCRIPT_DIR%..\..\Intermediate\Turnkey\PostTurnkeyVariables.bat"
	rem ## setlocal again so that any popd's etc don't have an effect on calling process
	setlocal
)
:SkipTurnkey

if not %RUNUAT_ERRORLEVEL% == 0 goto Error_UATFailed

rem ## Success!
goto Exit


:Error_BatchFileInWrongLocation
echo CustomRunUAT.bat ERROR: The batch file does not appear to be located in the /Engine/Build/BatchFiles directory.  This script must be run from within that directory.
set RUNUAT_EXITCODE=1
goto Exit_Failure

:Error_NoDotnetSDK
echo CustomRunUAT.bat ERROR: Unable to find a install of Dotnet SDK.  Please make sure you have it installed and that `dotnet` is a globally available command.
set RUNUAT_EXITCODE=1
goto Exit_Failure

:Error_NoFallbackExecutable
echo CustomRunUAT.bat ERROR: Visual studio and/or AutomationTool.csproj was not found, nor was Engine\Binaries\DotNET\AutomationTool\AutomationTool.dll. Can't run the automation tool.
set RUNUAT_EXITCODE=1
goto Exit_Failure

:Error_UATCompileFailed
echo CustomRunUAT.bat ERROR: AutomationTool failed to compile.
set RUNUAT_EXITCODE=1
goto Exit_Failure


:Error_UATFailed
set RUNUAT_EXITCODE=%RUNUAT_ERRORLEVEL%
goto Exit_Failure

:Exit_Failure
echo BUILD FAILED
popd
exit /B %RUNUAT_EXITCODE%

:Exit
rem ## Restore original CWD in case we change it
popd
exit /B 0
