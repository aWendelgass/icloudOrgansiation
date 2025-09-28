# ===================================================================
# PowerShell Script Module for Structured Logging
#
# MediaWorkflowLogger.psm1
#
# This module provides a centralized function for structured logging
# for the media workflow script suite.
# ===================================================================

# --- Configuration ---
# Define the path for the central log file.
$LogFilePath = Join-Path -Path $PSScriptRoot -ChildPath "media_workflow.log.csv"

# --- Lade UTF8 Helper Modul ---
try {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath "Utf8BomHelper.psm1")
} catch {
    Write-Host "FEHLER: Das UTF8 Helper Modul 'Utf8BomHelper.psm1' konnte nicht geladen werden." -ForegroundColor Red
    pause
    return
}


# --- Function Definition ---

function Write-StructuredLog {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("INFO", "WARN", "ERROR")]
        [string]$LogLevel,

        [Parameter(Mandatory=$true)]
        [string]$Message,

        [Parameter(Mandatory=$false)]
        [string]$SkriptName,

        [Parameter(Mandatory=$false)]
        [object]$FileObject
    )

    # 1. Write to console
    $consoleMessage = "[$LogLevel] $Message"
    $color = @{"INFO"="Green"; "WARN"="Yellow"; "ERROR"="Red"}[$LogLevel]
    
    # Use Write-Warning for WARN and ERROR to write to the error stream if needed
    if ($LogLevel -eq "WARN" -or $LogLevel -eq "ERROR") {
        Write-Warning $Message
    } else {
        Write-Host $consoleMessage -ForegroundColor $color
    }

    # 2. Prepare structured log entry
    $logEntry = [PSCustomObject]@{
        Timestamp   = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        LogLevel    = $LogLevel
        Skript      = $SkriptName
        Quelldatei  = if ($FileObject -and $FileObject.PSObject.Properties.Name -contains 'Dateiname') { $FileObject.Dateiname } else { "N/A" }
        Pfad        = if ($FileObject -and $FileObject.PSObject.Properties.Name -contains 'Pfad') { $FileObject.Pfad } else { "N/A" }
        Meldung     = $Message
    }

    # 3. Write to structured log file (CSV)
    # Check if the log file exists to write the header only once
    if (-not (Test-Path $LogFilePath)) {
        # Create the file and add the header
        #  alt $logEntry | Export-Csv -Path $LogFilePath -NoTypeInformation -Delimiter ';' -Encoding UTF8
        Export-CsvWithBom -Data $logEntry -Path $LogFilePath -Delimiter ';'



    } else {
        # Append without the header
        #alt:  $logEntry | Export-Csv -Path $LogFilePath -Append -NoTypeInformation -Delimiter ';' -Encoding UTF8
        Export-CsvWithBom -Data $logEntry -Path $LogFilePath -Delimiter ';' -Append

    }
}

# --- Export Module Members ---
# Export the function to make it available to scripts that import this module.
Export-ModuleMember -Function Write-StructuredLog
