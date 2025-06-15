param (
    [string]$source,
    [string]$destination,
    [switch]$help
)

function Show-Help {
    Write-Output @"
使い方:
    backup_check.ps1 -source <比較元フォルダパス> -destination <比較先フォルダパス>

    ※ パスに空白がある場合は "" で囲んでください。

例:
    .\backup_check.ps1 -source ""C:\Work\0001_作って覚える"" -destination ""C:\Users\<ユーザー名>\OneDrive\0001_作って覚える""

引数なしで実行した場合は対話的に入力を求めます。
"@
}

if ($help) {
    Show-Help
    exit 0
}

if (-not $source) {
    $source = Read-Host "比較元フォルダのパスを入力してください（空白を含む場合は \"\" で囲む）"
}
if (-not $destination) {
    $destination = Read-Host "比較先フォルダのパスを入力してください（空白を含む場合は \"\" で囲む）"
}

$source = $source.Trim('"')
$destination = $destination.Trim('"')

# 除外したい拡張子のリスト（小文字で統一）
$excludeExtensions = @(".suo", ".swp". ".ide", ".ide-wal", ".lock")
# 除外したいフォルダ名のリスト（小文字で統一）
$excludeFolders = @(".vs")

function Write-Log {
    param([string]$message)
    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "$time : $message"
    Add-Content -Path $logFile -Value $line
    Write-Output $line
}

function Get-RelativeItems {
    param([string]$rootPath)

    Get-ChildItem -Path $rootPath -Recurse | Where-Object {
        $relativePath = $_.FullName.Substring($rootPath.Length).TrimStart('\').ToLower()

        # パスを区切ってフォルダ名を取り出す
        $parts = $relativePath -split '\\'

        # いずれかのパーツが除外対象フォルダに一致したら除外
        foreach ($exFolder in $excludeFolders) {
            if ($parts -contains $exFolder) {
                return $false
            }
        }
        return $true
    } | ForEach-Object {
        if ($_.PSIsContainer) {
            $_.FullName.Substring($rootPath.Length).TrimStart('\') + "\"
        }
        else {
            $_.FullName.Substring($rootPath.Length).TrimStart('\')
        }
    }
}



$timestamp = Get-Date -Format "yyyyMMddHHmmss"
$logFile = "C:\temp\copy_errors_$timestamp.log"
if (Test-Path $logFile) { Remove-Item $logFile }

Write-Log "===== バックアップ比較チェック開始 ====="
Write-Log "比較元フォルダ: $source"
Write-Log "比較先フォルダ: $destination"

$sourceItems = Get-RelativeItems $source
$destinationItems = Get-RelativeItems $destination

# ファイルだけ除外リストを適用
function Filter-ExcludedFiles {
    param([string[]]$items)
    $items | Where-Object {
        if ($_ -like "*\") {
            # フォルダは除外対象外（そのまま残す）
            $true
        }
        else {
            $ext = [IO.Path]::GetExtension($_).ToLower()
            -not ($excludeExtensions -contains $ext)
        }
    }
}

$sourceFiltered = Filter-ExcludedFiles -items $sourceItems
$destinationFiltered = Filter-ExcludedFiles -items $destinationItems

$sourceFolders = $sourceFiltered | Where-Object { $_ -like "*\" }
$destinationFolders = $destinationFiltered | Where-Object { $_ -like "*\" }
$sourceFiles = $sourceFiltered | Where-Object { $_ -notlike "*\" }
$destinationFiles = $destinationFiltered | Where-Object { $_ -notlike "*\" }

Write-Log "比較元（除外適用後）：フォルダ数 $($sourceFolders.Count), ファイル数 $($sourceFiles.Count)"
Write-Log "比較先（除外適用後）：フォルダ数 $($destinationFolders.Count), ファイル数 $($destinationFiles.Count)"

if ($sourceFolders.Count -eq $destinationFolders.Count -and $sourceFiles.Count -eq $destinationFiles.Count) {
    Write-Log "ファイル数とフォルダー数が一致しています。"
}
else {
    Write-Log "ファイル数またはフォルダー数に差があります。差分を出力します。"

    $missingFolders = $sourceFolders | Where-Object { $_ -notin $destinationFolders }
    $extraFolders = $destinationFolders | Where-Object { $_ -notin $sourceFolders }
    if ($missingFolders.Count -gt 0) {
        Write-Log "【比較先に存在しないフォルダ（比較元にのみ存在）】"
        $missingFolders | ForEach-Object { Write-Log "  $_" }
    }
    if ($extraFolders.Count -gt 0) {
        Write-Log "【比較先にのみ存在する余分なフォルダ】"
        $extraFolders | ForEach-Object { Write-Log "  $_" }
    }

    $missingFiles = $sourceFiles | Where-Object { $_ -notin $destinationFiles }
    $extraFiles = $destinationFiles | Where-Object { $_ -notin $sourceFiles }
    if ($missingFiles.Count -gt 0) {
        Write-Log "【比較先に存在しないファイル（比較元にのみ存在）】"
        $missingFiles | ForEach-Object { Write-Log "  $_" }
    }
    if ($extraFiles.Count -gt 0) {
        Write-Log "【比較先にのみ存在する余分なファイル】"
        $extraFiles | ForEach-Object { Write-Log "  $_" }
    }
}

Write-Log "===== バックアップ比較チェック終了 ====="
