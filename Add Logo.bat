@echo off
setlocal enabledelayedexpansion

REM 获取当前脚本所在目录
set "DIRECTORY=%~dp0"

REM 创建输出目录
set "OUTPUT_DIR=%DIRECTORY%output"
if not exist "%OUTPUT_DIR%" (
    mkdir "%OUTPUT_DIR%"
)

REM 遍历文件夹中的所有文件
for %%F in ("%DIRECTORY%\*") do (
    REM 检查是否为文件
    if exist "%%F" (
        REM 获取文件扩展名
        set "EXT=%%~xF"
        set "BASENAME=%%~nF"

        REM 转换扩展名为小写
        set "EXT=!EXT:.=!"
        set "EXT=!EXT:~0,4!"

        REM 处理图片文件
        if /I "!EXT!"=="jpg" (
            call :ProcessImage "%%F" "!BASENAME!" "!OUTPUT_DIR!"
        ) else if /I "!EXT!"=="bmp" (
            call :ProcessImage "%%F" "!BASENAME!" "!OUTPUT_DIR!"
        ) else if /I "!EXT!"=="png" (
            call :ProcessImage "%%F" "!BASENAME!" "!OUTPUT_DIR!"
        ) else if /I "!EXT!"=="webp" (
            call :ProcessImage "%%F" "!BASENAME!" "!OUTPUT_DIR!"
        )
    )
)

echo Processing complete!
goto :EOF

:ProcessImage
REM 参数: %1=原文件路径 %2=文件名(无扩展) %3=输出目录
echo Processing image: %~2
bin\ffmpeg -i "%~1" -vf "drawtext=fontfile='bin/Roboto-Bold.ttf':text='Image generated with AI':fontcolor=white@0.8:fontsize=24:x=W-tw-10:y=H-th-10" "%~3\%~2.png"
echo Image saved as: %~3\%~2.png
exit /b
