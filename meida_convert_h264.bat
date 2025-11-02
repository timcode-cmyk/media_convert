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

        REM 处理视频文件
        if /I "!EXT!"=="mp4" (
            call :ProcessVideo "%%F" "!BASENAME!" "!OUTPUT_DIR!"
        ) else if /I "!EXT!"=="mkv" (
            call :ProcessVideo "%%F" "!BASENAME!" "!OUTPUT_DIR!"
        ) else if /I "!EXT!"=="avi" (
            call :ProcessVideo "%%F" "!BASENAME!" "!OUTPUT_DIR!"
        ) else if /I "!EXT!"=="mov" (
            call :ProcessVideo "%%F" "!BASENAME!" "!OUTPUT_DIR!"
        )

        REM 处理音频文件
        if /I "!EXT!"=="mp3" (
            call :ProcessAudio "%%F" "!BASENAME!" "!OUTPUT_DIR!"
        ) else if /I "!EXT!"=="aac" (
            call :ProcessAudio "%%F" "!BASENAME!" "!OUTPUT_DIR!"
        ) else if /I "!EXT!"=="flac" (
            call :ProcessAudio "%%F" "!BASENAME!" "!OUTPUT_DIR!"
        ) else if /I "!EXT!"=="ogg" (
            call :ProcessAudio "%%F" "!BASENAME!" "!OUTPUT_DIR!"
        ) else if /I "!EXT!"=="mpeg" (
            call :ProcessAudio "%%F" "!BASENAME!" "!OUTPUT_DIR!"
        ) else if /I "!EXT!"=="m4a" (
            call :ProcessAudio "%%F" "!BASENAME!" "!OUTPUT_DIR!"
        ) else if /I "!EXT!"=="aiff" (
            call :ProcessVideo "%%F" "!BASENAME!" "!OUTPUT_DIR!"
        )

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

:ProcessVideo
REM 参数: %1=原文件路径 %2=文件名(无扩展) %3=输出目录
echo Processing video: %~2
bin\ffmpeg -i "%~1" -c:v dnxhd -profile:v dnxhr_hq -c:a pcm_s16le "%~3\%~2_dnxhd.mov"
echo Video saved as: %~3\%~2_dnxhd.mov
exit /b

:ProcessAudio
REM 参数: %1=原文件路径 %2=文件名(无扩展) %3=输出目录
echo Processing audio: %~2
bin\ffmpeg -i "%~1" "%~3\%~2.wav"
echo Audio saved as: %~3\%~2.wav
exit /b

:ProcessImage
REM 参数: %1=原文件路径 %2=文件名(无扩展) %3=输出目录
echo Processing image: %~2
bin\ffmpeg -i "%~1" "%~3\%~2.png"
echo Image saved as: %~3\%~2.png
exit /b