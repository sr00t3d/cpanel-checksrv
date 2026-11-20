# cPanel CheckSrv (`cp-checksrv.sh`)

![Capa do cPanel CheckSrv](./cp-checksrv-cover.webp)

[![Versão](https://img.shields.io/badge/version-2.0.0-blue.svg)](./cp-checksrv.sh)
[![Licença](https://img.shields.io/badge/license-Apache--2.0-green.svg)](./LICENSE)
[![Plataforma](https://img.shields.io/badge/platform-Linux%20%7C%20cPanel%20%2F%20WHM%20%7C%20chkservd-orange.svg)](#requisitos)

> 🇺🇸 **[Read in English (README.md)](./README.md)**

O **cPanel CheckSrv** (`cp-checksrv.sh` v2.0.0) é um parser CLI de alta velocidade em Bash + Python3 (somente biblioteca padrão) para o `/var/log/chkservd.log` em servidores cPanel/WHM. Projetado para ambientes de produção onde o log ultrapassa facilmente 100 MB, ele utiliza **leitura reversa em blocos** (256 KB a partir do fim do arquivo) para auditar os ciclos mais recentes em milissegundos sem carregar o arquivo inteiro na memória.

---

## Funcionalidades

- **Leitura Reversa em Blocos (Reverse-Seek):** Lê o `/var/log/chkservd.log` de trás para frente em blocos de 256 KB, garantindo resposta em milissegundos mesmo em logs acima de 100 MB.
- **Resumo de Uptime por Serviço (`-S, --summary`):** Consolida `CHECKS`, `OK`, `FAILED`, `UPTIME%` e o último status de `check command` / `socket connect` por daemon monitorado.
- **Modos Falhas e Completo:** Exibe apenas falhas por padrão, ou todos os serviços monitorados (`httpd`, `mysql`, `exim`, `named`, `imap`, `cpsrvd`, `lfd`, `sshd`, etc.) com `-f, --functional`.
- **Filtro por Serviço e Log Customizado:** Isole um único serviço com `-s <nome>` ou audite logs rotacionados/arquivados com `-l <caminho>`.
- **Saídas Estruturadas:** Exporta relatórios em `table` (padrão), `json` ou `csv` para `cron`, Zabbix e automações de plantão.
- **Exit Codes Semânticos:** Retorna `0` quando todos os checks estão saudáveis, `1` em erro de uso/arquivo e `2` quando há falhas no período analisado (pronto para `cp-checksrv.sh -q 1 || mail ...`).

---

## Requisitos

- Linux com Bash 4.0+ e Python 3.6+ (somente biblioteca padrão, zero dependências externas)
- Permissão de leitura em `/var/log/chkservd.log` (geralmente `root` ou `sudo`)

---

## Instalação

```bash
git clone https://github.com/sr00t3d/cpanel-checksrv.git
cd cpanel-checksrv
chmod +x cp-checksrv.sh
```

---

## Como usar

```bash
# Padrão: exibe falhas nos últimos 5 ciclos do chkservd
sudo ./cp-checksrv.sh

# Resumo de uptime por serviço nos últimos 20 ciclos
sudo ./cp-checksrv.sh -S -q 20

# Status completo (OK + FAILED) dos últimos 2 ciclos
sudo ./cp-checksrv.sh -f -q 2

# Filtrar histórico de um serviço específico (ex.: exim)
sudo ./cp-checksrv.sh -s exim -f -q 10

# Exportar resumo por serviço em JSON
sudo ./cp-checksrv.sh -S -q 50 -o json > chkservd-summary.json

# Alerta via cron em qualquer falha no último ciclo
*/5 * * * * /usr/local/bin/cp-checksrv.sh -q 1 --no-color >/dev/null || echo "Falha chkservd em $(hostname)" | mail -s "Alert chkservd" ops@example.com
```

### Opções da CLI

| Opção | Descrição |
| :--- | :--- |
| `-q, --quantity <N>` | Quantidade de ciclos mais recentes a analisar (padrão: `5`) |
| `-f, --functional` | Inclui serviços saudáveis (`OK`), não apenas falhas |
| `-a, --all` | Varre até `--max-lines` linhas recentes (padrão: `5000`) |
| `--max-lines <N>` | Limite de linhas finais no modo `--all` (padrão: `5000`) |
| `-S, --summary` | Exibe tabela consolidada de uptime e falhas por serviço |
| `-s, --service <nome>` | Filtra a saída para um serviço específico |
| `-l, --log <caminho>` | Caminho customizado do `chkservd.log` (padrão: `/var/log/chkservd.log`) |
| `-o, --output <fmt>` | Formato de saída: `table` (padrão), `json`, `csv` |
| `--no-color` | Desativa cores ANSI |
| `-V, --version` | Exibe a versão e encerra |
| `-h, --help` | Exibe a ajuda e encerra |

---

## Exemplo de Saída Real

Capturado em container AlmaLinux 8.10 / cPanel executando `cp-checksrv.sh -S -q 4 --no-color` sobre 4 ciclos de verificação (32 checagens de serviço, com 3 falhas transitórias em `exim` e `mysql`):

```text
================================================================================================================
 CPANEL CHECKSRV v2.0.0 - [cpanel-test.local] | Log: /tmp/chkservd-test.log (0.0 MB) | chkservd: NOT_RUNNING
================================================================================================================
SERVICE                | CHECKS |     OK | FAILED |  UPTIME | LAST     | LAST CHECK / SOCKET
----------------------------------------------------------------------------------------------------------------
cpsrvd                 |      4 |      4 |      0 |  100.0% | OK       | cmd:N/A sock:+
exim                   |      4 |      2 |      2 |   50.0% | OK       | cmd:+ sock:+
httpd                  |      4 |      4 |      0 |  100.0% | OK       | cmd:+ sock:+
imap                   |      4 |      4 |      0 |  100.0% | OK       | cmd:+ sock:+
lfd                    |      4 |      4 |      0 |  100.0% | OK       | cmd:+ sock:N/A
mysql                  |      4 |      3 |      1 |   75.0% | OK       | cmd:+ sock:+
named                  |      4 |      4 |      0 |  100.0% | OK       | cmd:+ sock:+
sshd                   |      4 |      4 |      0 |  100.0% | OK       | cmd:+ sock:+
================================================================================================================
 Summary: 4 cycle(s) | 8 service(s) | Total checks: 32 | Failures: 3
================================================================================================================
```

---

## Licença

Distribuído sob a [Licença Apache-2.0](./LICENSE). Inspirado no utilitário original em Perl `checksrv` de Matthew Harris (HostGator, 2013).
