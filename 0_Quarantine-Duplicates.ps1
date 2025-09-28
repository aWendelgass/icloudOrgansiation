# ===================================================================
# Skript zum Finden und Isolieren von Duplikaten (basierend auf Groesse und Typ)
#
# Dies ist ein vorgelagerter, optionaler Schritt (Skript 0).
#
# Arbeitsweise in 2 Phasen:
#
# Phase 1: Analyse ($DryRun = $true)
# Das Skript scannt alle Dateien und erstellt einen "Aktionsplan"
# (`0_quarantine_plan.json`), ohne Aenderungen vorzunehmen.
#
# Phase 2: Ausfuehrung ($DryRun = $false)
# Das Skript liest den Aktionsplan ein und fuehrt die geplanten
# Dateioperationen (verschieben, kopieren) aus.
#
# ===================================================================

# !!!SICHERHEITSSCHALTER:
#    $true  = Analyse-Modus: Sucht Duplikate und erstellt einen Plan. Zeigt nur an, was getan wuerde.
#    $false = Ausfuehrungs-Modus: Fuehrt den zuvor erstellten Plan aus.
#
# WORKFLOW: Immer zuerst mit $true laufen lassen, dann auf $false aendern und erneut ausfuehren.
$DryRun = $true

# --- Konfiguration ---
$SkriptName = "Skript 0: Duplikat-Suche"
$Arbeitsordner = $PSScriptRoot
$QuarantineFolder = Join-Path -Path $Arbeitsordner -ChildPath "_DUPLICATES_TO_DELETE"
$PlanFile = Join-Path -Path $Arbeitsordner -ChildPath "0_quarantine_plan.json"
$mediaExtensions = @("*.jpg", "*.jpeg", "*.heic", "*.png", "*.mov", "*.mp4")

# --- Lade Logging Modul ---
try {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath "MediaWorkflowLogger.psm1")
} catch {
    Write-Host "FEHLER: Das Logging-Modul 'MediaWorkflowLogger.psm1' konnte nicht geladen werden." -ForegroundColor Red
    pause
    return
}

# Setze Konsolen-Encoding auf UTF-8, um die Ausgabe von externen Tools korrekt zu lesen
[System.Console]::InputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::OutputEncoding = [System.Text.Encoding]::UTF8
# --- Skript-Logik ---

if ($DryRun) {
    # --- PHASE 1: ANALYSE ---
    Write-StructuredLog -LogLevel INFO -SkriptName $SkriptName -Message "PHASE 1: ANALYSE - Suche nach Duplikaten und erstelle Aktionsplan."

    Write-StructuredLog -LogLevel INFO -SkriptName $SkriptName -Message "Suche nach Mediendateien in '$Arbeitsordner'..."
    $allFiles = Get-ChildItem -Path $Arbeitsordner -Recurse -File -Include $mediaExtensions -Exclude "*\_DUPLICATES_TO_DELETE\*"

    Write-StructuredLog -LogLevel INFO -SkriptName $SkriptName -Message "Es wurden $($allFiles.Count) Dateien gefunden."
    Write-StructuredLog -LogLevel INFO -SkriptName $SkriptName -Message "Gruppiere Dateien nach Groesse und Typ, um Duplikate zu finden..."
    $duplicateGroups = $allFiles | Group-Object -Property Length, Extension | Where-Object { $_.Count -gt 1 }

    if ($duplicateGroups.Count -eq 0) {
        Write-StructuredLog -LogLevel INFO -SkriptName $SkriptName -Message "Keine Duplikate basierend auf Groesse und Typ gefunden."
        if (Test-Path $PlanFile) { Remove-Item $PlanFile } # Alten Plan loeschen
        pause
        return
    }

    Write-StructuredLog -LogLevel WARN -SkriptName $SkriptName -Message "Es wurden $($duplicateGroups.Count) Gruppen von moeglichen Duplikaten gefunden."
    
    $actionPlan = [System.Collections.Generic.List[object]]::new()

    foreach ($group in $duplicateGroups) {
        $sortedFiles = $group.Group | Sort-Object -Property CreationTime
        $originalFile = $sortedFiles | Select-Object -First 1
        $duplicateFiles = $sortedFiles | Select-Object -Skip 1
        
        $originalBaseName = $originalFile.BaseName
        $originalExtension = $originalFile.Extension

        $quarantineOriginalName = "${originalBaseName}_original${originalExtension}"
        $quarantineOriginalPath = Join-Path -Path $QuarantineFolder -ChildPath $quarantineOriginalName
        $actionPlan.Add([PSCustomObject]@{
            Action = "Copy"
            Source = $originalFile.FullName
            Destination = $quarantineOriginalPath
        })

        $counter = 1
        foreach ($dupFile in $duplicateFiles) {
            $quarantineDuplicateName = "${originalBaseName}_${counter}${originalExtension}"
            $quarantineDuplicatePath = Join-Path -Path $QuarantineFolder -ChildPath $quarantineDuplicateName
            $actionPlan.Add([PSCustomObject]@{
                Action = "Move"
                Source = $dupFile.FullName
                Destination = $quarantineDuplicatePath
            })
            $counter++
        }
    }

    Write-StructuredLog -LogLevel INFO -SkriptName $SkriptName -Message "------------------------------------------------------------"
    Write-StructuredLog -LogLevel INFO -SkriptName $SkriptName -Message "[SIMULATION] Die folgenden Aktionen wuerden ausgefuehrt:"
    $actionPlan | ForEach-Object {
        Write-StructuredLog -LogLevel INFO -SkriptName $SkriptName -Message "$($_.Action) '$($_.Source)' nach '$($_.Destination)'"
    }
    Write-StructuredLog -LogLevel INFO -SkriptName $SkriptName -Message "------------------------------------------------------------"

    $actionPlan | ConvertTo-Json -Depth 5 | Out-File -FilePath $PlanFile -Encoding UTF8
    Write-StructuredLog -LogLevel INFO -SkriptName $SkriptName -Message "Aktionsplan wurde erfolgreich in '$PlanFile' gespeichert."
    Write-StructuredLog -LogLevel INFO -SkriptName $SkriptName -Message "Um diese Aktionen auszufuehren, setzen Sie `$DryRun = `$false` und fuehren das Skript erneut aus."

} else {
    # --- PHASE 2: AUSFUEHRUNG ---
    Write-StructuredLog -LogLevel INFO -SkriptName $SkriptName -Message "PHASE 2: AUSFUEHRUNG - Lese und verarbeite Aktionsplan."

    if (-not (Test-Path -Path $PlanFile)) {
        Write-StructuredLog -LogLevel ERROR -SkriptName $SkriptName -Message "Konnte keinen Aktionsplan ('$PlanFile') finden."
        Write-StructuredLog -LogLevel ERROR -SkriptName $SkriptName -Message "Bitte fuehren Sie das Skript zuerst im Analyse-Modus (`$DryRun = `$true`) aus."
        pause
        return
    }

    $actionPlan = Get-Content -Path $PlanFile | ConvertFrom-Json
    
    if ($actionPlan.Count -eq 0) {
        Write-StructuredLog -LogLevel INFO -SkriptName $SkriptName -Message "Aktionsplan ist leer. Nichts zu tun."
        Remove-Item $PlanFile
        pause
        return
    }

    Write-StructuredLog -LogLevel INFO -SkriptName $SkriptName -Message "Aktionsplan mit $($actionPlan.Count) Aktionen wird ausgefuehrt..."

    if (-not (Test-Path -Path $QuarantineFolder)) {
        New-Item -Path $QuarantineFolder -ItemType Directory | Out-Null
    }

    foreach ($action in $actionPlan) {
        try {
            Write-StructuredLog -LogLevel INFO -SkriptName $SkriptName -Message "$($action.Action) '$($action.Source)' nach '$($action.Destination)'"
            if ($action.Action -eq "Copy") {
                [System.IO.File]::Copy($action.Source, $action.Destination)
            } elseif ($action.Action -eq "Move") {
                [System.IO.File]::Move($action.Source, $action.Destination)
            }
        } catch {
            Write-StructuredLog -LogLevel ERROR -SkriptName $SkriptName -Message "FEHLER bei der Ausfuehrung der Aktion fuer '$($action.Source)': $($_.Exception.Message)"
        }
    }

    Remove-Item $PlanFile
    
    Write-StructuredLog -LogLevel INFO -SkriptName $SkriptName -Message "------------------------------------------------------------"
    Write-StructuredLog -LogLevel INFO -SkriptName $SkriptName -Message "Alle Aktionen aus dem Plan wurden ausgefuehrt."
    Write-StructuredLog -LogLevel WARN -SkriptName $SkriptName -Message "Alle gefundenen Duplikate wurden in den Ordner '$QuarantineFolder' verschoben/kopiert."
    Write-StructuredLog -LogLevel WARN -SkriptName $SkriptName -Message "Bitte ueberpruefen Sie den Inhalt und loeschen Sie den Ordner manuell."
}

pause
