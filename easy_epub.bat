@echo off
cd /d %0\..

if "%1"=="" goto MSG

perl easy_epub.pl %1
echo Success !!
goto END

:MSG
echo Not found --- text-file

:END
pause