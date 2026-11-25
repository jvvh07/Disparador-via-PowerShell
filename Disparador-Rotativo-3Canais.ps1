<#
.SYNOPSIS
    Disparador B2B Rotativo (Round-Robin) entre 3 sessoes:
    1. Google Chrome (WhatsApp Web)
    2. Brave Browser (WhatsApp Web)
    3. WhatsApp Desktop (App nativo Windows)
#>

[CmdletBinding()]
param (
    [string]$CaminhoContatos = ".\contatos_b2b.txt",
    [string]$ArquivoEstado = ".\progresso_rotativo.json",
    [int]$IntervaloSegundos = 25,
    [int]$TempoCarregamentoSegundos = 8,
    [string]$MensagemFixa = "Bom dia, tudo bem?",
    [switch]$PularDoisPrimeiros
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System;
using System.Runtime.InteropServices;

public class Win32Rotativo {
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    [DllImport("kernel32.dll")]
    public static extern uint GetCurrentThreadId();

    [DllImport("user32.dll")]
    public static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    public static bool ForceFocus(IntPtr targetHwnd) {
        if (targetHwnd == IntPtr.Zero) return false;
        IntPtr fgHwnd = GetForegroundWindow();
        uint dummy;
        uint fgThread = GetWindowThreadProcessId(fgHwnd, out dummy);
        uint curThread = GetCurrentThreadId();

        ShowWindow(targetHwnd, 9);
        if (fgThread != curThread) {
            AttachThreadInput(curThread, fgThread, true);
            SetForegroundWindow(targetHwnd);
            AttachThreadInput(curThread, fgThread, false);
        } else {
            SetForegroundWindow(targetHwnd);
        }
        return GetForegroundWindow() == targetHwnd;
    }
}
"@

function Focar-Aplicativo {
    param (
        [string]$ProcessName,
        [string]$FiltroTitulo = ""
    )

    $wshell = New-Object -ComObject WScript.Shell
    $janelas = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowHandle -ne 0 }

    if (-not $janelas) { return $false }

    $alvo = $null
    if (-not [string]::IsNullOrWhiteSpace($FiltroTitulo)) {
        $alvo = $janelas | Where-Object { $_.MainWindowTitle -like "*$FiltroTitulo*" } | Select-Object -First 1
    }
    if (-not $alvo) {
        $alvo = $janelas | Select-Object -First 1
    }

    for ($t = 1; $t -le 5; $t++) {
        [void][Win32Rotativo]::ForceFocus($alvo.MainWindowHandle)
        [void]$wshell.AppActivate($alvo.Id)
        Start-Sleep -Milliseconds 300

        $fg = [Win32Rotativo]::GetForegroundWindow()
        $fgPid = 0
        [void][Win32Rotativo]::GetWindowThreadProcessId($fg, [ref]$fgPid)
        $procFg = Get-Process -Id $fgPid -ErrorAction SilentlyContinue

        if ($procFg -and $procFg.ProcessName -eq $ProcessName) {
            return $true
        }
    }

    return $false
}

function Enviar-ViaNavegador {
    param (
        [string]$NomeCanal,
        [string]$ProcessName,
        [string]$Telefone,
        [string]$Mensagem,
        [int]$EsperaCarregamento
    )

    if (-not (Focar-Aplicativo -ProcessName $ProcessName -FiltroTitulo "WhatsApp")) {
        return @{
            Sucesso = $false
            Detalhe = "[$NomeCanal] Nao foi possivel focar a janela (verifique se esta aberto)."
        }
    }

    try {
        $textoCodificado = [Uri]::EscapeDataString($Mensagem)
        $urlDestino = "https://web.whatsapp.com/send?phone=$Telefone&text=$textoCodificado"

        [System.Windows.Forms.Clipboard]::SetText($urlDestino)
        Start-Sleep -Milliseconds 200

        [System.Windows.Forms.SendKeys]::SendWait("^l")
        Start-Sleep -Milliseconds 250
        [System.Windows.Forms.SendKeys]::SendWait("{BACKSPACE}")
        Start-Sleep -Milliseconds 150
        [System.Windows.Forms.SendKeys]::SendWait("^v")
        Start-Sleep -Milliseconds 300
        [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")

        Start-Sleep -Seconds $EsperaCarregamento

        if (-not (Focar-Aplicativo -ProcessName $ProcessName -FiltroTitulo "WhatsApp")) {
            return @{
                Sucesso = $false
                Detalhe = "[$NomeCanal] Perdeu foco antes de disparar ENTER."
            }
        }

        Start-Sleep -Milliseconds 400
        [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
        Start-Sleep -Milliseconds 500

        return @{
            Sucesso = $true
            Detalhe = "[$NomeCanal] Mensagem disparada para $Telefone."
        }
    }
    catch {
        return @{
            Sucesso = $false
            Detalhe = "[$NomeCanal] Erro: $($_.Exception.Message)"
        }
    }
}

function Enviar-ViaWhatsAppDesktop {
    param (
        [string]$Telefone,
        [string]$Mensagem,
        [int]$EsperaCarregamento
    )

    $procApp = Get-Process -ErrorAction SilentlyContinue |
        Where-Object { $_.ProcessName -in @("WhatsApp", "WhatsApp.Root") } |
        Select-Object -First 1

    if (-not $procApp) {
        return @{
            Sucesso = $false
            Detalhe = "[WhatsApp App] Aplicativo WhatsApp Desktop nao esta aberto."
        }
    }

    try {
        $textoCodificado = [Uri]::EscapeDataString($Mensagem)
        $uriProtocolo = "whatsapp://send?phone=$Telefone&text=$textoCodificado"

        Start-Process $uriProtocolo
        Start-Sleep -Seconds $EsperaCarregamento

        if (-not (Focar-Aplicativo -ProcessName $procApp.ProcessName)) {
            return @{
                Sucesso = $false
                Detalhe = "[WhatsApp App] Nao foi possivel focar a janela do aplicativo."
            }
        }

        Start-Sleep -Milliseconds 400
        [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
        Start-Sleep -Milliseconds 500

        return @{
            Sucesso = $true
            Detalhe = "[WhatsApp App] Mensagem disparada para $Telefone."
        }
    }
    catch {
        return @{
            Sucesso = $false
            Detalhe = "[WhatsApp App] Erro: $($_.Exception.Message)"
        }
    }
}

function Normalizar-Telefone {
    param ([string]$NumeroBruto)
    if ([string]::IsNullOrWhiteSpace($NumeroBruto)) { return $null }
    $digitos = ($NumeroBruto -replace '\D', '')
    if ($digitos.Length -in @(10, 11)) { $digitos = "55$digitos" }
    if ($digitos.Length -lt 10 -or $digitos.Length -gt 15) { return $null }
    return $digitos
}

function Salvar-Estado {
    param ([string]$Caminho, [hashtable]$Estado)
    $Estado.AtualizadoEm = (Get-Date).ToString("o")
    $Estado | ConvertTo-Json -Depth 6 | Set-Content -Path $Caminho -Encoding UTF8
}

function Ler-TeclasControle {
    param ([ref]$Pausado, [ref]$Interromper)
    while ([Console]::KeyAvailable) {
        $key = [Console]::ReadKey($true)
        switch ($key.Key) {
            'P' { $Pausado.Value = $true; Write-Host "`n[PAUSADO] Pressione [R] para retomar ou [Q] para sair." -ForegroundColor Yellow }
            'R' { if ($Pausado.Value) { $Pausado.Value = $false; Write-Host "`n[RETOMADO] Retomando fila..." -ForegroundColor Green } }
            'Q' { $Interromper.Value = $true; Write-Host "`n[INTERROMPENDO] Salvando estado..." -ForegroundColor Red }
        }
    }
}

function Aguardar-Intervalo {
    param ([int]$Segundos, [ref]$Pausado, [ref]$Interromper, [hashtable]$Estado, [string]$CaminhoEstado)
    $restante = $Segundos
    while ($restante -gt 0 -or $Pausado.Value) {
        Ler-TeclasControle -Pausado $Pausado -Interromper $Interromper
        if ($Interromper.Value) { Salvar-Estado -Caminho $CaminhoEstado -Estado $Estado; return }
        if ($Pausado.Value) { Start-Sleep -Milliseconds 250; continue }
        Write-Host -NoNewline "`r[AGUARDANDO] Proximo envio em $($restante.ToString('00'))s  |  [P] Pausar  [R] Retomar  [Q] Parar   "
        Start-Sleep -Seconds 1
        $restante--
    }
    Write-Host ""
}

function Mostrar-Progresso {
    param ([string]$Atual, [string]$CanalAtual, [hashtable]$Estado)
    Write-Host "============================================================" -ForegroundColor DarkGray
    Write-Host "Contato atual       : $Atual" -ForegroundColor White
    Write-Host "Canal da vez        : $CanalAtual" -ForegroundColor Magenta
    Write-Host "Total de contatos   : $($Estado.TotalContatos)" -ForegroundColor White
    Write-Host "Contatos processados: $($Estado.Processados)" -ForegroundColor Cyan
    Write-Host "Envios realizados   : $($Estado.Enviados)" -ForegroundColor Green
    Write-Host "Falhas              : $($Estado.Falhas)" -ForegroundColor Red
    Write-Host "============================================================" -ForegroundColor DarkGray
}

$canais = @(
    @{ Nome = "Google Chrome";    Tipo = "Browser"; Processo = "chrome" },
    @{ Nome = "Brave Browser";    Tipo = "Browser"; Processo = "brave"  },
    @{ Nome = "WhatsApp Desktop"; Tipo = "App";     Processo = "WhatsApp" }
)

if (-not (Test-Path $CaminhoContatos)) {
    throw "Arquivo de contatos nao encontrado: $CaminhoContatos"
}

$listaOriginal = Get-Content -Path $CaminhoContatos |
    ForEach-Object { $_.Trim() } |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

$contatosFila = if ($PularDoisPrimeiros) { @($listaOriginal | Select-Object -Skip 2) } else { @($listaOriginal) }

if (Test-Path $ArquivoEstado) {
    $salvo = Get-Content -Path $ArquivoEstado -Raw | ConvertFrom-Json
    $setConcluidos = New-Object System.Collections.Generic.HashSet[string]
    foreach ($item in @($salvo.ChavesConcluidas)) { [void]$setConcluidos.Add([string]$item) }
    $estado = @{
        TotalContatos    = $contatosFila.Count
        Processados      = [int]$salvo.Processados
        Enviados         = [int]$salvo.Enviados
        Falhas           = [int]$salvo.Falhas
        IndiceCanal      = [int]$salvo.IndiceCanal
        ChavesConcluidas = @($setConcluidos)
        Registros        = @($salvo.Registros)
        AtualizadoEm     = [string]$salvo.AtualizadoEm
    }
}
else {
    $setConcluidos = New-Object System.Collections.Generic.HashSet[string]
    $estado = @{
        TotalContatos    = $contatosFila.Count
        Processados      = 0
        Enviados         = 0
        Falhas           = 0
        IndiceCanal      = 0
        ChavesConcluidas = @()
        Registros        = @()
        AtualizadoEm     = (Get-Date).ToString("o")
    }
    Salvar-Estado -Caminho $ArquivoEstado -Estado $estado
}

Write-Host "=== PREPARACAO DOS 3 CANAIS ===" -ForegroundColor Cyan
Write-Host "1. Deixe o Google Chrome aberto na aba do WhatsApp Web (Numero 1)"
Write-Host "2. Deixe o Brave aberto na aba do WhatsApp Web (Numero 2)"
Write-Host "3. Deixe o aplicativo WhatsApp Desktop aberto e logado (Numero 3)"
Write-Host "Pressione ENTER quando os 3 estiverem abertos e logados..." -ForegroundColor Yellow
[void][Console]::ReadLine()

$pausado = $false
$interromper = $false

for ($i = 0; $i -lt $contatosFila.Count; $i++) {
    Ler-TeclasControle -Pausado ([ref]$pausado) -Interromper ([ref]$interromper)
    while ($pausado -and -not $interromper) {
        Start-Sleep -Milliseconds 250
        Ler-TeclasControle -Pausado ([ref]$pausado) -Interromper ([ref]$interromper)
    }
    if ($interromper) { break }

    $contatoBruto = $contatosFila[$i]
    $chave = "$i|$contatoBruto"
    if ($setConcluidos.Contains($chave)) { continue }

    $canal = $canais[$estado.IndiceCanal % $canais.Count]

    Mostrar-Progresso -Atual "$contatoBruto ($($i + 1)/$($contatosFila.Count))" -CanalAtual $canal.Nome -Estado $estado

    $numeroValido = Normalizar-Telefone -NumeroBruto $contatoBruto
    if (-not $numeroValido) {
        $resultado = @{ Sucesso = $false; Detalhe = "Numero invalido: '$contatoBruto'" }
    }
    else {
        if ($canal.Tipo -eq "Browser") {
            $resultado = Enviar-ViaNavegador `
                -NomeCanal $canal.Nome `
                -ProcessName $canal.Processo `
                -Telefone $numeroValido `
                -Mensagem $MensagemFixa `
                -EsperaCarregamento $TempoCarregamentoSegundos
        }
        else {
            $resultado = Enviar-ViaWhatsAppDesktop `
                -Telefone $numeroValido `
                -Mensagem $MensagemFixa `
                -EsperaCarregamento $TempoCarregamentoSegundos
        }
    }

    $estado.Processados++
    if ($resultado.Sucesso) {
        $estado.Enviados++
        Write-Host "[SUCESSO] $($resultado.Detalhe)" -ForegroundColor Green
    }
    else {
        $estado.Falhas++
        Write-Warning "[FALHA] $($resultado.Detalhe)"
    }

    $estado.IndiceCanal = ($estado.IndiceCanal + 1) % $canais.Count

    [void]$setConcluidos.Add($chave)
    $estado.ChavesConcluidas = @($setConcluidos)
    $estado.Registros += @{
        Indice       = $i + 1
        Canal        = $canal.Nome
        ContatoBruto = $contatoBruto
        Telefone     = $numeroValido
        Sucesso      = $resultado.Sucesso
        Detalhe      = $resultado.Detalhe
        DataHora     = (Get-Date).ToString("o")
    }

    Salvar-Estado -Caminho $ArquivoEstado -Estado $estado

    if ((($i + 1) -lt $contatosFila.Count) -and -not $interromper) {
        Aguardar-Intervalo -Segundos $IntervaloSegundos -Pausado ([ref]$pausado) -Interromper ([ref]$interromper) -Estado $estado -CaminhoEstado $ArquivoEstado
    }
}

Salvar-Estado -Caminho $ArquivoEstado -Estado $estado
Write-Host "`n=== EXECUCAO FINALIZADA ===" -ForegroundColor Cyan
Mostrar-Progresso -Atual "Encerrado" -CanalAtual "-" -Estado $estado
