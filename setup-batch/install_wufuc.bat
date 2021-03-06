@echo off
title wufuc installer
:: Copyright (C) 2017 zeffy

:: This program is free software: you can redistribute it and/or modify
:: it under the terms of the GNU General Public License as published by
:: the Free Software Foundation, either version 3 of the License, or
:: (at your option) any later version.

:: This program is distributed in the hope that it will be useful,
:: but WITHOUT ANY WARRANTY; without even the implied warranty of
:: MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
:: GNU General Public License for more details.

:: You should have received a copy of the GNU General Public License
:: along with this program.  If not, see <http://www.gnu.org/licenses/>.

echo Copyright ^(C^) 2017 zeffy
echo This program comes with ABSOLUTELY NO WARRANTY.
echo This is free software, and you are welcome to redistribute it
echo under certain conditions; see COPYING.txt for details.
echo.

fltmc >nul 2>&1 || (
    echo This batch script requires administrator privileges. Right-click on
    echo %~nx0 and select "Run as administrator".
    goto :die
)

echo Checking system requirements...

if /I "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
    goto :is_x64
) else (
    if /I "%PROCESSOR_ARCHITEW6432%"=="AMD64" (
        goto :is_x64
    )
    if /I "%PROCESSOR_ARCHITECTURE%"=="x86" (
        goto :is_x86
    )
)
goto :unsupported_os

:is_x86
set "WINDOWS_ARCHITECTURE=x86"
set "wufuc_dll=%~dp0wufuc32.dll"
goto :dll_exists

:is_x64
set "WINDOWS_ARCHITECTURE=x64"
set "wufuc_dll=%~dp0wufuc64.dll"

:dll_exists
if exist "%wufuc_dll%" (
    goto :get_ver
)
echo ERROR - Could not find %wufuc_dll%!
echo.
echo This most likely means you tried to clone the repository.
echo Please download wufuc from here:  https://github.com/zeffy/wufuc/releases
echo.
echo If you are using an unstable AppVeyor build, it could also mean you
echo downloaded the wrong build of wufuc for your operating system. If this
echo is the case, you need to download the %WINDOWS_ARCHITECTURE% build instead.
echo.
echo AVG ^(and possibly other AV^) users:
echo This error could also mean that your anti-virus deleted or quarantined wufuc
echo in which case, you will need to make an exception and restore it.
goto :die

:get_ver
call :get_filever "%wufuc_dll%"
title wufuc installer - v%Version%

set "wufuc_xml=%~dp0wufuc.xml"

if exist "%wufuc_xml%" (
    goto :check_winver
)
echo ERROR - Could not find %wufuc_xml%!
echo.
echo This most likely means you didn't extract all the files from the archive.
echo.
echo Please extract all the files from wufuc_v%Version%.zip to a permanent
echo location like C:\Program Files\wufuc and try again.
goto :die

:check_winver
ver | findstr " 6\.1\." >nul && (
    echo Detected supported operating system: Windows 7 %WINDOWS_ARCHITECTURE%
    goto :check_unattended
)
ver | findstr " 6\.3\." >nul && (
    echo Detected supported operating system: Windows 8.1 %WINDOWS_ARCHITECTURE%
    goto :check_unattended
)

:unsupported_os
echo WARNING - Detected that you are using an unsupported operating system.
echo.
echo The ver command says that you are using:
ver
echo.
echo This patch only works on the following versions of Windows:
echo.
echo   - Windows 7   ^(x64 / x86^) [6.1.xxxx]
echo   - Windows Server 2008 R2  [6.1.xxxx]
echo   - Windows 8.1 ^(x64 / x86^) [6.3.xxxx]
echo   - Windows Server 2012 R2  [6.3.xxxx]
echo.
echo If you're absolutely certain that you are using a supported operating system,
echo and that this warning is a mistake, you may continue with the patching process 
echo at your own peril.
goto :confirmation

:check_unattended
if [%1]==[] goto :confirmation
if /I "%1"=="/UNATTENDED" goto :uninstall
shift
goto :check_unattended

:confirmation
echo.
echo wufuc disables the "Unsupported Hardware" message in Windows Update, 
echo and allows you to continue installing updates on Windows 7 and 8.1
echo systems with Intel Kaby Lake, AMD Ryzen, or other unsupported processors.
echo.
echo Please be absolutely sure you really need wufuc before proceeding.
echo.
set /p CONTINUE=Enter 'Y' if you want to install wufuc: 
if /I not "%CONTINUE%"=="Y" goto :cancel
echo.

:install
sfc /SCANFILE="%systemroot%\System32\wuaueng.dll"
net start Schedule
set "wufuc_task=wufuc.{72EEE38B-9997-42BD-85D3-2DD96DA17307}"
schtasks /Create /XML "%wufuc_xml%" /TN "%wufuc_task%" /F
schtasks /Change /TN "%wufuc_task%" /TR "'%systemroot%\System32\rundll32.exe' """%wufuc_dll%""",Rundll32Entry"
schtasks /Change /TN "%wufuc_task%" /ENABLE
rundll32 "%wufuc_dll%",Rundll32Unload
net stop wuauserv
schtasks /Run /TN "%wufuc_task%"

timeout /nobreak /t 3 >nul
net start wuauserv

echo.
echo Installed and started wufuc, you can now continue installing updates! :^)
echo.
echo To uninstall, run uninstall_wufuc.bat as administrator.
goto :die

:die
echo.
echo Press any key to exit...
pause >nul
exit

:cancel
echo.
echo Canceled by user, press any key to exit...
pause >nul
exit

:get_filever  file
set "file=%~1"
for /f "tokens=*" %%i in ('wmic /output:stdout datafile where "name='%file:\=\\%'" get Version /value ^| find "="') do set "%%i"

exit /b
