@echo off
setlocal
cd /d "%~dp0"

set "TEST_INI=%TEMP%\INIEx_SetString_Test.ini"
copy /y "Test.ini" "%TEST_INI%" >nul
if errorlevel 1 goto :fail

echo [1] Update an existing key in an existing section
"%~dp0INIEx.exe" SetString /Sec=General /Key=Name "/Value=Updated Name" "%TEST_INI%"
if errorlevel 1 goto :fail
set "ACTUAL="
for /f "delims=" %%A in ('"%~dp0INIEx.exe" ReadString /Sec=General /Key=Name "%TEST_INI%"') do set "ACTUAL=%%A"
if not "%ACTUAL%"=="Updated Name" goto :fail

echo [2] Add a new key to an existing section
"%~dp0INIEx.exe" SetString /Sec=General /Key=AddedKey /Value=AddedValue "%TEST_INI%"
if errorlevel 1 goto :fail
set "ACTUAL="
for /f "delims=" %%A in ('"%~dp0INIEx.exe" ReadString /Sec=General /Key=AddedKey "%TEST_INI%"') do set "ACTUAL=%%A"
if not "%ACTUAL%"=="AddedValue" goto :fail

echo [3] Create a new section and write a key
"%~dp0INIEx.exe" SetString /Sec=Generated /Key=Author /Value=INIEx "%TEST_INI%"
if errorlevel 1 goto :fail
set "ACTUAL="
for /f "delims=" %%A in ('"%~dp0INIEx.exe" ReadString /Sec=Generated /Key=Author "%TEST_INI%"') do set "ACTUAL=%%A"
if not "%ACTUAL%"=="INIEx" goto :fail

del "%TEST_INI%" >nul 2>&1
echo.
echo All SetString checks passed.
pause
exit /b 0

:fail
echo.
echo SetString test failed. Check the command output above.
if exist "%TEST_INI%" del "%TEST_INI%" >nul 2>&1
pause
exit /b 1
