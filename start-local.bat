@echo off
REM DentalCare API - Local Startup Script with H2 Database

REM Set Java 21 LTS JDK
set JAVA_HOME=C:\Users\rtm473\.jdk\jdk-21.0.10
set PATH=%JAVA_HOME%\bin;%PATH%

REM Display header
echo.
echo ===============================================
echo       DentalCare API - Local Test Launch
echo ===============================================
echo.
echo Java Version:
java -version
echo.
echo Starting DentalCare API...
echo URL: http://localhost:8080
echo H2 Console: http://localhost:8080/h2-console
echo.
echo [Press Ctrl+C to stop]
echo ===============================================
echo.

cd /d D:\dentalcare\backend

REM Run the JAR with H2 database (no PostgreSQL needed)
java -jar target\dentalcare-api-0.0.1-SNAPSHOT.jar

pause
