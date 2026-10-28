#Requires -Version 7.2
[CmdletBinding()]
param([Parameter(Mandatory)][string]$SqlFile)
$ErrorActionPreference = 'Stop'
if (-not $env:DB_CONNECTION_STRING) { throw 'DB_CONNECTION_STRING is required.' }
$connection = [System.Data.SqlClient.SqlConnection]::new($env:DB_CONNECTION_STRING)
$command = $connection.CreateCommand(); $command.CommandTimeout=120
$command.CommandText=Get-Content $SqlFile -Raw
try { $connection.Open(); [void]$command.ExecuteNonQuery() }
finally { $command.Dispose(); $connection.Dispose() }
Write-Output 'Database assertions passed.'
