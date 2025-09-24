# ===================================================================
# Skript zum Extrahieren von Medien-Metadaten mittels EXIFTOOL
#
# Das Skript gehört zu einem Set of 5: Wenn alles ordnungsgemäß abläuft 
# könnt ihr damit eine beliebige Verzeichnisstruktur  von Bild und 
# Video Medien organisieren. Das heisst: Umbenennen, verschieben, 
# doppelte entfernen. 
#
# 1_Export-Media-Data.ps1
#
# ** Damit das Skript ausgeführt werden kann müssen die Policies  **
# ** Für die Dauer des Prozesses geändert werden, dazu habe ich   **
# ** Die Batchdatei 1_doExport-Media-Data.bat erstellt, die       **
# ** kümmert sich darum und ruft das Script auf                   **
#
# Das Skript stellt Lat und Long Koordinaten zu einem Koordinatenpaar X#Y zusammen
# Es wird eine CSV Datei erstellt: 1_Media-Export.csv
# Diese besitzt die folgenden Spalten
#
#  - Pfad
#  - Dateiname
#  - Dateiname_ohne_Extension
#  - Extension
#  - Datumsstempel_fuer_Dateiname
#  - latitude
#  - longitude
#
# Die Ausgabedatei ist der Input für das nächste Skript: 2_Extrakt-Koordinatengruppen.ps1
#
# ===================================================================



# --- Konfiguration ---
$SkriptName = "Skript 1: Media-Daten Export"
$Arbeitsordner = $PSScriptRoot
$Zieldatei_CSV = Join-Path -Path $Arbeitsordner -ChildPath "1_Media-Export.csv"

# --- Lade Logging Modul ---
try {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath "MediaWorkflowLogger.psm1")
} catch {
    Write-Host "FEHLER: Das Logging-Modul 'MediaWorkflowLogger.psm1' konnte nicht geladen werden." -ForegroundColor Red
    pause
    return
}

# --- Skript-Logik ---

# Setze Konsolen-Encoding auf UTF-8, um die Ausgabe von externen Tools korrekt zu lesen
[System.Console]::InputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ExifTool-Pruefung
if (-not (Get-Command exiftool -ErrorAction SilentlyContinue)) {
    Write-StructuredLog -LogLevel ERROR -SkriptName $SkriptName -Message "exiftool.exe wurde nicht gefunden."
    pause
    return
}

Write-StructuredLog -LogLevel INFO -SkriptName $SkriptName -Message "Arbeitsordner ist: $Arbeitsordner"
Write-StructuredLog -LogLevel INFO -SkriptName $SkriptName -Message "Die Ausgabedatei wird sein: $Zieldatei_CSV"

$mediaExtensions = @("*.jpg", "*.jpeg", "*.heic", "*.png", "*.mov", "*.mp4")
$dateien = Get-ChildItem -Path $Arbeitsordner -Recurse -File -Include $mediaExtensions
$ergebnisliste = [System.Collections.Generic.List[object]]::new()

if ($dateien.Count -eq 0) {
    Write-StructuredLog -LogLevel WARN -SkriptName $SkriptName -Message "Es wurden keine passenden Mediendateien im Ordner gefunden."
    pause
    return
}

Write-StructuredLog -LogLevel INFO -SkriptName $SkriptName -Message "Es wurden $($dateien.Count) Dateien gefunden. Beginne mit der Verarbeitung..."

$zaehler = 0
$gesamt = $dateien.Count

foreach ($datei in $dateien) {
    $zaehler++
    Write-Progress -Activity "Extrahiere Metadaten" -Status "Verarbeite $($datei.Name)" -PercentComplete (($zaehler / $gesamt) * 100)

    try {
        $exifJson = exiftool -j -n -S -charset utf8 -TrackCreateDate -DateTimeOriginal -CreateDate -FileModifyDate -GPSLatitude -GPSLongitude $datei.FullName

        if ($exifJson) {
            $meta = $exifJson | ConvertFrom-Json | Select-Object -First 1
            $mediumErstelltDatum = $null
            $dateString = $null

            if ($meta.TrackCreateDate) { $dateString = $meta.TrackCreateDate }
            elseif ($meta.DateTimeOriginal) { $dateString = $meta.DateTimeOriginal }
            elseif ($meta.CreateDate) { $dateString = $meta.CreateDate }

            if ($dateString) {
                try {
                    $datePart = $dateString.Substring(0, 10).Replace(':', '-')
                    $timePart = $dateString.Substring(11)
                    $cleanDateString = "$datePart $timePart"
                    $mediumErstelltDatum = [datetime]$cleanDateString
                } catch {
                    Write-StructuredLog -LogLevel WARN -SkriptName $SkriptName -Message "Konnte primaeres Datumsformat '$dateString' nicht verarbeiten." -FileObject $datei
                }
            }
            
            if (-not $mediumErstelltDatum) {
                $modifyDateString = $meta.FileModifyDate
                $createDateObject = $datei.CreationTime
                $mediumErstelltDatum = $createDateObject

                if ($modifyDateString) {
                    try {
                        $datePart = $modifyDateString.Substring(0, 10).Replace(':', '-')
                        $timePart = $modifyDateString.Substring(11)
                        $cleanDateString = "$datePart $timePart"
                        $modifyDateObject = [datetime]$cleanDateString
                        if ($modifyDateObject -lt $createDateObject) {
                            $mediumErstelltDatum = $modifyDateObject
                        }
                    } catch {
                        Write-StructuredLog -LogLevel WARN -SkriptName $SkriptName -Message "Konnte Fallback-Datumsformat '$modifyDateString' nicht verarbeiten." -FileObject $datei
                    }
                }
            }

            $objekt = [PSCustomObject]@{
                Pfad                          = $datei.DirectoryName
                Dateiname                     = $datei.Name
                Dateiname_ohne_Extension      = $datei.BaseName
                Extension                     = $datei.Extension
                Datumsstempel_fuer_Dateiname  = if ($mediumErstelltDatum) { $mediumErstelltDatum.ToString("yyyyMMdd_HHmmss") } else { "" }
                latitude                      = $meta.GPSLatitude
                longitude                     = $meta.GPSLongitude
            }
            
            $ergebnisliste.Add($objekt)
        }
    } catch {
        Write-StructuredLog -LogLevel ERROR -SkriptName $SkriptName -Message "Ein unerwarteter Fehler ist aufgetreten: $($_.Exception.Message)" -FileObject $datei
    }
}

Write-StructuredLog -LogLevel INFO -SkriptName $SkriptName -Message "Verarbeitung abgeschlossen. Speichere Ergebnisse..."
$ergebnisliste | Export-Csv -Path $Zieldatei_CSV -Delimiter ';' -NoTypeInformation -Encoding UTF8
Write-StructuredLog -LogLevel INFO -SkriptName $SkriptName -Message "Fertig! Die Datei '$Zieldatei_CSV' wurde erfolgreich erstellt."
pause
