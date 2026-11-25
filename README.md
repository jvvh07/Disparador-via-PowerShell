

__________________________________________________________________________________________
# Disparador-via-PowerShell
Script em PowerShell para automação de fila B2B com rotação entre Google Chrome, Brave e WhatsApp Desktop. Lê números de um .txt, envia mensagem automática com intervalo configurável, exibe progresso em tempo real, suporta pausa/retomada/interrupção (P, R, Q) e salva o estado em JSON para retomar sem reprocessar.


# Disparador B2B via PowerShell (Disparador-Rotativo-3Canais.ps1)

Script em PowerShell para automação de fila B2B com rotação entre Google Chrome, Brave e WhatsApp Desktop. Lê números de um .txt, envia mensagem automática com intervalo configurável, exibe progresso em tempo real, suporta pausa/retomada/interrupção (P, R, Q) e salva o estado em JSON para retomar sem reprocessar.

## Como funciona na prática

* Leitura e preparação da fila: O script carrega os números de contatos_b2b.txt (um por linha), ignora linhas vazias e permite pular os dois primeiros contatos com -PularDoisPrimeiros se necessário.
* Rotação entre 3 canais (Round-Robin): A cada contato da fila, o script avança o índice do canal (0 -> Google Chrome, 1 -> Brave Browser, 2 -> WhatsApp Desktop), dividindo os envios entre os três números/sessões abertos no computador.
* Foco de janela e envio automático: Utiliza chamadas Win32 (SetForegroundWindow / AttachThreadInput e AppActivate) para trazer a janela do canal da vez para frente, navega até a conversa com a mensagem fixa ("Bom dia, tudo bem?") já preenchida e dispara {ENTER} automaticamente.
* Controle de execução: Durante a contagem regressiva ou entre os itens da fila, aceita comandos no teclado ([P] para pausar, [R] para retomar e [Q] para interromper com segurança).
* Persistência de estado: Após cada contato processado, grava contadores, histórico e chaves concluídas em progresso_rotativo.json, permitindo retomar exatamente de onde parou.

## Passo a passo de uso

1. Prepare os arquivos na mesma pasta
   * Salve o script Disparador-Rotativo-3Canais.ps1.
   * Crie o arquivo contatos_b2b.txt com um telefone por linha (ex.: 5547999999999).

2. Abra e autentique os 3 canais no Windows
   * Canal 1 (Google Chrome): Abra o WhatsApp Web e faça login no primeiro número.
   * Canal 2 (Brave Browser): Abra o WhatsApp Web e faça login no segundo número.
   * Canal 3 (WhatsApp Desktop): Abra o aplicativo nativo do Windows e faça login no terceiro número.

3. Libere a execução de scripts no PowerShell (se necessário)
   ```powershell

__________________________________________________________________________________________

PowerShell
.\Disparador-Rotativo-3Canais.ps1
Quando o terminal pedir, confirme que os 3 canais estão abertos e pressione ENTER.

Acompanhe, pause ou retome a fila

Pressione P para pausar, R para retomar e Q para encerrar salvando o progresso.

Para começar uma nova fila do zero, apague o arquivo progresso_rotativo.json antes de rodar novamente.
   Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned

__________________________________________________________________________________________
## Parâmetros configuráveis

| Parâmetro | Padrão | Função |
| :--- | :--- | :--- |
| -CaminhoContatos | .\contatos_b2b.txt | Caminho do arquivo .txt com a lista de números. |
| -ArquivoEstado | .\progresso_rotativo.json | Arquivo JSON usado para salvar e recuperar o progresso. |
| -IntervaloSegundos | 25 | Tempo de espera (em segundos) entre um disparo e o próximo. |
| -TempoCarregamentoSegundos | 8 | Tempo de espera para a conversa carregar antes de enviar ENTER. |
| -MensagemFixa | "Bom dia, tudo bem?" | Texto enviado automaticamente para cada contato. |
| -PularDoisPrimeiros | $false | Ignora os 2 primeiros números da lista original ao montar a fila. |
__________________________________________________________________________________________
