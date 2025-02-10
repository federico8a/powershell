oh-my-posh init pwsh | Invoke-Expression
if ($host.Name -eq 'ConsoleHost')
{
    Import-Module PSReadLine
}
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineOption -EditMode Windows