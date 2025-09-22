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
$DryRun = $false

# --- Konfiguration ---
$Arbeitsordner = $PSScriptRoot
$QuarantineFolder = Join-Path -Path $Arbeitsordner -ChildPath "_DUPLICATES_TO_DELETE"
$PlanFile = Join-Path -Path $Arbeitsordner -ChildPath "0_quarantine_plan.json"
$mediaExtensions = @("*.jpg", "*.jpeg", "*.heic", "*.png", "*.mov", "*.mp4")

# --- Skript-Logik ---

if ($DryRun) {
    # --- PHASE 1: ANALYSE ---
    Write-Host "PHASE 1: ANALYSE - Suche nach Duplikaten und erstelle Aktionsplan." -ForegroundColor Yellow

    Write-Host "Suche nach Mediendateien in '$Arbeitsordner'..." -ForegroundColor Green
    $allFiles = Get-ChildItem -Path $Arbeitsordner -Recurse -File -Include $mediaExtensions -Exclude "*\_DUPLICATES_TO_DELETE\*"

    Write-Host "Es wurden $($allFiles.Count) Dateien gefunden."
    Write-Host "Gruppiere Dateien nach Groesse und Typ, um Duplikate zu finden..."
    $duplicateGroups = $allFiles | Group-Object -Property Length, Extension | Where-Object { $_.Count -gt 1 }

    if ($duplicateGroups.Count -eq 0) {
        Write-Host "Keine Duplikate basierend auf Groesse und Typ gefunden." -ForegroundColor Green
        if (Test-Path $PlanFile) { Remove-Item $PlanFile } # Alten Plan loeschen
        pause
        return
    }

    Write-Host "Es wurden $($duplicateGroups.Count) Gruppen von moeglichen Duplikaten gefunden." -ForegroundColor Yellow
    
    $actionPlan = [System.Collections.Generic.List[object]]::new()

    foreach ($group in $duplicateGroups) {
        $sortedFiles = $group.Group | Sort-Object -Property CreationTime
        $originalFile = $sortedFiles | Select-Object -First 1
        $duplicateFiles = $sortedFiles | Select-Object -Skip 1
        
        $originalBaseName = $originalFile.BaseName
        $originalExtension = $originalFile.Extension

        # Aktion fuer das Original definieren (KOPIEREN)
        $quarantineOriginalName = "${originalBaseName}_original${originalExtension}"
        $quarantineOriginalPath = Join-Path -Path $QuarantineFolder -ChildPath $quarantineOriginalName
        $actionPlan.Add([PSCustomObject]@{
            Action = "Copy"
            Source = $originalFile.FullName
            Destination = $quarantineOriginalPath
            OriginalName = $originalFile.FullName
        })

        # Aktionen fuer die Duplikate definieren (VERSCHIEBEN)
        $counter = 1
        foreach ($dupFile in $duplicateFiles) {
            $quarantineDuplicateName = "${originalBaseName}_${counter}${originalExtension}"
            $quarantineDuplicatePath = Join-Path -Path $QuarantineFolder -ChildPath $quarantineDuplicateName
            $actionPlan.Add([PSCustomObject]@{
                Action = "Move"
                Source = $dupFile.FullName
                Destination = $quarantineDuplicatePath
                OriginalName = $dupFile.FullName
            })
            $counter++
        }
    }

    Write-Host "------------------------------------------------------------"
    Write-Host "[SIMULATION] Die folgenden Aktionen wuerden ausgefuehrt:" -ForegroundColor Cyan
    $actionPlan | ForEach-Object {
        Write-Host "$($_.Action) '$($_.Source)' nach '$($_.Destination)'"
    }
    Write-Host "------------------------------------------------------------"

    # Speichere den Plan als JSON-Datei
    $actionPlan | ConvertTo-Json -Depth 5 | Out-File -FilePath $PlanFile -Encoding UTF8
    Write-Host "Aktionsplan wurde erfolgreich in '$PlanFile' gespeichert." -ForegroundColor Green
    Write-Host "Um diese Aktionen auszufuehren, setzen Sie `$DryRun = `$false` und fuehren das Skript erneut aus."

} else {
    # --- PHASE 2: AUSFUEHRUNG ---
    Write-Host "PHASE 2: AUSFUEHRUNG - Lese und verarbeite Aktionsplan." -ForegroundColor Yellow

    if (-not (Test-Path -Path $PlanFile)) {
        Write-Host "FEHLER: Konnte keinen Aktionsplan ('$PlanFile') finden." -ForegroundColor Red
        Write-Host "Bitte fuehren Sie das Skript zuerst im Analyse-Modus (`$DryRun = `$true`) aus." -ForegroundColor Red
        pause
        return
    }

    $actionPlan = Get-Content -Path $PlanFile | ConvertFrom-Json
    
    if ($actionPlan.Count -eq 0) {
        Write-Host "Aktionsplan ist leer. Nichts zu tun." -ForegroundColor Green
        Remove-Item $PlanFile
        pause
        return
    }

    Write-Host "Aktionsplan mit $($actionPlan.Count) Aktionen wird ausgefuehrt..."

    # Erstelle den Quarantaene-Ordner, falls er nicht existiert
    if (-not (Test-Path -Path $QuarantineFolder)) {
        New-Item -Path $QuarantineFolder -ItemType Directory | Out-Null
    }

    foreach ($action in $actionPlan) {
        try {
            Write-Host "$($action.Action) '$($action.Source)' nach '$($action.Destination)'" -ForegroundColor Magenta
            if ($action.Action -eq "Copy") {
                [System.IO.File]::Copy($action.Source, $action.Destination)
            } elseif ($action.Action -eq "Move") {
                [System.IO.File]::Move($action.Source, $action.Destination)
            }
        } catch {
            Write-Warning "FEHLER bei der Ausfuehrung der Aktion fuer '$($action.Source)': $($_.Exception.Message)"
        }
    }

    # Plan nach erfolgreicher Ausfuehrung loeschen
    Remove-Item $PlanFile
    
    Write-Host "------------------------------------------------------------"
    Write-Host "Alle Aktionen aus dem Plan wurden ausgefuehrt." -ForegroundColor Green
    Write-Host "Alle gefundenen Duplikate wurden in den Ordner '$QuarantineFolder' verschoben/kopiert." -ForegroundColor Yellow
    Write-Host "Bitte ueberpruefen Sie den Inhalt und loeschen Sie den Ordner manuell." -ForegroundColor Yellow
}

pause
