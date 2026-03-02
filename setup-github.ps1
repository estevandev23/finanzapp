#!/usr/bin/env pwsh
# setup-github.ps1
# Conecta los repositorios locales a GitHub y configura los submodules.
# Uso: .\setup-github.ps1 -GithubUser "tu-usuario"

param(
    [Parameter(Mandatory = $true)]
    [string]$GithubUser
)

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot

function Push-Repo {
    param([string]$dir, [string]$remote)
    Write-Host "`n>> $dir -> $remote"
    Push-Location $dir
    git remote add origin $remote
    git push -u origin main
    Pop-Location
}

# 1. Subir los tres proyectos a sus repos individuales
Push-Repo "$root\finanzapp"     "https://github.com/$GithubUser/finanzapp-api.git"
Push-Repo "$root\finanzapp-mcp" "https://github.com/$GithubUser/finanzapp-mcp.git"
Push-Repo "$root\finanzapp-web" "https://github.com/$GithubUser/finanzapp-web.git"

# 2. Registrar los submodules en el repo raiz
Write-Host "`n>> Configurando submodules en el repo raiz..."
Push-Location $root

git submodule add "https://github.com/$GithubUser/finanzapp-api.git" finanzapp
git submodule add "https://github.com/$GithubUser/finanzapp-mcp.git" finanzapp-mcp
git submodule add "https://github.com/$GithubUser/finanzapp-web.git" finanzapp-web

git add .gitmodules finanzapp finanzapp-mcp finanzapp-web
git commit -m "chore: add submodules for api, mcp, and web

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"

git remote add origin "https://github.com/$GithubUser/finanzapp.git"
git push -u origin main

Pop-Location

Write-Host "`nListo. Repositorios publicados:"
Write-Host "  Root    -> https://github.com/$GithubUser/finanzapp"
Write-Host "  Backend -> https://github.com/$GithubUser/finanzapp-api"
Write-Host "  MCP     -> https://github.com/$GithubUser/finanzapp-mcp"
Write-Host "  Web     -> https://github.com/$GithubUser/finanzapp-web"
Write-Host "`nPara clonar en otro equipo:"
Write-Host "  git clone --recurse-submodules https://github.com/$GithubUser/finanzapp.git"
