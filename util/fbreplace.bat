@echo off

@rem #############################################################################################################
@rem #########    U P G R A D E     F I R E B I R D     I N S A N C E S     F R O M    S N A P S H O T   #########
@rem #############################################################################################################

@rem This batch tries to:
@rem 1. Stop all Firebird services which are specified in the setting variable %FB_SERVICES%.
@rem 2. Remove client libraries (fbclient.ddl) before any further action (exit if this fails),
@rem 3. For each of files from source snapshot folder %SNAPSHOT_DIR%, do:
@rem    3.1. If filename is 'firebird.conf' or 'databases.conf' than create backup of it in the target folder
@rem         (command: copy <name>.conf to <name>.conf.previous) in order to restore it after finish all job;
@rem         After backup will be created - replace <name>.conf with the same file from SNAPSHOT_DIR.
@rem    3.2. All other files - try to remove file with the same name in the <FB_HOME>, log if fault.
@rem    3.2. In case of successfully removed file - copy it from %SNAPSHOT_DIR%
@rem 4. Create SYSDBA/masterke account in each security3.fdb using gsec utility
@rem 5. Restore firebird.conf and databases.conf in <FB_HOME>: copy <name>.conf.previous <name>.conf
@rem 6. Start all Firebird services.
@rem 7. Obtain server versions via fbsvcmgr and display them.
@rem 8. Check log of its own job for text about failed removals of old files and output it.


setlocal enabledelayedexpansion enableextensions
set fbv=%1
if not .%1.==.25. if not .%1.==.30. goto no_vers

set tmp=%~n0.tmp
set log=%~n0.log
set zip=%~n0.fb-snapshot-%fbv%.7z
set pdb=%~n0.fb-snapshot-%fbv%.pdb.7z
if .%fbv%.==.25. (
  set url=http://web.firebirdsql.org/download/snapshot_builds/win/2.5/
  set FB_SERVICES=fb25_tmp
) else (
  set url=http://web.firebirdsql.org/download/snapshot_builds/win/3.0/
  set FB_SERVICES=fb30_tmp
)
set ptn4fbs=_x64.7z
set ptn4pdb=_x64_pdb.7z

del %log% 2>nul
del %tmp% 2>nul
del %zip% 2>nul
del %pdb% 2>nul

@rem check that 7-Zip is avaliable:
7za 1>>%log% 2>&1
findstr /i /c /b "7-Zip" %log% 1>nul 2>&1
if errorlevel 1 (
  del %log%
  echo.
  (
     echo 7za.exe - command line stand alone version of 7-Zip archiver - is required for this batch.
     echo Download it from: http://sourceforge.net/projects/sevenzip/files/7-Zip
  ) >>%log%
  type %log%
  goto end
)
del %log% 2>nul

wget --help 1>%log% 2>&1
findstr /i /b /c "GNU Wget" %log% 1>nul 2>&1
if errorlevel 1 (
  del %log%
  echo.
  echo msg=GNU Wget non-interactive network retriever - is required for this batch. >>%log%
  type %log%
  goto end
)


@rem --------------------------------------------------
@rem Download DIRECTORY content with Firebird snapshots
@rem --------------------------------------------------

wget.exe --tries=2 -o %log% --output-document=%tmp% %url%
if errorlevel 1 (
  echo FAILED to get directory content for %url%
  type %log%
  goto end
)

@rem findstr /i /c:"Firebird" %tmp% | findstr /i /c:"%ptn4fbs%"
set urlbak=%url%

for /f "tokens=4 delims=^>^<" %%a in ('findstr /i /c:"Firebird" %tmp% ^| findstr /i /c:"%ptn4fbs%"') do (
  set word=%%a
  call :trim word !word!
  if not .!word!.==.. (
    set url=!url!!word!
    set msg=Firebird snapshot to download URL: !url! 
    echo !msg!
    echo !msg! >>%log%
  )
)

if .%urlbak%.==.!url!. (
  set msg=FAILED to parse node in directory !urlbak! for pattern !ptn4fbs!
  echo !msg! >>%log%
  type %log%
  goto end
)

@rem ------------------------------
@rem Download Firebird .7z-snapshot
@rem ------------------------------

set run_cmd=wget.exe --tries=2 -o %log% --output-document=%zip% !url!

echo Download Firebird %fbv% snapshot.
echo !run_cmd!
echo !run_cmd! >> %log%
!run_cmd!

findstr %zip% %log% | findstr saved > nul
if errorlevel 1 (
  echo FAILED to download URL: !url! >>%log%
  type %log%
  goto end
) else (
  echo Downloaded OK.
)

(
  dir %zip% | findstr /i /c:%zip%
  7za t %zip% | findstr /i /c:"Everything is Ok" /c:"Files:" /c:"Size:" /c:"Compressed:"
) >>%log%

findstr /i /c:"Everything is Ok" %log% >nul

if errorlevel 1 (
  echo Downloaded archieve seems to be broken. >>%log%
  type %log%
  goto end
) else (
  echo Integrity test passed OK.
)

@rem -------------------------------------------------------------------------------------------------
@rem Download PDB files. One may need to send them together with FB process dump to FB developer team.
@rem NOTE: extracting of these files does not needed.
@rem -------------------------------------------------------------------------------------------------

set url=%urlbak%
for /f "tokens=4 delims=^>^<" %%a in ('findstr /i /c:"Firebird" %tmp% ^| findstr /i /c:"%ptn4pdb%"') do (
  set word=%%a
  call :trim word !word!
  if not .!word!.==.. (
    set url=!url!!word!
    set msg=Firebird PDB files download URL: !url! 
    echo !msg!
    echo !msg! >>%log%
  )
)

if .%urlbak%.==.!url!. (
  set msg=FAILED to parse node in directory !urlbak! for pattern !pdb!
  echo !msg! >>%log%
  type %log%
  @rem -- do NOT, it's not critical: goto end
)

set run_cmd=wget.exe --tries=2 -o %log% --output-document=%pdb% !url!

echo Download PDB files.
echo !run_cmd!
echo !run_cmd! >> %log%
!run_cmd!

@rem ---------------------  e x t r a c t i n g -----------------------

@rem Folder where downloaded snapshot files will be extracted:
set SNAPSHOT_DIR=%~dp0tmp4snapshot.%fbv%
md %SNAPSHOT_DIR% 2>nul

set msg=!time! Extracting files from %zip% to %SNAPSHOT_DIR%
echo !msg!
echo !msg!>>%log%
set run_cmd=7za x -y -o%SNAPSHOT_DIR% -mmt %zip%
echo !run_cmd!
echo !run_cmd! >>%log%

!run_cmd! 1>>%log% 2>&1

set msg=!time! Done.
echo !msg!
echo !msg!>>%log%

@rem #############################################################################################################
@rem ##########################  T R Y I N G    T O    S T O P    S E R V I C E S  ###############################
@rem #############################################################################################################
for /d %%s in ( %FB_SERVICES% ) do (
  echo %%s
  echo.>>%log%
  sc query FirebirdServer%%s | findstr /i /c:"STOPPED" 1>nul 2>&1
  if errorlevel 1 (
    set msg=Stopping service FirebirdServer%%s
    echo !msg!
    echo.>>%log%
    echo !msg!>>%log%
    set cmd_run=sc stop FirebirdServer%%s
    echo !cmd_run!
    echo !cmd_run!>>%log%
    sc stop FirebirdServer%%s 1>>%log% 2>&1
    echo Wait a few seconds. . .
    ping -n 3 127.0.0.1 1>nul
    :: became broken 10.06.2015 (instant reply instead of wait), the reason not found: ping -n 1 -w 2000 1.1.1.1 1>nul 2>&1
    echo Check that service is really stopped:>>%log%
    set cmd_run=sc query FirebirdServer%%s
    echo !cmd_run!
    echo !cmd_run!>>%log%
    sc query FirebirdServer%%s>>%log%
    sc query FirebirdServer%%s | findstr /i /c:"STOPPED" 1>nul 2>&1
    if errorlevel 1 (
      set msg=CAN NOT STOP SERVICE! Job terminated.
      echo !msg!
      echo !msg!>>%log%
      exit
    ) else (
      set msg=Service FirebirdServer%%s has been successfully stopped.
      echo !msg!
      echo.>>%log%
      echo !msg!>>%log%
    )
  ) else (
    set msg=Service already has been stopped.
    echo !msg!
    echo !msg!>>%log%
  )
  sc query FirebirdServer%%s>>%log%
)

@rem ########################################################################################################
@rem ####################  C R E A T E    T E M P    B A C K U P S   (.7Z)   A N D  #########################
@rem ####################  T R Y     T O    D E L E T E    F B C L I E N T . D L L  #########################
@rem ########################################################################################################

set archsuff=19000101000000
call :getFileDTS gen_vbs
call :getFileDTS get_dts %log% archsuff
call :getFileDTS del_tmp

for /d %%i in ( %FB_SERVICES% ) do (
  del %~n0.err 2>nul

  for /f "tokens=3" %%k in ('REG.EXE query HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\FirebirdServer%%i ^| findstr /i /c:"ImagePath"') do (
    set fn=%%k
    set fp=%%~dpk
    if .%fbv%.==.25. (
        for %%m in ("!fp:~0,-1!") do set fp=%%~dpm
    )
    @rem Remove trailing backslash:
    set fp=!fp:~0,-1!

    set msg=Home dir for %%i: !fp!
    echo ##########################################
    echo !msg!
    echo ##########################################
    echo.
    echo !msg!>>%log%
  )

  set archname=tmp.%~n0.backup.%%i.%archsuff%.7z
  echo Packing previous FB build to !archname!
  @rem '-ep1' =  excluse base path from arch names; '-idp' = do NOT show (and log) percents progress 

  echo !time! Packing previous FB build to !archname!>>%log%
  if .%fbv%.==.25. (
    set cmd_run=7za u -bd -r -ssw -mmt !archname! !fp!\bin !fp!\include !fp!\intl !fp!\lib !fp!\plugins !fp!\*.conf !fp!\firebird.msg !fp!\security*.fdb
  ) else (
    set cmd_run=7za u -bd -r -ssw -mmt !archname! !fp!\include !fp!\intl !fp!\lib !fp!\plugins !fp!\*.conf !fp!\*.dll !fp!\*.exe !fp!\*.bat !fp!\firebird.msg !fp!\security*.fdb
  )
  echo !time! !cmd_run!
  echo !time! !cmd_run!>>%log%
  cmd /c !cmd_run! 1>>%log% 2>&1

  echo Done.
  echo !time! Done.>>%log%
  dir /-c !archname! | findstr /i /c:!archname! 1>%~n0.err 2>&1
  type %~n0.err>>%log%
  type %~n0.err

  if .%fbv%.==.25. (
    set fn=!fp!\bin\fbclient.dll
  ) else (
    set fn=!fp!\fbclient.dll
  )
  if exist !fn! (
    set msg=Trying to delete !fn! - perhaps it can be loaded now by some app.
    echo !msg!
    echo !msg!>>%log%
    del !fn! 2>%~n0.err
    type %~n0.err>>%log%
    for /f "usebackq" %%A in ('%~n0.err') do set errsize=%%~zA
    if .!errsize!.==.. set errsize=0
    if !errsize! gtr 0 (
       echo dir /-c !fn!>>%log%
       dir /-c !fn! | findstr /i /c:fbclient.dll>>%log%
       set msg=File !fn! can not be deleted. Batch terminated.
       echo !msg!
       echo !msg!>>%log%
       del %~n0.err 2>nul
       exit
    )
    set msg=File !fn! has been successfully deleted.
    echo !msg!
    echo !msg!>>%log%
  ) else (
    set msg=Client library !fn! does not exist. Skip trying to delete it.
    echo !msg!
    echo !msg!>>%log%
  )
)
del %~n0.err 2>nul

@rem these files will be removed only after SUCCESSFUL finish of this batch: dir tmp.%~n0.backup.*.rar
:m1

@rem #############################################################################################################
@rem #################  C O P Y I N G     A L L    F I L E S    F R O M     S N A P S H O T ######################
@rem #############################################################################################################
for /d %%i in ( %FB_SERVICES% ) do (

  for /f "tokens=3" %%k in ('REG.EXE query HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\FirebirdServer%%i ^| findstr /i /c:"ImagePath"') do (
    @rem Image path of FB service ('drive:\path\firebird.exe'):
    set fn=%%k
    @rem Path to FB instance ('drive:\path\')
    set fp=%%~dpk
    if .%fbv%.==.25. (
        for %%m in ("!fp:~0,-1!") do set fp=%%~dpm
    )
    @rem Remove trailing backslash:
    set fp=!fp:~0,-1!

    echo Copying files from %SNAPSHOT_DIR% to !fp! 

    set cmd_run=copy %pdb% !fp!\*.*
    echo !cmd_run! 1>>%log%
    cmd /c !cmd_run! 1>>%log% 2>&1
    del %pdb% 1>>%log% 2>&1

    for /f %%a in ('dir /s /a-d /b %SNAPSHOT_DIR%') do (
      @rem set fn=%%~da%%~pa%%a
      set sn=%%a
      set sp=%%~da%%~pa

      @rem Replace in full path+filename from SNAPSHOT folder its PATH to the folder of currently processed FB instance:
      @rem set tp=!sn:%SNAPSHOT_DIR%\=%%~dpk!
      set tp=!sn:%SNAPSHOT_DIR%=%fp%!
      set skip=0
      if /i "%%~nxa"=="firebird.conf" set skip=1
      if /i "%%~nxa"=="databases.conf" set skip=1
      if /i "%%~nxa"=="aliases.conf" set skip=1

@rem echo sp=!sp! sn=!sn!
@rem echo tp=!tp!
@rem echo ~~~~~~~~~~~~~~~~~~~~~~~~
@rem echo skip=!skip!
@rem pause

      if .!skip!.==.1. (
        if exist !tp! (
          @rem Before replace firebird.conf and databases.conf we have to backup them.
          @rem After copying all files (and before starting services) these files (`firebird.conf`
          @rem and `databases.conf`) need to be renamed back.

          set cmd_run=copy !tp! !tp!.previous
          
          set msg=### CREATING BACKUP ### %%a
          echo !msg!>>%log%
          echo !time! !cmd_run!>>%log%

          cmd /c !cmd_run! 1>>%log% 2>&1
        )
        set copy_cmd=copy !sn! !tp!
        @rem echo !time! !copy_cmd!
        echo !time! !copy_cmd!>>%log%

        cmd /c !copy_cmd! 1>>%log% 2>&1

      ) else (
        del %~n0.err 2>nul
        if exist !tp! (
          set cmd_del=del !tp!
          echo !time! !cmd_del! 1>>%log%

          cmd /c !cmd_del! 2>%~n0.err
        )
        for /f "usebackq" %%A in ('%~n0.err') do set errsize=%%~zA
        if .!errsize!.==.. set errsize=0
        if !errsize! gtr 0 (
          set msg=### FAILED TO EXECUTE ### !cmd_del! - replacement could be incompleted.
          type %~n0.err>>%log%
          echo !msg!
          echo !msg!>>%log%
        ) else (
          set copy_cmd=copy !sn! !tp!
          @rem echo !time! !copy_cmd!
          echo !time! !copy_cmd!>>%log%
          cmd /c !copy_cmd! 1>>%log% 2>&1
        )
      )
    )
  )
)
del %~n0.tmp.vbs 2>nul

@rem #############################################################################################################
@rem #############################   C R E A T I N G    S Y S D B A    A C C O U N T  ############################
@rem #############################                        a n d                       ############################
@rem #############################   R E S T O R I N G     .c o n f    F I L E S      ############################
@rem #############################################################################################################

for /d %%s in ( %FB_SERVICES% ) do (
  for /f "tokens=3" %%k in ('REG.EXE query HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\FirebirdServer%%s ^| findstr /i /c:"ImagePath"') do (
    set fn=%%k
    set fp=%%~dpk
    if .%fbv%.==.25. (
        for %%m in ("!fp:~0,-1!") do set fp=%%~dpm
    )
    set fp=!fp:~0,-1!

    if .%fbv%.==.30. (
        set cmd_run=!fp!\gsec -user sysdba -pass 1 -add sysdba -pw masterke -database !fp!\security3.fdb
        echo !time! Trying to add SYSDBA into security database: !cmd_run!
        echo !cmd_run!
        echo !cmd_run!>>%log%

        echo !time! Check record: point BEFORE using gsec for add SYSDBA, instance: %%s>>%log%
        cmd /c !cmd_run! 1>%~n0.tmp  2>%~n0.err
        echo !time! Check record: point AFTER using gsec for add SYSDBA, instance: %%s>>%log%

        for /f "usebackq" %%A in ('%~n0.err') do set errsize=%%~zA
        if .!errsize!.==.. set errsize=0
        if !errsize! gtr 0 (
          set msg=### FAILED TO EXECUTE ### !cmd_run!.
          echo !msg!
          echo !msg!>>%log%
          type %~n0.err
          type %~n0.err>>%log%
        )
        type %~n0.tmp
        type %~n0.tmp>>%log%
        del %~n0.err 2>nul
        del %~n0.tmp 2>nul

        set cmd_run=!fp!\gsec -display -database !fp!\security3.fdb -user sysdba -pass masterke
        echo !time! Trying to display SYSDBA info:
        echo !cmd_run!
        echo !cmd_run!>>%log%
        
        echo !time! Check record: point BEFORE using gsec for display SYSDBA, instance: %%s>>%log%
        cmd /c !cmd_run! 1>%~n0.tmp 2>%~n0.err
        echo !time! Check record: point AFTER using gsec for display SYSDBA, instance: %%s>>%log%

        for /f "usebackq" %%A in ('%~n0.err') do set errsize=%%~zA
        if .!errsize!.==.. set errsize=0
        if !errsize! gtr 0 (
          set msg=### FAILED TO EXECUTE ### !cmd_run!.
          echo !msg!
          echo !msg!>>%log%
          type %~n0.err
          type %~n0.err>>%log%
        )

        type %~n0.tmp
        type %~n0.tmp>>%log%
        del %~n0.err 2>nul
        del %~n0.tmp 2>nul
    )
    @rem end of "if fbv==30"

    set msg=Restore files that was backed up before copying:
    echo !msg!
    echo !msg!>>%log%

    set cmd_run=copy !fp!\firebird.conf.previous !fp!\firebird.conf
    echo !time! !cmd_run!>>%log%
    cmd /c !cmd_run! 1>>%log%

    set cmd_run=copy !fp!\databases.conf.previous !fp!\databases.conf
    echo !time! !cmd_run!>>%log%
    cmd /c !cmd_run! 1>>%log%
  )
)

@rem #############################################################################################################
@rem ################################   S T A R T I N G     S E R V I C E S    ###################################
@rem #############################################################################################################
for /d %%s in ( %FB_SERVICES% ) do (
  set msg=Starting service FirebirdServer%%s
  echo !msg!
  echo.>>%log%
  echo !msg!>>%log%
  
  echo !time! Check record: point BEFORE starting instance: %%s>>%log%
  
  sc start FirebirdServer%%s 1>>%log% 2>&1

  echo !time! Check record: point AFTER starting  instance: %%s>>%log%

  ping -n 1 -w 800 1.1.1.1 1>nul 2>&1
  echo After pause:>>%log%

  sc query FirebirdServer%%s 1>>%log% 2>&1
  sc query FirebirdServer%%s | findstr /i /c:"RUNNING" 1>nul 2>&1
  if errorlevel 1 (
    set msg=### FAILED TO EXECUTE ### start service command.
  ) else (
    set msg=Service has been successfully started.
  )
  echo !msg!
  echo !msg!>>%log%

)

@rem #############################################################################################################
@rem ###########################   O B T A I N    S E R V E R    V E R S I O N S   ###############################
@rem #############################################################################################################
for /d %%s in ( %FB_SERVICES% ) do (
  for /f "tokens=3" %%k in ('REG.EXE query HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\FirebirdServer%%s ^| findstr /i /c:"ImagePath"') do (
    set fn=%%k
    set fp=%%~dpk
    set fp=!fp:~0,-1!

    set cmd_run=!fp!\fbsvcmgr localhost:service_mgr user SYSDBA password masterke info_server_version
    set msg=Trying to obtain server version for service %%s
    echo !msg!
    echo !msg!>>%log%
    echo !cmd_run!>>%log%

    echo !time! Check record: point BEFORE get server version, instance: %%s>>%log%
    cmd /c !cmd_run! 1>%~n0.tmp 2>%~n0.err
    echo !time! Check record: point AFTER get server version, instance: %%s>>%log%

    for /f "usebackq" %%A in ('%~n0.err') do set errsize=%%~zA
    if .!errsize!.==.. set errsize=0
    if !errsize! gtr 0 (
      set msg=### FAILED TO EXECUTE ### !cmd_run!.
      echo !msg!
      echo !msg!>>%log%
      type %~n0.err
      type %~n0.err>>%log%
    )
    type %~n0.tmp
    echo.>>%log%
    type %~n0.tmp>>%log%
    echo.>>%log%

    if .%fbv%.==.25. (
        set fp=%%~dpk
        for %%m in ("!fp:~0,-1!") do set fp=%%~dpm
        set fp=!fp:~0,-1!
    )

    (
      echo This FB instance has been downloaded from:
      echo !url!
      echo Replacement was done by %~nf0 at !date! !time!
      type %~n0.tmp 
    ) > !fp!\firebird.log

    del %~n0.err 2>nul
    del %~n0.tmp 2>nul
  )
)

findstr /i /c:"FAILED TO EXECUTE" %log% 1>%~n0.err 2>nul
if errorlevel 1 (
  echo.
  echo No faults occured during replacement files.
  @echo Now we can remove temp files.

  set cmd_del=del !archname!
  echo !time! !cmd_del! 1>>%log%
  cmd /c !cmd_del! 1>>%log% 2>&1

  set cmd_del=del %zip%
  echo !time! !cmd_del! 1>>%log%
  cmd /c !cmd_del! 1>>%log% 2>&1

  set cmd_del=rd /s /q %SNAPSHOT_DIR%
  echo !time! !cmd_del! 1>>%log% 2>&1
  cmd /c !cmd_del! 1>>%log% 2>&1

) else (
  (
    echo.
    echo ::: ACHTUNG :::
    echo.
    echo At least one error occured, replacement is INCOMPLETE. 
    echo You can restore previous FB instances from backups:

    dir /-c tmp.%~n0.backup.*.7z | findstr /c:".7z"

    echo FAILED commands:
    type %~n0.err
  ) > %tmp%
  type %tmp%
  type %tmp% >>%log%
  exit
)
del %~n0.err 2>nul
echo.
echo Check log in the file: %log%
echo.
goto end

:getFileDTS
  @rem http://www.dostips.com/DtTutoFunctions.php
    set vbs=%~n0.tmp.vbs
    set dts=%~n0.tmp.log
    if /i .%1.==.gen_vbs. (
      del %vbs% 2>nul
      echo 'Created auto, do NOT edit! >>%vbs%
      echo 'Used to obtain exact timestamp of file >>%vbs%
      echo 'Usage: cscript ^/^/nologo %vbs% ^<file^> >>%vbs%
      echo 'Result: last modified timestamp, in format: YYYYMMDDhhmiss >>%vbs%
      echo Set objFS ^= CreateObject("Scripting.FileSystemObject"^) >>%vbs%
      echo Set objArgs ^= WScript.Arguments >>%vbs%
      echo strFile ^= objArgs(0^) >>%vbs%
      echo ts ^= timeStamp(objFS.GetFile(strFile^).DateLastModified^) >>%vbs%
      echo WScript.Echo ts >>%vbs%
      echo. >>%vbs%
      echo Function timeStamp( d ^) >>%vbs%
      echo   timeStamp ^= Year(d^) ^& _ >>%vbs%
      echo   Right("0" ^& Month(d^),2^) ^& _ >>%vbs%
      echo   Right("0" ^& Day(d^),2^)  ^& _ >>%vbs% 
      echo   Right("0" ^& Hour(d^),2^) ^& _ >>%vbs%
      echo   Right("0" ^& Minute(d^),2^) ^& _ >>%vbs%
      echo   Right("0" ^& Second(d^),2^) >>%vbs%
      echo End Function >>%vbs%
      endlocal&goto:eof
    )
    if /i .%1.==.get_dts. (
      @rem echo|set /p=Obtaining timestamp of %2... 
      cscript //nologo %vbs% %2 1>%dts%
      @rem type %dts%
      set /p %~3=<%dts%
      del %dts% 2>nul
    )
    if /i .%1.==.del_tmp. (
      del %vbs% 2>nul
    )
  endlocal
goto:eof

:trim
    setLocal
    @rem EnableDelayedExpansion
    set Params=%*
    for /f "tokens=1*" %%a in ("!Params!") do endLocal & set %1=%%b
goto:eof

:no_vers
    echo Syntax: %~n0.bat ^<firebird_version^>
    echo Where:  ^<firebird_version^> = 25 ^| 30
    echo Press any key. . .
    pause >nul
:end
