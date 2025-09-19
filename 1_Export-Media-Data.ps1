# ===================================================================
# Skript zum Extrahieren von Medien-Metadaten mittels EXIFTOOL
#
# Das Skript gehört zu einem Set of 5: Wenn alles ordnungsgemäß abläuft 
# könnt ihr damit eine beliebiege Verzeichnissttruktur  von Bild und 
# Video Medien organsieren. Das heisst: Umbenennen, verschieben, 
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
# Diese besitzt die folgrenden Spalten
#
#  - Pfad
#  - Dateiname
#  - Dateiname_ohne_Extension
#  - Extension
#  - Erstelldatum_Zeit_des_Mediums: Falls der Wert nicht exisitiert, wird das füheste Datum oder das Dateidatum verwendet
#  - latitude
#  - longitude
#
# Die Ausgabedatei ist der Input für das nöchste Skriot: 2_Extrakt-Koordinatengruppen.ps1
#
# ===================================================================

# Dynamische Pfadermittlung über den Speicherort des Skripts
$Arbeitsordner = $PSScriptRoot
$Zieldatei_CSV = Join-Path -Path $Arbeitsordner -ChildPath "1_Media-Export.csv"

# ExifTool-Prüfung
if (-not (Get-Command exiftool -ErrorAction SilentlyContinue)) {
    Write-Host "FEHLER: exiftool.exe wurde nicht gefunden." -ForegroundColor Red
    pause
    return
}

Write-Host "Arbeitsordner ist: $Arbeitsordner" -ForegroundColor Green
Write-Host "Die Ausgabatei wird sein: $Zieldatei_CSV" -ForegroundColor Green

$mediaExtensions = @("*.jpg", "*.jpeg", "*.heic", "*.png", "*.mov", "*.mp4")
$dateien = Get-ChildItem -Path $Arbeitsordner -Recurse -File -Include $mediaExtensions
$ergebnisliste = [System.Collections.Generic.List[object]]::new()

if ($dateien.Count -eq 0) {
    Write-Warning "Es wurden keine passenden Mediendateien im Ordner gefunden."
    pause
    return
}

Write-Host "Es wurden $($dateien.Count) Dateien gefunden. Beginne mit der Verarbeitung..."

$zaehler = 0
$gesamt = $dateien.Count

foreach ($datei in $dateien) {
    $zaehler++
    Write-Progress -Activity "Extrahiere Metadaten" -Status "Verarbeite $($datei.Name)" -PercentComplete (($zaehler / $gesamt) * 100)

    try {
        $exifJson = exiftool -j -n -S -TrackCreateDate -DateTimeOriginal -CreateDate -FileModifyDate -GPSLatitude -GPSLongitude $datei.FullName

        if ($exifJson) {
            $meta = $exifJson | ConvertFrom-Json | Select-Object -First 1
            $mediumErstelltDatum = $null
            $dateString = $null

            # Priorität 1: Die "goldenen" EXIF-Tags
            if ($meta.TrackCreateDate) {
                $dateString = $meta.TrackCreateDate
            } elseif ($meta.DateTimeOriginal) {
                $dateString = $meta.DateTimeOriginal
            } elseif ($meta.CreateDate) {
                $dateString = $meta.CreateDate
            }

            if ($dateString) {
                # Konvertiere den EXIF-String in ein Objekt
                try {
                    $datePart = $dateString.Substring(0, 10).Replace(':', '-')
                    $timePart = $dateString.Substring(11)
                    $cleanDateString = "$datePart $timePart"
                    $mediumErstelltDatum = [datetime]$cleanDateString
                } catch {
                    Write-Warning "Konnte primäres Datumsformat '$dateString' für Datei $($datei.Name) nicht verarbeiten."
                }
            }
            
            # Fallback, wenn kein primäres Datum gefunden oder konvertiert werden konnte
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
                        Write-Warning "Konnte Fallback-Datumsformat '$modifyDateString' für Datei $($datei.Name) nicht verarbeiten."
                    }
                }
            }

            # ======================= HIER IST DIE ÄNDERUNG =======================
            $objekt = [PSCustomObject]@{
                Pfad                         = $datei.DirectoryName # NEU: Der Pfad zum Ordner
                Dateiname                    = $datei.Name           # NEU: Der vollständige Dateiname
                Dateiname_ohne_Extension     = $datei.BaseName
                Extension                    = $datei.Extension
                Erstelldatum_Zeit_des_Mediums = $mediumErstelltDatum
                latitude                     = $meta.GPSLatitude
                longitude                    = $meta.GPSLongitude
            }
            # =====================================================================
            
            $ergebnisliste.Add($objekt)
        }
    } catch {
        Write-Warning "Ein unerwarteter Fehler ist bei der Verarbeitung von $($datei.FullName) aufgetreten: $_"
    }
}

Write-Host "Verarbeitung abgeschlossen. Speichere Ergebnisse..." -ForegroundColor Green
# FINALE KORREKTUR: Formatiere alle Datumsobjekte einheitlich beim Export
$ergebnisliste | ForEach-Object {
    if ($_.Erstelldatum_Zeit_des_Mediums -is [datetime]) {
        $_.Erstelldatum_Zeit_des_Mediums = $_.Erstelldatum_Zeit_des_Mediums.ToString("yyyy-MM-dd HH:mm:ss")
    }
    $_
} | Export-Csv -Path $Zieldatei_CSV -Delimiter ';' -NoTypeInformation -Encoding UTF8
Write-Host "Fertig! Die Datei '$Zieldatei_CSV' wurde erfolgreich erstellt." -ForegroundColor Cyan