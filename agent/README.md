# Executador Agent — Windows

Agente local do projeto **Executador**.

## Como usar

### Primeira vez
1. Abra o painel Executador no celular.
2. Toque em **Conectar PC**.
3. Baixe **Parear-Executador.cmd** no PC.
4. Execute o arquivo.
5. Digite o código mostrado no celular.
6. Aceite a janela do Windows pedindo permissão de Administrador.

### Depois do pareamento
Execute **Start-Executador.cmd**.

Enquanto a janela do Executador estiver aberta, o celular pode:
- iniciar diagnósticos;
- acompanhar resultados;
- enviar reparos permitidos;
- consultar programas, drivers e estado do PC.

Fechar a janela encerra a sessão remota.

## Segurança

- Não é instalado serviço oculto.
- Não é criada persistência automática no Windows.
- A execução administrativa depende de UAC visível.
- O servidor não envia PowerShell/CMD arbitrário.
- O agente aceita somente handlers pré-programados.
- O token local é protegido com DPAPI.
- O agente não envia documentos, fotos, senhas nem conteúdo de arquivos pessoais.
- Identificadores de hardware são enviados como SHA-256.

## Dados coletados

Windows/build, CPU, RAM, GPU, armazenamento, aplicativos instalados, drivers, inicialização, bateria, rede e falhas recentes do Event Viewer.

## Logs

C:\ProgramData\Executador\logs\agent.log
