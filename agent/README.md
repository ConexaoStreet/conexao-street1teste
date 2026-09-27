# Executador Agent — Windows

## Conexão rápida

O pareamento agora começa **no PC**:

1. No computador, execute `Parear-Executador.cmd`.
2. O arquivo solicita **Administrador (UAC)** automaticamente.
3. O Agent baixa/atualiza e mostra um código de 8 caracteres.
4. No celular, abra o Executador e toque em **Conectar PC**.
5. Cole o código e toque em **Vincular este PC**.
6. O PC reconhece a vinculação e inicia a sessão.

O código expira em 15 minutos e só pode ser usado uma vez.

## Depois do primeiro vínculo

Execute `Start-Executador.cmd`.

Esse arquivo também solicita **Administrador automaticamente** e mantém o Agent ativo enquanto a janela estiver aberta.

## Segurança

- não existe endpoint para CMD/PowerShell arbitrário;
- somente handlers de diagnóstico/reparo existentes no Agent podem executar;
- código de pareamento é armazenado no backend apenas como SHA-256;
- a credencial do Agent é gerada no próprio PC;
- o backend guarda somente o hash da credencial;
- o token local é protegido com DPAPI;
- o código de conexão é de uso único e tem expiração;
- nenhum documento, foto, senha ou conteúdo de arquivo pessoal é enviado;
- identificadores de hardware são enviados somente em hash;
- a elevação administrativa sempre passa pelo UAC visível do Windows.

## Arquivos

- `Parear-Executador.cmd`: gera o código no PC e aguarda o celular.
- `Start-Executador.cmd`: inicia uma máquina já vinculada.
- `ExecutadorAgent.ps1`: diagnóstico, inventário e handlers de reparo.

## Logs

`C:\ProgramData\Executador\logs\agent.log`
