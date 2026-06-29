# refresh_bookmarks.ps1
# Visual Studio DTE를 통해 Bookmark Studio를 강제 리프레시합니다.
# 사용법: pwsh -File refresh_bookmarks.ps1

$dteVersions = @("18.0", "17.0", "16.0")
$dte = $null

foreach ($version in $dteVersions) {
    try {
        $dte = [System.Runtime.InteropServices.Marshal]::GetActiveObject("VisualStudio.DTE.$version")
        Write-Host "Visual Studio DTE $version 연결됨"
        break
    } catch {
        # 해당 버전 미실행, 다음 시도
    }
}

if ($null -eq $dte) {
    Write-Error "실행 중인 Visual Studio 인스턴스를 찾을 수 없습니다."
    exit 1
}

try {
    $dte.ExecuteCommand("BookmarkStudio.RefreshBookmarkManager")
    Write-Host "북마크 리프레시 완료"
} catch {
    Write-Error "명령 실행 실패: $_"
    exit 1
}
