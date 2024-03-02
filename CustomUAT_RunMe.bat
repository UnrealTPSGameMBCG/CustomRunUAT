@echo off

rem ## This script calls CustomRunUAT.bat to force-build UAT and then it runs with BuildCookRun params
rem ## Originally it wa created to test fix in UAT (https://github.com/EpicGames/UnrealEngine/pull/11567)
rem ## 
rem ##  Put this script at the same directory as normal RunUAT.bat (i.e. to Engine/Build/BatchFiles/CustomRunUAT.bat)
rem ## 
rem ##  "-compile" forces using BuildUAT.bat
rem ##  .. use it after changing AutomationTools source files.
rem ##  .. don't call BuildCoocRun in the same call where you use "-compile"
rem ##  Use "-ubtargs=-UnoptimizedCode" to build unoptimized version of your UE project


set /P choice=Do you want to run this script (Did you check the hardcoded parameters?) (Y/N)?
if /I "%choice%"=="Y" (
    :: We need to call CustomRunUAT.bat "-compile" as a separate command
    call "%~dp0CustomRunUAT.bat" -compile 

    :: it will use the version of UAT that we built above
    if %errorlevel% equ 0 (
        echo MYMSG: Will run BuildCookRun now...

        call "%~dp0CustomRunUAT.bat" -nocompileuat ^
        BuildCookRun ^
        -project="c:\Users\michael\Documents\Unreal Projects\FixUAT\FixUAT.uproject" ^
        -platform="Win64" ^
        -clientconfig="Development" ^
        -build -cook -ubtargs=-UnoptimizedCode -noturnkeyvariables 
    ) else (
        echo MYERROR: Custom UAT was not built. BuildCookRun will not run...
    )   

    pause
) else (
    echo Exiting...
    exit /B 1
)

