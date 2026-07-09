# Get-Iata.ps1
# Extract airports from Wikipedia A-Z IATA list pages
# Output columns: Country, Province, Airport Name, IATA code, ICAO code

$OutputCsv  = "C:\Projects\iata_airports_all.csv"
$OutputXlsx = "C:\Projects\iata_airports_all.xlsx"

$letters = 65..90 | ForEach-Object { [char]$_ }
$rows = New-Object System.Collections.Generic.List[object]

function Clean-WikiText {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ""
    }

    $t = $Text

    $t = $t -replace "<ref.*?</ref>", ""
    $t = $t -replace "<.*?>", ""
    $t = $t -replace "\{\{.*?\}\}", ""
    $t = $t -replace "\[\[(.*?\|)?(.*?)\]\]", '$2'
    $t = $t -replace "'''", ""
    $t = $t -replace "''", ""
    $t = $t -replace "&nbsp;", " "
    $t = $t -replace "\s+", " "

    return $t.Trim()
}

function Parse-LocationParts {
    param([string]$Location)

    $country = ""
    $province = ""

    if ([string]::IsNullOrWhiteSpace($Location)) {
        return [PSCustomObject]@{
            Country  = ""
            Province = ""
        }
    }

    $parts = $Location.Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }

    if ($parts.Count -ge 1) {
        $country = $parts[$parts.Count - 1]
    }

    if ($parts.Count -ge 3) {
        $province = $parts[$parts.Count - 2]
    }

    return [PSCustomObject]@{
        Country  = $country
        Province = $province
    }
}

foreach ($letter in $letters) {
    $url = "https://en.wikipedia.org/w/index.php?title=List_of_airports_by_IATA_airport_code:_$letter&action=raw"
    Write-Host "Processing letter $letter ..." -ForegroundColor Cyan

    try {
        $content = (Invoke-WebRequest -Uri $url -UseBasicParsing).Content
        $lines = $content -split "`r?`n"

        foreach ($line in $lines) {
            if (-not $line.StartsWith("|")) { continue }
            if ($line.StartsWith("|-")) { continue }
            if ($line.StartsWith("|}")) { continue }

            $cells = $line.Substring(1).Split("||")

            if ($cells.Count -lt 4) { continue }

            # Correct order from Wikipedia airport table row:
            # ICAO | IATA | airport | location
            $icaoRaw = $cells[0].Trim()
            $iataRaw = $cells[1].Trim()
            $airportRaw = $cells[2].Trim()
            $locationRaw = $cells[3].Trim()

            $icao = Clean-WikiText $icaoRaw
            $iata = Clean-WikiText $iataRaw
            $airportName = Clean-WikiText $airportRaw
            $location = Clean-WikiText $locationRaw

            if ($iata -notmatch '^[A-Z0-9]{3}$') { continue }

            $loc = Parse-LocationParts -Location $location

            $rows.Add([PSCustomObject]@{
                Country = $loc.Country
                Province = $loc.Province
                'Airport Name' = $airportName
                'IATA code' = $iata
                'ICAO code' = $icao
            }) | Out-Null
        }

        Write-Host "Done $letter" -ForegroundColor Green
    }
    catch {
        Write-Warning ("Failed for letter " + $letter + ": " + $_.Exception.Message)
    }
}

$final = $rows |
    Where-Object { $_.'IATA code' -and $_.'Airport Name' } |
    Sort-Object 'IATA code' -Unique

$final | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host "CSV saved to $OutputCsv with $($final.Count) rows." -ForegroundColor Yellow

if (Get-Module -ListAvailable -Name ImportExcel) {
    $final | Export-Excel -Path $OutputXlsx -WorksheetName "IATA Airports" -AutoSize
    Write-Host "Excel saved to $OutputXlsx" -ForegroundColor Yellow
}
else {
    Write-Host "ImportExcel module not found; Excel file not created." -ForegroundColor DarkYellow
    Write-Host "Install it with: Install-Module ImportExcel -Scope CurrentUser"
}