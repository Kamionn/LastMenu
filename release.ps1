# LastMenu — Release helper
# Reads the version from ./version, creates a git tag and pushes it.
# GitHub Actions (.github/workflows/release.yml) then creates the GitHub release.
#
# Usage: .\release.ps1

$raw     = Get-Content .\version -Raw
$match   = [regex]::Match($raw, 'version\s*=\s*([\d.]+)')

if (-not $match.Success) {
    Write-Error "Could not read version from ./version"
    exit 1
}

$version = $match.Groups[1].Value
$tag     = "v$version"

# Check tag does not already exist locally or on remote
$local = git tag -l $tag
if ($local) {
    Write-Error "Tag $tag already exists locally. Bump the version first."
    exit 1
}

Write-Host ""
Write-Host "  LastMenu $tag"
Write-Host ""

git tag $tag
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

git push origin $tag
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ""
Write-Host "  Tag $tag pushed. GitHub Actions will create the release automatically."
Write-Host ""
