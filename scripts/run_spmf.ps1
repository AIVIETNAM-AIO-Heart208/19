# Sinh output tham chieu cua SPMF (Eclat) cho moi file trong data/toy/.
#   powershell -ExecutionPolicy Bypass -File scripts/run_spmf.ps1
# Ket qua: test/expected/<ten>_<minsup>.txt. Can JDK 25+ va tools/spmf.jar.
# Script KHONG tu sua hay tu tao output: neu SPMF khong sinh file thi chi bao lai.

$root   = Split-Path -Parent $PSScriptRoot
$jar    = Join-Path $root 'tools\spmf.jar'
$inDir  = Join-Path $root 'data\toy'
$outDir = Join-Path $root 'test\expected'

if (-not (Test-Path $jar)) { Write-Host "Khong thay $jar"; exit 1 }
New-Item -ItemType Directory -Force $outDir | Out-Null

$failed = 0
foreach ($f in Get-ChildItem (Join-Path $inDir '*.txt') | Sort-Object Name) {
    $levels = @(20, 40, 60)
    if ($f.BaseName -eq 'toy') { $levels = @(20, 21, 39, 40, 60) }
    # File thua: 20-60% gan nhu khong con itemset nao, them nguong thap de test co noi dung.
    if ($f.BaseName -eq 'rand_sparse') { $levels = @(2, 5, 10, 20, 40, 60) }
    foreach ($p in $levels) {
        $out = Join-Path $outDir ("{0}_{1}.txt" -f $f.BaseName, $p)
        if (Test-Path $out) { Remove-Item $out }
        $log = & java -jar $jar run Eclat $f.FullName $out "$p%"
        # SPMF chi in dong thong ke nay khi chay xong; khi loi no co the de lai file output rong.
        $ok = (Test-Path $out) -and (($log -join "`n") -match 'Frequent itemsets count')
        if ($ok) {
            $n = @(Get-Content $out | Where-Object { $_ -match '#SUP:' }).Count
            Write-Host ("OK    {0,-36} {1,3}%  {2,6} itemset" -f $f.Name, $p, $n)
        } else {
            $failed++
            if (Test-Path $out) { Remove-Item $out }
            $msg = @($log | Where-Object { $_ -match 'ERROR MESSAGE|input file is empty' }) -join ' '
            Write-Host ("FAIL  {0,-36} {1,3}%  SPMF khong chay duoc: {2}" -f $f.Name, $p, $msg.Trim())
        }
    }
}
Write-Host "So lan SPMF khong sinh output: $failed"
Write-Host "(Da biet: SPMF khong doc duoc dup_items_comments.txt va empty.txt, 3 muc moi file = 6 lan; xem test/expected/README.md)"
exit $failed
