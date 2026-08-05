param([int]$Port = 8081)

$ErrorActionPreference = 'Stop'
$siteRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\download_page')).Path
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
Write-Output "DOWNLOAD_PAGE_READY=http://localhost:$Port/"

$contentTypes = @{
    '.html' = 'text/html; charset=utf-8'
    '.css'  = 'text/css; charset=utf-8'
    '.js'   = 'application/javascript; charset=utf-8'
    '.png'  = 'image/png'
    '.jpg'  = 'image/jpeg'
    '.webp' = 'image/webp'
    '.apk'  = 'application/vnd.android.package-archive'
    '.sha256' = 'text/plain; charset=utf-8'
}

try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        try {
            $relativePath = [Uri]::UnescapeDataString($context.Request.Url.AbsolutePath.TrimStart('/'))
            if ([string]::IsNullOrWhiteSpace($relativePath)) { $relativePath = 'index.html' }
            $candidate = [IO.Path]::GetFullPath((Join-Path $siteRoot $relativePath))
            if (-not $candidate.StartsWith($siteRoot, [StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
                $context.Response.StatusCode = 404
                $context.Response.Close()
                continue
            }
            $file = Get-Item -LiteralPath $candidate
            $extension = $file.Extension.ToLowerInvariant()
            $context.Response.ContentType = if ($contentTypes.ContainsKey($extension)) { $contentTypes[$extension] } else { 'application/octet-stream' }
            $context.Response.ContentLength64 = $file.Length
            if ($extension -eq '.apk') {
                $context.Response.AddHeader('Content-Disposition', "attachment; filename=`"$($file.Name)`"")
            }
            if ($context.Request.HttpMethod -ne 'HEAD') {
                $stream = [IO.File]::OpenRead($candidate)
                try { $stream.CopyTo($context.Response.OutputStream) } finally { $stream.Dispose() }
            }
            $context.Response.OutputStream.Close()
        } catch {
            $context.Response.StatusCode = 500
            $context.Response.Close()
        }
    }
} finally {
    $listener.Stop()
    $listener.Close()
}

