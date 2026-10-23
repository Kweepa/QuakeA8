@echo off
setlocal
cd /d "%~dp0"

if exist "%~dp0setup-env.bat" call "%~dp0setup-env.bat"

set STEP=acme
if defined ACME if exist "%ACME%" goto run
where acme >nul 2>&1 && set ACME=acme && goto run
echo ACME not found. Set ACME in setup-env.bat
goto failed

:run
set STEP=gen_smc_tags
python tools\gen_smc_tags.py
if errorlevel 1 goto failed
set STEP=gentables
python tools\gentables.py
if errorlevel 1 goto failed
set STEP=genscreens
python tools\genscreens.py
if errorlevel 1 goto failed
set STEP=genlinebodies
python tools\genlinebodies.py
if errorlevel 1 goto failed
set STEP=genrotate
python tools\genrotate.py
if errorlevel 1 goto failed
set STEP=genuifont
python tools\genuifont.py
if errorlevel 1 goto failed
set STEP=genenemymuzzle
python tools\genenemymuzzle.py
if errorlevel 1 goto failed
set STEP=gensplat
python tools\gensplat.py
if errorlevel 1 goto failed
set STEP=gensounds
python tools\gensounds.py
if errorlevel 1 goto failed
set STEP=genenemies
python tools\genenemies.py
if errorlevel 1 goto failed
set STEP=genmap
python tools\genmap.py
if errorlevel 1 goto failed
set STEP=genitems
python tools\genitems.py
if errorlevel 1 goto failed
set STEP=genweapons
python tools\genweapons.py
if errorlevel 1 goto failed
set STEP=gen_menu_text
python tools\gen_menu_text.py
if errorlevel 1 goto failed
set STEP=gen_a8_cursor
python tools\gen_a8_cursor.py
if errorlevel 1 goto failed
set STEP=genpokey
python tools\genpokey.py
if errorlevel 1 goto failed

set STEP=acme enemy_data_blob.asm
pushd src
"%ACME%" enemy_data_blob.asm
if errorlevel 1 goto failed_pop
set STEP=acme tables.asm
"%ACME%" tables.asm
if errorlevel 1 goto failed_pop
set STEP=acme sqtab.asm
"%ACME%" sqtab.asm
if errorlevel 1 goto failed_pop
set STEP=acme uifont.asm
"%ACME%" uifont.asm
if errorlevel 1 goto failed_pop
popd

if exist src\enemydata.prg move /y src\enemydata.prg enemydata.prg >nul
if exist src\tab.prg move /y src\tab.prg tab.prg >nul
if exist src\sqt.prg move /y src\sqt.prg sqt.prg >nul
if exist src\fnt.prg move /y src\fnt.prg fnt.prg >nul

set STEP=acme overlay.asm
pushd src
"%ACME%" --vicelabels ..\overlay.lbl overlay.asm
if errorlevel 1 goto failed_pop
popd

set STEP=acme quake64.asm ai
pushd src
"%ACME%" -v3 --vicelabels ..\game-ai.lbl quake64.asm
if errorlevel 1 goto failed_pop
popd
set STEP=genaisymbols
python tools\genaisymbols.py --labels game-ai.lbl
if errorlevel 1 goto failed

set STEP=acme ai
pushd src
"%ACME%" --vicelabels ..\enemies\ai_grunt.lbl ai_grunt.asm
if errorlevel 1 goto failed_pop
"%ACME%" --vicelabels ..\enemies\ai_rott.lbl ai_rott.asm
if errorlevel 1 goto failed_pop
"%ACME%" --vicelabels ..\enemies\ai_knight.lbl ai_knight.asm
if errorlevel 1 goto failed_pop
"%ACME%" --vicelabels ..\enemies\ai_ogre.lbl ai_ogre.asm
if errorlevel 1 goto failed_pop
"%ACME%" --vicelabels ..\enemies\ai_scrag.lbl ai_scrag.asm
if errorlevel 1 goto failed_pop
"%ACME%" --vicelabels ..\enemies\ai_zombie.lbl ai_zombie.asm
if errorlevel 1 goto failed_pop
"%ACME%" --vicelabels ..\enemies\ai_crush.lbl ai_crush.asm
if errorlevel 1 goto failed_pop
"%ACME%" --vicelabels ..\enemies\ai_chthon.lbl ai_chthon.asm
if errorlevel 1 goto failed_pop
"%ACME%" --vicelabels ..\enemies\ai_shambl.lbl ai_shambler.asm
if errorlevel 1 goto failed_pop
"%ACME%" --vicelabels ..\enemies\ai_demon.lbl ai_demon.asm
if errorlevel 1 goto failed_pop
"%ACME%" --vicelabels ..\enemies\skel_draw.lbl skel_draw.asm
if errorlevel 1 goto failed_pop
popd
set STEP=genaimeta
python tools\genaimeta.py
if errorlevel 1 goto failed
set STEP=genaibanks
python tools\genaibanks.py
if errorlevel 1 goto failed
set STEP=checkaibanks
python tools\checkaibanks.py
if errorlevel 1 goto failed

set STEP=acme quake64.asm
pushd src
"%ACME%" -v3 --vicelabels ..\game.lbl quake64.asm
if errorlevel 1 goto failed_pop
"%ACME%" --vicelabels a8boot.lbl a8boot.asm
if errorlevel 1 goto failed_pop
popd
if exist src\game.prg move /y src\game.prg game.prg >nul

set STEP=mkreloc
python tools\mkreloc.py --labels game.lbl
if errorlevel 1 goto failed

set STEP=acme quake64.asm reloc
pushd src
"%ACME%" -v3 --vicelabels ..\game.lbl quake64.asm
if errorlevel 1 goto failed_pop
popd
if exist src\game.prg move /y src\game.prg game.prg >nul

set STEP=acme menu.asm
pushd src
"%ACME%" -v3 --vicelabels ..\menu.lbl menu.asm
if errorlevel 1 goto failed_pop
popd
if exist src\menu.prg move /y src\menu.prg menu.prg >nul

set STEP=genqsyms
python tools\genqsyms.py --labels game.lbl
if errorlevel 1 goto failed
set STEP=acme a8qsave.asm
pushd src
"%ACME%" -v3 --vicelabels ..\qsave.lbl a8qsave.asm
if errorlevel 1 goto failed_pop
popd
if exist src\qsave.prg move /y src\qsave.prg qsave.prg >nul

set STEP=mkatr
python tools\mkatr.py
if errorlevel 1 goto failed

set STEP=buildreport
python tools\buildreport.py
if errorlevel 1 goto failed

echo Built quake.atr
dir quake.atr
exit /b 0

:failed_pop
popd
:failed
python tools\buildreport.py --failed "%STEP%"
echo FAILED: %STEP%
exit /b 1
