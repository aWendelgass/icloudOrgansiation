# Workflow for organising media files

This project contains a set of PowerShell scripts that perform a four-step process to enrich media metadata (images and videos) with address information. The ultimate goal is to create a comprehensive CSV file that can be used to organise (e.g. rename, move) your media files.

## How it works

The process is divided into four main scripts that must be executed in sequence. Each script creates a file that is used as input by the next script.

1.  **`1_Export-Media-Data.ps1`**: Extracts metadata such as creation date and GPS coordinates from all media files (`.jpg`, `.jpeg`, `.heic`, `.png`, `.mov`, `.mp4`) in the current directory and its subdirectories.

2.  **`2_Extrakt-Koordinatengruppen.ps1`**: Analyses the extracted GPS coordinates and groups them to reduce the number of unique locations. This is an optimisation step to minimise the number of API requests in the next step.

3.  **`3_Fetch-Adressen.ps1`**: Uses the grouped coordinates to retrieve the associated physical addresses via an external API (Geoapify).

4.  **`4_Merge-Data.ps1`**: Adds the retrieved addresses to the original metadata and creates a final, enriched CSV file.



## Prerequisites

Before running the scripts, make sure that the following requirements are met:

1. **Operating system**: Windows with PowerShell.
2. **ExifTool**: The tool `exiftool.exe` must be installed. You can download it from the [official ExifTool website](https://exiftool.org/). Make sure that the `exiftool.exe` is either in the same folder as the scripts or is included in the system PATH so that it can be called from anywhere.
3 **Geoapify API key**: You will need a free API key from the geodata service [Geoapify](https://www.geoapify.com/).
    * Register on [myprojects.geoapify.com](https://myprojects.geoapify.com).
    * Create a new project.
    * Generate an API key.

## Execution

Execute the following steps to start the process:



### 1. configuration

1 **Place scripts**: Copy the four PS1 and the four BAT files into the same directory where your image and video files (or the folders containing them) are located. The first script searches all subfolders for media files.
2. enter **API key**: Open the file `3_Fetch-Addresses.ps1` in a text editor. Find the following line and replace the placeholder key with your personal Geoapify API key:
 ```powershell
 $ApiKey = "1234567890abcdefghijklmnopqrstuv"
 ```

### 2. execute scripts

For each PowerShell script (`.ps1`) there is an associated batch file (`.bat`). **Execute the batch files in the correct order** by double-clicking on them. The batch files take care of temporarily adapting the PowerShell execution guidelines and starting the respective script.

Execute the files in this order:



1.  `1_doExport-Media-Data.bat`
2.  `2_doExtrakt-Koordinatengruppen.bat`
3.  `3_doFetch-Adressen.bat` (Dieser Schritt kann je nach Anzahl der Standorte einige Zeit dauern)
4.  `4_doMerge-Data.bat`

### 3rd result

After the last script has been completed, you will find a file named `4_Media-Export_extended.csv` in the directory. This CSV file contains a list of all your media files together with the original metadata and the newly added addresses.

**Example of the final CSV file:**

| Pfad | Dateiname | Erstelldatum_Zeit_des_Mediums | latitude | longitude | Adresse |
| :--- | :--- | :--- | :--- | :--- | :--- |
| C:\Fotos\Urlaub | IMG_123.jpg | 2023-08-15 14:30:00 | 48.13052 | 10.99327 | Ritterschwemme zu Kaltenberg, Schloßstraße 11, 82269 Kaltenberg, Germany |
| C:\Fotos\Urlaub | IMG_124.jpg | 2023-08-15 14:32:10 | 48.13052 | 10.99327 | Ritterschwemme zu Kaltenberg, Schloßstraße 11, 82269 Kaltenberg, Germany |

This file can now be used as the basis for further automation (e.g. with Excel, Python or other tools) to organise your media library.



-----


# Workflow zur Organisation von Medien-Dateien

Dieses Projekt enthält einen Satz von PowerShell-Skripten, die einen vierstufigen Prozess zur Anreicherung von Medien-Metadaten (Bilder und Videos) mit Adressinformationen durchführen. Das ultimative Ziel ist es, eine umfassende CSV-Datei zu erstellen, die für die Organisation (z.B. Umbenennen, Verschieben) Ihrer Mediendateien verwendet werden kann.

## Funktionsweise

Der Prozess ist in vier Hauptskripte unterteilt, die nacheinander ausgeführt werden müssen. Jedes Skript erzeugt eine Datei, die vom nächsten Skript als Eingabe verwendet wird.

1.  **`1_Export-Media-Data.ps1`**: Extrahiert Metadaten wie Erstellungsdatum und GPS-Koordinaten aus allen Medien-Dateien (`.jpg`, `.jpeg`, `.heic`, `.png`, `.mov`, `.mp4`) im aktuellen Verzeichnis und dessen Unterverzeichnissen.
2.  **`2_Extrakt-Koordinatengruppen.ps1`**: Analysiert die extrahierten GPS-Koordinaten und gruppiert sie, um die Anzahl der eindeutigen Standorte zu reduzieren. Dies ist ein Optimierungsschritt, um die Anzahl der API-Anfragen im nächsten Schritt zu minimieren.
3.  **`3_Fetch-Adressen.ps1`**: Verwendet die gruppierten Koordinaten, um über eine externe API (Geoapify) die zugehörigen physischen Adressen abzurufen.
4.  **`4_Merge-Data.ps1`**: Fügt die abgerufenen Adressen den ursprünglichen Metadaten hinzu und erstellt eine finale, angereicherte CSV-Datei.

## Voraussetzungen

Bevor Sie die Skripte ausführen, stellen Sie sicher, dass die folgenden Anforderungen erfüllt sind:

1.  **Betriebssystem**: Windows mit PowerShell.
2.  **ExifTool**: Das Tool `exiftool.exe` muss installiert sein. Sie können es von der [offiziellen ExifTool-Website](https://exiftool.org/) herunterladen. Stellen Sie sicher, dass die `exiftool.exe` entweder in demselben Ordner wie die Skripte liegt oder im System-PATH enthalten ist, damit sie von überall aus aufgerufen werden kann.
3.  **Geoapify API-Schlüssel**: Sie benötigen einen kostenlosen API-Schlüssel vom Geodatendienst [Geoapify](https://www.geoapify.com/).
    *   Registrieren Sie sich auf [myprojects.geoapify.com](https://myprojects.geoapify.com).
    *   Erstellen Sie ein neues Projekt.
    *   Generieren Sie einen API-Schlüssel.

## Ausführung

Führen Sie die folgenden Schritte aus, um den Prozess zu starten:

### 1. Konfiguration

1.  **Skripte Platzieren**: Kopieren Sie die vier PS1 und die vier BAT Dateien in dasselbe Verzeichnis, in dem sich Ihre Bild- und Videodateien (oder die Ordner, die sie enthalten)  befinden. Das erste Skript durchsucht alle Unterordner nach Mediendateien.
2.  **API-Schlüssel eintragen**: Öffnen Sie die Datei `3_Fetch-Adressen.ps1` in einem Texteditor. Suchen Sie die folgende Zeile und ersetzen Sie den Platzhalter-Schlüssel durch Ihren persönlichen Geoapify API-Schlüssel:
    ```powershell
    $ApiKey = "1234567890abcdefghijklmnopqrstuv"
    ```

### 2. Skripte ausführen

Für jedes PowerShell-Skript (`.ps1`) gibt es eine zugehörige Batch-Datei (`.bat`). **Führen Sie die Batch-Dateien in der richtigen Reihenfolge aus**, indem Sie sie doppelt anklicken. Die Batch-Dateien kümmern sich darum, die PowerShell-Ausführungsrichtlinien temporär anzupassen und das jeweilige Skript zu starten.

Führen Sie die Dateien in dieser Reihenfolge aus:

1.  `1_doExport-Media-Data.bat`
2.  `2_doExtrakt-Koordinatengruppen.bat`
3.  `3_doFetch-Adressen.bat` (Dieser Schritt kann je nach Anzahl der Standorte einige Zeit dauern)
4.  `4_doMerge-Data.bat`

### 3. Ergebnis

Nachdem das letzte Skript abgeschlossen ist, finden Sie im Verzeichnis eine Datei mit dem Namen `4_Media-Export_extended.csv`. Diese CSV-Datei enthält eine Liste aller Ihrer Mediendateien zusammen mit den ursprünglichen Metadaten und den neu hinzugefügten Adressen.

**Beispiel für die finale CSV-Datei:**

| Pfad | Dateiname | Erstelldatum_Zeit_des_Mediums | latitude | longitude | Adresse |
| :--- | :--- | :--- | :--- | :--- | :--- |
| C:\Fotos\Urlaub | IMG_123.jpg | 2023-08-15 14:30:00 | 48.13052 | 10.99327 | Ritterschwemme zu Kaltenberg, Schloßstraße 11, 82269 Kaltenberg, Germany |
| C:\Fotos\Urlaub | IMG_124.jpg | 2023-08-15 14:32:10 | 48.13052 | 10.99327 | Ritterschwemme zu Kaltenberg, Schloßstraße 11, 82269 Kaltenberg, Germany |

Diese Datei kann nun als Grundlage für weitere Automatisierungen (z.B. mit Excel, Python oder anderen Werkzeugen) zur Organisation Ihrer Medienbibliothek dienen.

