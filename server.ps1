# PowerShell Static Web Server
$port = 8080
$localPath = $PSScriptRoot
if (-not $localPath) { $localPath = Get-Location }

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$port/")
$listener.Start()

Write-Host "Server running at http://localhost:$port/"
Write-Host "Press Ctrl+C to stop the server."

try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response

        $url = $request.RawUrl.Split('?')[0]
        if ($url -eq '/') { $url = '/index.html' }

        # Remove leading slash and resolve path safely
        $cleanUrl = $url.TrimStart('/')
        $filePath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($localPath, $cleanUrl))

        # Security check: ensure file is inside $localPath
        if (-not $filePath.StartsWith($localPath, [System.StringComparison]::OrdinalIgnoreCase)) {
            $response.StatusCode = 403
            $bytes = [System.Text.Encoding]::UTF8.GetBytes("403 Forbidden")
            $response.OutputStream.Write($bytes, 0, $bytes.Length)
            $response.Close()
            continue
        }

        if (Test-Path $filePath -PathType Leaf) {
            $ext = [System.IO.Path]::GetExtension($filePath).ToLower()
            $contentType = switch ($ext) {
                ".html" { "text/html; charset=utf-8" }
                ".css"  { "text/css; charset=utf-8" }
                ".js"   { "application/javascript; charset=utf-8" }
                ".wasm" { "application/wasm" }
                ".svg"  { "image/svg+xml" }
                ".webp" { "image/webp" }
                ".png"  { "image/png" }
                ".jpg"  { "image/jpeg" }
                ".hdr"  { "image/vnd.radiance" }
                ".ttf"  { "font/ttf" }
                ".enc"  { "application/octet-stream" }
                default { "application/octet-stream" }
            }

            $response.ContentType = $contentType
            $bytes = [System.IO.File]::ReadAllBytes($filePath)
            $response.ContentLength64 = $bytes.Length
            $response.OutputStream.Write($bytes, 0, $bytes.Length)
        } else {
            $response.StatusCode = 404
            $bytes = [System.Text.Encoding]::UTF8.GetBytes("404 Not Found: " + $url)
            $response.OutputStream.Write($bytes, 0, $bytes.Length)
        }
        $response.Close()
    }
} catch {
    Write-Host "Server error: $_"
} finally {
    $listener.Stop()
    Write-Host "Server stopped."
}
