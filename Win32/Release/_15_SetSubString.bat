@echo off
setlocal
cd /d "%~dp0"

set "TEST_INI=%TEMP%\INIEx_SetSubString_Test.ini"
set "RESULT_FILE=%TEMP%\INIEx_SetSubString_Result.txt"
copy /y "Test.ini" "%TEST_INI%" >nul
if errorlevel 1 goto :fail

echo [1] Update a value in an existing nested section
"%~dp0INIEx.exe" SetSubString /MainSec=Players "/SubSec=Player1|Stats" /Key=Level /Value=99 "%TEST_INI%"
if errorlevel 1 goto :fail
"%~dp0INIEx.exe" ReadSubString /o="%RESULT_FILE%" /MainSec=Players "/SubSec=Player1|Stats" /Key=Level "%TEST_INI%"
if errorlevel 1 goto :fail
set "ACTUAL="
set /p "ACTUAL="<"%RESULT_FILE%"
if not "%ACTUAL%"=="99" goto :fail

echo [2] Create a new nested section and write a value
"%~dp0INIEx.exe" SetSubString /MainSec=Players "/SubSec=Player3|Stats" /Key=Level /Value=1 "%TEST_INI%"
if errorlevel 1 goto :fail
"%~dp0INIEx.exe" ReadSubString /o="%RESULT_FILE%" /MainSec=Players "/SubSec=Player3|Stats" /Key=Level "%TEST_INI%"
if errorlevel 1 goto :fail
set "ACTUAL="
set /p "ACTUAL="<"%RESULT_FILE%"
if not "%ACTUAL%"=="1" goto :fail

goto :cleanup

:cleanup
del "%TEST_INI%" >nul 2>&1
del "%RESULT_FILE%" >nul 2>&1
echo.
echo All SetSubString checks passed.
pause
exit /b 0

:fail
echo.
echo SetSubString test failed. Check the command output above.
del "%TEST_INI%" >nul 2>&1
del "%RESULT_FILE%" >nul 2>&1
pause
exit /b 1
