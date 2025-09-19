# ===================================================================
# Skript zum Extrahieren bzw. vorbereiten von GEO Daten
#
# Das Skript gehört zu einem Set of 5: Wenn alles ordnungsgemäß abläuft 
# könnt ihr damit eine beliebiege Verzeichnissttruktur  von Bild und 
# Video Medien organsieren. Das heisst: Umbenennen, verschieben, 
# doppelte entfernen. 
#
# 2_Extrakt-Koordinatengruppen.ps1
#
# ** Damit das Skript ausgeführt werden kann müssen die Policies **
# ** Für die Dauer des Prozesses geändert werden, dazu habe ich  **
# ** Die Batchdatei 2_doExtrakt-Koordinatengruppen.bat erstellt, **
# ** die kümmert sich darum und ruft das Script auf              **
#
# Das Skript stellt Lat und Long Koordinaten zu einem Koordinatenpaar X#Y zusammen
# Die Genaugukeit wurde auf 5 Stellen hinterm Komma reduziert, damit sind wir auf 
# Hausnummern Genauigkeit.
#        
# Sinn ist: Wir werden im  nächsten Skript die Reverse Geocoding API nutzen. Diese erlaubt
# jedoch nur ca 1 Abfrage pro Sekunde und bremmst dann ein. Um die Abfrage zu reduzieren
# kabe ich die Lokalitäten geclustert. Diese Clusterung wird in diesem Skriot druchgeführt.                            t
#             
# Die 1_Media-Export.csv aus dem esten Skript wird dazu eingelesen und eine einfache Tabelle erzeugt
#
# 25,34886#51,52943
# 48,13052#10,99327
# 8,13052#10,99329
# 25,34798#51,53084
# 25,34862#51,52973

# Im nächsten Skript werden dann nur diese Cluster über die Reverse Geocoding API abgefragt
# Die Adressdaten werden später den Bildern wieder zugeordnet. In meinem Fall reduzierte das 
# den Aufwand von 100.000 Abfragen auf ca. 5000 Abfragen und diese reduzierte Abfrage dauert 
# schon kanpp über eine Stunde

# Die Ausgabedatei ist der Input für das nöchste Skript: 3_Fetch-Adressen.ps1


#region Konfiguration
$InputCsv_Full = Join-Path -Path $PSScriptRoot -ChildPath "1_Media-Export.csv"
$OutputCsv_Unique = Join-Path -Path $PSScriptRoot -ChildPath "2_Koordinaten-Export.csv"
#endregion

Write-Host "Lese große Datendatei ein..."
$fullData = Import-Csv -Path $InputCsv_Full -Delimiter ';'

$uniqueKeys = @{}
Write-Host "Analysiere $($fullData.Count) Datensätze..."
foreach ($row in $fullData) {
    if ($row.latitude -and $row.longitude -and $row.latitude -ne "") {
        # FINALE LOGIK: Normalisiert den Input (ersetzt Komma durch Punkt) und arbeitet dann nur noch mit Text.
        $latNormalized = $row.latitude.Replace(',', '.')
        $lonNormalized = $row.longitude.Replace(',', '.')

        if ($latNormalized.Contains('.')) {
            $latParts = $latNormalized.Split('.')
            # Baut den finalen Schlüssel mit Komma wieder zusammen
            $latRounded = $latParts[0] + "," + $latParts[1].PadRight(5, '0').Substring(0, 5)

            $lonParts = $lonNormalized.Split('.')
            $lonRounded = $lonParts[0] + "," + $lonParts[1].PadRight(5, '0').Substring(0, 5)

            $key = "$latRounded#$lonRounded"
            $uniqueKeys[$key] = $true
        }
    }
}
$resultList = [System.Collections.Generic.List[object]]::new()
foreach($key in $uniqueKeys.Keys) { $resultList.Add([PSCustomObject]@{ LATLONG = $key }) }
Write-Host "$($resultList.Count) einzigartige Koordinaten gefunden. Speichere..."
$resultList | Export-Csv -Path $OutputCsv_Unique -Delimiter ';' -NoTypeInformation -Encoding UTF8
Write-Host "Fertig!" -ForegroundColor Green