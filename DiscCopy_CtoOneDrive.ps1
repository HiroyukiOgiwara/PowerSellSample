param (
    [string]$source,
    [string]$destination,
    [switch]$help
)

function Show-Help {
    Write-Output @"
使い方:
    DiscCopy_CtoOneDrive.ps1 -source <コピー元フォルダ> -destination <コピー先OneDriveフォルダ>

    ※ パスに空白がある場合は "" で囲んでください。

例:
    .\DiscCopy_CtoOneDrive.ps1 -source ""C:\Work\0001_作って覚える"" -destination ""C:\Users\<ユーザー名>\OneDrive\0001_作って覚える""

引数なしで実行すると対話形式で入力を求めます。
"@
}

if ($help) {
    Show-Help
    exit 0
}

if (-not $source) {
    $source = Read-Host "コピー元フォルダのパスを入力してください（空白含む場合は \"\" で囲む）"
}
if (-not $destination) {
    $destination = Read-Host "コピー先OneDriveローカル同期フォルダのパスを入力してください（空白含む場合は \"\" で囲む）"
}

$source = $source.Trim('"')
$destination = $destination.Trim('"')

$logFile = "C:\temp\copy_errors.log"

function Write-Log {
    param([string]$msg, [switch]$append)
    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "$time : $msg"
    if ($append) {
        Add-Content -Path $logFile -Value $line
    }
    Write-Output $line
}

Write-Log "============================================================" -append
Write-Log "【コピー処理開始】"
Write-Log "コピー元: $source"
Write-Log "コピー先: $destination"

# ファイルとフォルダ数を事前に取得
$totalFiles = (Get-ChildItem -Path $source -Recurse -File).Count
$totalFolders = (Get-ChildItem -Path $source -Recurse -Directory).Count

Write-Log "コピー元フォルダ内のファイル数: $totalFiles"
Write-Log "コピー元フォルダ内のフォルダ数: $totalFolders"

# 進捗表示用変数
$copiedFiles = 0
$copiedFolders = 0
$lastUpdateTime = Get-Date

# 直近の出力長を記憶
$global:lastOutputLength = 0

function Write-ProgressLine {
    param (
        [int]$filesCopied,
        [int]$foldersCopied,
        [int]$totalFiles,
        [int]$totalFolders
    )
    $percentTotal = if (($totalFiles + $totalFolders) -gt 0) {
        [math]::Round((($filesCopied + $foldersCopied) / ($totalFiles + $totalFolders)) * 100, 2)
    } else { 100 }

    $text = "処理中・・・　$filesCopied ファイル $foldersCopied フォルダ / 全 $totalFiles ファイル $totalFolders フォルダ ： $percentTotal% 処理完了"

    # コンソール幅取得
    $width = [Console]::WindowWidth

    # 出力文字列を幅いっぱいにスペースで埋めて前の残りを消す
    if ($text.Length -lt $global:lastOutputLength) {
        $text = $text.PadRight($global:lastOutputLength)
    }

    # 行頭に戻り改行なしで上書き表示
    Write-Host -NoNewline "`r$text"

    $global:lastOutputLength = $text.Length
}

try {
    Get-ChildItem -Path $source -Recurse | ForEach-Object {
        $destPath = Join-Path $destination ($_.FullName.Substring($source.Length).TrimStart('\'))
        if ($_.PSIsContainer) {
            if (-not (Test-Path $destPath)) {
                New-Item -ItemType Directory -Path $destPath | Out-Null
            }
            $copiedFolders++
        }
        else {
            try {
                Copy-Item -Path $_.FullName -Destination $destPath -Force -ErrorAction Stop
            }
            catch {
                $errMsg = "コピー失敗ファイル: $($_.FullName) - エラー: $($_.Exception.Message)"
                Write-Log $errMsg -append
            }
            $copiedFiles++
        }

        # 0.5秒以上経過したら進捗更新表示
        $now = Get-Date
        if (($now - $lastUpdateTime).TotalSeconds -ge 0.5) {
            Write-ProgressLine -filesCopied $copiedFiles -foldersCopied $copiedFolders -totalFiles $totalFiles -totalFolders $totalFolders
            $lastUpdateTime = $now
        }
    }

    # 処理完了時に改行を入れて残す
    Write-Host ""
}
catch {
    Write-Log "全体の処理中にエラー発生: $($_.Exception.Message)" -append
}

$endTime = Get-Date
Write-Log "処理終了日時: $endTime"
Write-Log "【コピー処理終了】"
Write-Log "============================================================"

# コピー後に backup_check.ps1 を呼び出し
$backupCheckPath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Definition) "backup_check.ps1"

if (Test-Path $backupCheckPath) {
    Write-Log "バックアップチェックを実行します..."
    & $backupCheckPath -source $source -destination $destination
} else {
    Write-Log "バックアップチェックスクリプト backup_check.ps1 が見つかりません。"
}
