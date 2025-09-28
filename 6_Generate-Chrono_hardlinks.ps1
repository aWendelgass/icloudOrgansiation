# --- KONFIGURATION ---
# Der Name des Ordners, in dem alle Hardlinks gesammelt werden.
$chronoFolderName = "@CHRONOLOGISCH"

# --- SKRIPT-LOGIK ---
# Startpunkt ist das Verzeichnis, in dem das Skript liegt.
$startDirectory = Get-Location
$chronoPath = Join-Path -Path $startDirectory.Path -ChildPath $chronoFolderName

Write-Host "Starte die Erstellung der chronologischen Hardlinks..." -ForegroundColor Cyan

# 1. Erstelle das Zielverzeichnis, falls es nicht existiert.
if (-not (Test-Path -Path $chronoPath)) {
    Write-Host "Verzeichnis '$chronoFolderName' wird erstellt..." -ForegroundColor Yellow
    New-Item -Path $chronoPath -ItemType Directory | Out-Null
} else {
    Write-Host "Verzeichnis '$chronoFolderName' existiert bereits." -ForegroundColor Green
}

# 2. Finde alle Dateien in allen Unterordnern, aber schließe den chronologischen Ordner selbst aus.
Write-Host "Suche nach allen Quelldateien..."
$allFiles = Get-ChildItem -Path $startDirectory.Path -Recurse -File -Exclude $chronoFolderName

if ($allFiles.Count -eq 0) {
    Write-Host "Keine Dateien zur Verlinkung gefunden." -ForegroundColor Red
    exit
}

Write-Host "$($allFiles.Count) Dateien gefunden. Erstelle nun die Hardlinks..." -ForegroundColor Green

# 3. Gehe jede Datei durch und erstelle den Hardlink.
foreach ($file in $allFiles) {
    # 3.1. Generiere den neuen Dateinamen für den Link.
    
    # KORREKTUR: Zerlege den Dateinamen in Basisname und Endung.
    $baseName = $file.BaseName
    $extension = $file.Extension # z.B. ".jpg"
    
    # Hole den relativen Pfad der Datei (z.B. "Ägypten\Al Ismailiya")
    $relativePath = $file.DirectoryName.Substring($startDirectory.Path.Length).TrimStart('\')
    
    # Ersetze alle '\' durch '_'
    $modifiedPath = $relativePath -replace '\\', '_'
    
    # KORREKTUR: Baue den finalen Namen so zusammen, dass die Endung am Schluss steht.
    $linkName = if ([string]::IsNullOrEmpty($modifiedPath)) {
        $file.Name # Wenn kein Pfad vorhanden, nutze Originalnamen
    } else {
        "$($baseName)-$($modifiedPath)$($extension)"
    }
    
    # Der volle Pfad für den neuen Hardlink
    $linkPath = Join-Path -Path $chronoPath -ChildPath $linkName
    
    # 3.2. Erstelle den Hardlink.
    try {
        # -Force sorgt dafür, dass ein bereits existierender Link überschrieben wird.
        New-Item -Path $linkPath -ItemType HardLink -Value $file.FullName -Force -ErrorAction Stop
        Write-Host "Link erstellt: $linkName"
    }
    catch {
        Write-Host "FEHLER beim Erstellen des Links für $($file.FullName): $_" -ForegroundColor Red
    }
}

Write-Host "Vorgang abgeschlossen!" -ForegroundColor Cyan