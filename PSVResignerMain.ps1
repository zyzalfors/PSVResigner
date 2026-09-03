param([string] $path, [switch] $res)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

(. "$PSScriptRoot\PSVResigner.ps1")
(. "$PSScriptRoot\PSVResignerForm.ps1")

[void] [PSVResignerForm]::new($path, $res).ShowDialog()