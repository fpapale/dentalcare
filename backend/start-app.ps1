$env:JAVA_HOME='C:\Users\rtm473\.jdk\jdk-21.0.10'
$env:PATH = 'C:\Users\rtm473\.jdk\jdk-21.0.10\bin;' + $env:PATH

Set-Location 'D:\dentalcare\backend'

Write-Output "Starting DentalCare API..."
Write-Output "Java: $(java -version 2>&1 | Select-Object -First 1)"
Write-Output ""

java -jar target\dentalcare-api-0.0.1-SNAPSHOT.jar
