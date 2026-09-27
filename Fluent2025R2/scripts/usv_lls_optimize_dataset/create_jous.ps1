# ============================================================
# create_jous.ps1
# 根据 doc/targets.txt 中的 (fai, r) 坐标，基于 jou/run_fai0_r0.75.jou 模板，
# 批量生成其余的 run_faiX_rY.jou 文件。
# 生成时替换 mesh_path 与 output_file_path 中的文件名
# （模板里被注释掉的引用行也会一并替换，保持一致）。
# ============================================================

$ErrorActionPreference = "Stop"
$root         = $PSScriptRoot
$targetsPath  = Join-Path $root "doc\targets.txt"
$jouDir       = Join-Path $root "jou"
$mshDir       = Join-Path $root "msh"
$outDir       = Join-Path $root "out"
$templatePath = Join-Path $root "jou\run_fai0_r0.75.jou"

if (-not (Test-Path $targetsPath))  { throw "找不到目标文件: $targetsPath" }
if (-not (Test-Path $templatePath)) { throw "找不到模板文件: $templatePath" }

$template = [IO.File]::ReadAllText($templatePath)

# 检测模板是否带 BOM，写出时保持一致
$bytes = [IO.File]::ReadAllBytes($templatePath)
$enc = if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
    New-Object System.Text.UTF8Encoding($true)
} else {
    New-Object System.Text.UTF8Encoding($false)
}

# r 数值 -> 网格/输出文件名中的 r 字符串（与 msh 目录实际命名严格一致）
#   0.75 -> "0.75"   1 -> "1.0"   1.25 -> "1.25"
#   1.5  -> "1.50"   2 -> "2.0"   2.5  -> "2.5"
function Get-RTag([double]$r) {
    switch ($r) {
        0.75 { "0.75"; break }
        1.0  { "1.0";  break }
        1.25 { "1.25"; break }
        1.5  { "1.50"; break }
        2.0  { "2.0";  break }
        2.5  { "2.5";  break }
        default { throw "targets.txt 中出现未知的 r 值: $r（无对应的网格命名规则）" }
    }
}

if (-not (Test-Path $jouDir)) { New-Item -ItemType Directory -Path $jouDir | Out-Null }
# out 目录若不存在，Fluent 写 report file 时会失败，这里自动创建
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null; Write-Host "已创建输出目录: $outDir" }

$generated = 0
$skipped   = 0
$warned    = 0

foreach ($line in Get-Content $targetsPath) {
    $line = $line.Trim()
    if ($line -eq "" -or $line.StartsWith("#")) { continue }

    $parts = $line -split '\s+'
    if ($parts.Count -lt 2) { throw "targets.txt 行格式错误: '$line'" }
    $fai = [int]$parts[0]
    $r   = [double]$parts[1]

    # fai0 / r0.75 即模板本身，跳过
    if ($fai -eq 0 -and $r -eq 0.75) { $skipped++; continue }

    $rtag = Get-RTag $r

    $meshName = "mesh_fai${fai}_r${rtag}.msh"
    $outName  = "pressure_signal_vof_fai${fai}_r${rtag}.out"

    # 网格文件应当已就绪，缺失则警告（不中断）
    $meshFile = Join-Path $mshDir $meshName
    if (-not (Test-Path $meshFile)) {
        Write-Warning "网格文件不存在（仍会生成 jou，请确认 msh 目录）: $meshName"
        $warned++
    }

    # 同时替换有效行与注释行中的引用
    $content = $template.Replace("mesh_fai0_r0.75", "mesh_fai${fai}_r${rtag}")
    $content = $content.Replace("pressure_signal_vof_fai0_r0.75", "pressure_signal_vof_fai${fai}_r${rtag}")

    $jouFile = Join-Path $jouDir ("run_fai{0}_r{1}.jou" -f $fai, $rtag)
    [IO.File]::WriteAllText($jouFile, $content, $enc)
    $generated++
    Write-Host ("生成 {0,-22}  mesh: {1,-24}  out: {2}" -f (Split-Path $jouFile -Leaf), $meshName, $outName)
}

Write-Host ""
Write-Host "完成: 生成 $generated 个 jou, 跳过模板 $skipped 个, 网格缺失警告 $warned 个"
