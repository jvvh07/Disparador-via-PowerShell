# Disparador via PowerShell

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=flat-square&logo=powershell&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-Windows-0078D6?style=flat-square&logo=windows&logoColor=white)
![Channels](https://img.shields.io/badge/Canais-Chrome%20%7C%20Brave%20%7C%20WhatsApp%20Desktop-25D366?style=flat-square)

Automação de fila B2B em PowerShell para Windows com rotação Round-Robin entre **Google Chrome**, **Brave Browser** e **WhatsApp Desktop**. Lê contatos de um arquivo `.txt`, normaliza números automaticamente, controla o progresso em tempo real e salva o estado em JSON para evitar reprocessamento.

---

## Principais Recursos

* **Rotação entre 3 canais (Round-Robin):** Alterna sequencialmente entre Chrome (`0`), Brave (`1`) e WhatsApp Desktop (`2`), distribuindo o volume entre três sessões diferentes.
* **Foco automático de janela:** Utiliza chamadas nativas da API Win32 (`SetForegroundWindow` e `AttachThreadInput`) para trazer o aplicativo da vez para primeiro plano antes de disparar o envio.
* **Normalização de números:** Limpa caracteres especiais e adiciona o DDI `55` automaticamente para números brasileiros de 10 ou 11 dígitos.
* **Controles em tempo real:** Permite pausar (`P`), retomar (`R`) ou interromper (`Q`) a fila a qualquer momento pelo teclado.
* **Recuperação de progresso:** Grava cada envio e falha em `progresso_rotativo.json`, retomando exatamente do ponto onde parou.

---

## Estrutura do Projeto

```text
├── Disparador-Rotativo-3Canais.ps1   # Script principal de automação e rotação
├── contatos_b2b.txt                  # Lista de contatos (um número por linha)
├── progresso_rotativo.json           # Arquivo gerado automaticamente com o estado da fila
└── README.md                         # Documentação do repositório
```

---

## Como Usar

1. **Prepare a lista de contatos**
   Adicione um número por linha no arquivo `contatos_b2b.txt`:
   ```text
   5547999990001
   5547999990002
   5547999990003
   ```

2. **Deixe os 3 canais abertos e logados**
   * **Google Chrome:** Aberto na aba do WhatsApp Web (Chip 1)
   * **Brave Browser:** Aberto na aba do WhatsApp Web (Chip 2)
   * **WhatsApp Desktop:** Aplicativo nativo aberto e autenticado (Chip 3)

3. **Libere a execução de scripts no PowerShell (apenas na primeira vez)**
   ```powershell
   Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
   ```

4. **Inicie o disparador**
   ```powershell
   .\Disparador-Rotativo-3Canais.ps1
   ```
   Pressione `ENTER` no terminal quando os 3 canais estiverem prontos.

---

## Parâmetros Configuráveis

| Parâmetro | Padrão | Descrição |
| :--- | :--- | :--- |
| `-CaminhoContatos` | `.\contatos_b2b.txt` | Caminho do arquivo `.txt` com a lista de telefones. |
| `-ArquivoEstado` | `.\progresso_rotativo.json` | Arquivo JSON usado para salvar e recuperar o histórico. |
| `-IntervaloSegundos` | `25` | Tempo de espera (em segundos) entre cada envio. |
| `-TempoCarregamentoSegundos` | `8` | Tempo de espera para carregar a conversa antes do disparo. |
| `-MensagemFixa` | `"Bom dia, tudo bem?"` | Mensagem enviada automaticamente para cada contato. |
| `-PularDoisPrimeiros` | `$false` | Ignora os 2 primeiros números da lista original. |

### Exemplos de execução

```powershell
# Alterar intervalo para 45 segundos
.\Disparador-Rotativo-3Canais.ps1 -IntervaloSegundos 45

# Personalizar a mensagem de abordagem
.\Disparador-Rotativo-3Canais.ps1 -MensagemFixa "Olá, tudo bem? Podemos conversar rapidamente?"

# Reiniciar a fila do zero
Remove-Item .\progresso_rotativo.json -ErrorAction SilentlyContinue; .\Disparador-Rotativo-3Canais.ps1
```

---

> **Aviso:** A automação de interface depende do foco das janelas no Windows e do tempo de resposta da rede. Utilize com responsabilidade e respeitando as políticas de uso do WhatsApp.
