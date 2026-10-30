#requires -Version 5.1
# Pester 5; all file operations are isolated to TestDrive.
BeforeAll {
 $root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
 $preflight=Join-Path $root 'scripts/00-Preflight.ps1'
 $provision=Join-Path $root 'scripts/02-Provision-Targets.ps1'
 $spmtOriginal=Join-Path $root 'scripts/03-Run-SPMT.ps1'
 $header='Wave,SourceUrl,TargetUrl,Title,OwnerUPN,ProvisionMode,StorageQuotaMB,Criticality,BusinessOwner'
 $good='W1,https://intranet.example.net/sites/finance,https://example.sharepoint.com/sites/finance,Finance,admin@example.com,Manual,5120,High,Finance'
 function global:Get-SPMTMigration { return $null }
 function global:Start-SPMTMigration {}
 function global:Register-SPMTMigration {}
 function global:Add-SPMTTask {}
 function global:Unregister-SPMTMigration {}
}
AfterAll {
 foreach($cmd in 'Get-SPMTMigration','Start-SPMTMigration','Register-SPMTMigration','Add-SPMTTask','Unregister-SPMTMigration') {
  Remove-Item -Path ("Function:\global:" + $cmd) -ErrorAction SilentlyContinue
 }
}
Describe 'SharePoint migration: safe preflight and SPMT guards' {
 BeforeEach {
  $dir=Join-Path $TestDrive ([guid]::NewGuid().ToString())
  New-Item -Path (Join-Path $dir 'scripts') -ItemType Directory -Force | Out-Null
  $manifest=Join-Path $dir 'manifest.csv'
  @($header,$good) | Set-Content -LiteralPath $manifest -Encoding UTF8
  $spmt=Join-Path $dir 'scripts/03-Run-SPMT.ps1'
  Copy-Item -LiteralPath $spmtOriginal -Destination $spmt
 }
 It 'accepts a well-formed migration manifest' {
  { & $preflight -Manifest $manifest } | Should -Not -Throw
 }
 It 'rejects duplicate target sites' {
  $other=$good.Replace('intranet.example.net/sites/finance','intranet.example.net/sites/hr')
  Add-Content $manifest $other
  { & $preflight -Manifest $manifest } | Should -Throw
 }
 It 'rejects duplicate source sites' {
  $other=$good.Replace('example.sharepoint.com/sites/finance','example.sharepoint.com/sites/hr')
  Add-Content $manifest $other
  { & $preflight -Manifest $manifest } | Should -Throw
 }
 It 'rejects a non-SharePoint target' {
  @($header,$good.Replace('example.sharepoint.com','untrusted.example.net')) | Set-Content $manifest
  { & $preflight -Manifest $manifest } | Should -Throw
 }
 It 'rejects embedded credentials in a target URL' {
  @($header,$good.Replace('https://example.sharepoint.com','https://admin:password@example.sharepoint.com')) | Set-Content $manifest
  { & $preflight -Manifest $manifest } | Should -Throw
 }
 It 'rejects unsupported provisioning modes' {
  @($header,$good.Replace(',Manual,',',Unsafe, ')) | Set-Content $manifest
  { & $preflight -Manifest $manifest } | Should -Throw
 }
 It 'rejects malformed storage quota' {
  @($header,$good.Replace(',5120,',',NaN,')) | Set-Content $manifest
  { & $preflight -Manifest $manifest } | Should -Throw
 }
 It 'rejects an unknown wave during provisioning' {
  { & $provision -Manifest $manifest -Wave UNKNOWN -Apply } | Should -Throw
 }
 It 'previews without requiring SPO authentication' {
  { & $provision -Manifest $manifest -Wave W1 } | Should -Not -Throw
 }
 It 'refuses delta without a registered session and lock' {
  Mock Import-Module {}
  Mock Get-SPMTMigration { $null }
  { & $spmt -Manifest $manifest -Wave W1 -Mode Delta } | Should -Throw
 }
 It 'does not register an initial session without explicit user confirmation' {
  Mock Import-Module {}
  Mock Get-SPMTMigration { $null }
  Mock Read-Host { 'NO' }
  Mock Register-SPMTMigration {}
  { & $spmt -Manifest $manifest -Wave W1 -Mode Initial } | Should -Throw
  Should -Invoke Register-SPMTMigration -Times 0 -Exactly
 }
 It 'never executes a demonstration Contoso target' {
  Mock Import-Module {}
  @($header,$good.Replace('example.sharepoint.com','contoso.sharepoint.com')) | Set-Content $manifest
  Mock Register-SPMTMigration {}
  { & $spmt -Manifest $manifest -Wave W1 -Mode Initial } | Should -Throw
  Should -Invoke Register-SPMTMigration -Times 0 -Exactly
 }
 It 'protects against changed initial-to-delta manifest hashes' {
  Mock Import-Module {}
  Mock Get-SPMTMigration { [pscustomobject]@{Status='Finished'} }
  Mock Start-SPMTMigration {}
  $output=Join-Path $dir 'output'
  New-Item -ItemType Directory -Path $output | Out-Null
  [pscustomobject]@{Wave='W1';Mode='Initial';ManifestSHA256='WRONG'} |
   ConvertTo-Json | Set-Content (Join-Path $output 'spmt-session-lock.json')
  { & $spmt -Manifest $manifest -Wave W1 -Mode Delta } | Should -Throw
  Should -Invoke Start-SPMTMigration -Times 0 -Exactly
 }
 It 'refuses to unregister a running SPMT session' {
  Mock Import-Module {}
  Mock Get-SPMTMigration { [pscustomobject]@{Status='Running'} }
  Mock Unregister-SPMTMigration {}
  $output=Join-Path $dir 'output'
  New-Item -ItemType Directory -Path $output | Out-Null
  [pscustomobject]@{Wave='W1';Mode='Scan'} |
   ConvertTo-Json | Set-Content (Join-Path $output 'spmt-session-lock.json')
  { & $spmt -Manifest $manifest -Wave W1 -Mode ResetSession } | Should -Throw
  Should -Invoke Unregister-SPMTMigration -Times 0 -Exactly
 }
}
