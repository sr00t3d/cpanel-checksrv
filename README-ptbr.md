# Check Server

Leia-me: [BR](README-ptbr.md)

![License](https://img.shields.io/github/license/sr00t3d/cpanel-checksrv) ![Shell Script](https://img.shields.io/badge/language-Bash-green.svg)

<img width="700" src="cp-checksrv-cover.webp" />

> **Reescrita em Bash do utilitário original checksrv em Perl por Matthew Harris (HostGator) - Convertido usando Kimi**

Um script Bash rápido e eficiente para analisar logs do `chkservd` do cPanel/WHM, projetado para lidar com arquivos de log grandes (100MB+) sem problemas de desempenho.

## Sobre

Este projeto é uma **reescrita em Bash** do script original em Perl `checksrv`, criado por **Matthew Harris** na HostGator em 2013. O script original foi desenvolvido para tornar o `/var/log/chkservd.log` legível por humanos, analisando os resultados de verificação de serviços do daemon de monitoramento do cPanel.

### Por que uma Reescrita em Bash?

- **Desempenho**: O script original em Perl tinha dificuldades com arquivos de log grandes (100MB+)
- **Portabilidade**: Não requer dependências do Perl
- **Velocidade**: Otimizado para sistemas modernos usando ferramentas Unix nativas (`grep`, `awk`, `sed`)
- **Cores**: Saída aprimorada no terminal com codificação por cores

## Referência Original

```perl
#!/usr/bin/perl
# $Date: 2013-02-15 $
# $Revision: 1.0 $
# $Source: /root/bin/checksrv $
# $Author: Matthew Harris $
# Make /var/log/chkservd.log pretty
# https://gatorwiki.hostgator.com/Admin/RootBin#checkserv 
# http://git.toolbox.hostgator.com/checkserv 
# Please submit all bug reports at projects.hostgator.com
# https://projects.hostbox.hostgator.com/projects/script-checkserv/issues/new
```

**Autor Original**: Matthew Harris (HostGator)  
**Data Original**: 2013-02-15  
**Propósito Original**: Analisar `/var/log/chkservd.log` para monitoramento de serviços

## Recursos

| Recurso               | Descrição                                   | Original | Esta Versão |
| --------------------- | -------------------------------------------- | -------- | ------------ |
| Analisar logs chkservd | Ler logs do monitor de serviços do cPanel  | ✅       | ✅           |
| Mostrar serviços com falha | Exibir apenas serviços com erro        | ✅       | ✅           |
| Mostrar todos os serviços | Exibir serviços funcionais também      | ❌       | ✅ (`-f`)    |
| Saída colorida        | Cores no terminal para melhor leitura       | ❌       | ✅           |
| Suporte a arquivos grandes | Lidar com logs de 100MB+ com eficiência | ❌       | ✅           |
| Informações do sistema | Mostrar PID do chkservd, uptime, tamanho do log | ❌ | ✅           |
| Execução rápida       | Otimizado com `grep`/`tail` vs leitura completa | ❌ | ✅           |
| Limite de quantidade  | Número ajustável de verificações a exibir   | ✅       | ✅ (`-q`)    |

## Requisitos

- **Bash** 4.0+
- **cPanel/WHM** (para `/var/log/chkservd.log`)
- Ferramentas Unix padrão: `grep`, `sed`, `awk`, `stat`, `ps`, `tac` (opcional)

## Instalação

```bash
# Clonar ou baixar
curl -O https://raw.githubusercontent.com/sr00t3d/cpanel-checksrv/refs/heads/main/checksrv.sh

# Tornar executável
chmod +x checksrv.sh

# Opcional: mover para o PATH
sudo mv checksrv.sh /usr/local/bin/checksrv
```

## Uso

```bash
./checksrv.sh [OPÇÕES]
```

### Opções

| Opção  | Forma Longa      | Descrição                                           |
| ------- | ---------------- | --------------------------------------------------- |
| `-a`   | `--all`          | Exibir todas as verificações de serviço (máx. 5000 linhas) |
| `-f`   | `--functional`   | Mostrar também serviços funcionais (com detalhes) |
| `-q N` | `--quantity N`   | Mostrar as últimas N verificações (padrão: 5)     |
| `-h`   | `--help`         | Mostrar mensagem de ajuda                          |

## Exemplos

### 1. Verificar Falhas (Padrão)

Mostrar apenas serviços com falha nas últimas 5 verificações:

```bash
./checksrv.sh
```

**Saída quando saudável:**

```bash
--------------------------------------
        Chksrvd Log Parser v2.0 (Bash)
--------------------------------------

Analisando últimas 5 verificações...
Nenhuma falha encontrada nas últimas verificações.
```

**Saída com falhas:**

```bash
[2026-03-03 09:45:12 -0300]
        [!] httpd failed
        [!] mysql failed
```

### 2. Status Detalhado dos Serviços

Mostrar todos os serviços (funcionais + com falha) com detalhes:

```bash
./checksrv.sh -f -q 2
```

**Saída:**

```bash
--------------------------------------
        Chksrvd Log Parser v2.0 (Bash)
--------------------------------------

=== Informações do Sistema ===
chkservd: RUNNING (PID: 1234, Uptime: 15-03:45:12)
Log: 99 MB | Checks: 53571
Falhas nas últimas 2000 linhas: 0

Analisando últimos 2 checks completos...

═══════════════════════════════════════════════════════════════
[2026-03-03 09:45:12 -0300] Service Check (24 serviços)
───────────────────────────────────────────────────────────────
        [✓] queueprocd [check:+] [socket:N/A] OK
        [✓] sshd [check:+] [socket:N/A] OK
        [✓] spamd [check:+] [socket:N/A] OK
        [✓] rsyslogd [check:+] [socket:N/A] OK
        [✓] pop [check:+] [socket:+] OK
        [✓] p0f [check:+] [socket:N/A] OK
        [✓] nscd [check:+] [socket:N/A] OK
        [✓] named [check:+] [socket:N/A] OK
        [✓] mysql [check:+] [socket:N/A] OK
        [✓] mailman [check:+] [socket:N/A] OK
        [✓] lmtp [check:+] [socket:+] OK
        [✓] lfd [check:+] [socket:N/A] OK
        [✓] ipaliases [check:+] [socket:N/A] OK
        [✓] imap [check:+] [socket:+] OK
        [✓] httpd [check:N/A] [socket:+] OK
        [✓] exim [check:+] [socket:+] OK
        [✓] dnsadmin [check:+] [socket:+] OK
        [✓] crond [check:+] [socket:N/A] OK
        [✓] cpsrvd [check:N/A] [socket:+] OK
        [✓] cphulkd [check:+] [socket:+] OK
        [✓] cpdavd [check:+] [socket:N/A] OK
        [✓] cpanellogd [check:+] [socket:N/A] OK
        [✓] cpanel_php_fpm [check:+] [socket:N/A] OK
        [✓] apache_php_fpm [check:+] [socket:N/A] OK
───────────────────────────────────────────────────────────────
        Resumo: Todos os 24 serviços OK

═══════════════════════════════════════════════════════════════
[2026-03-03 09:36:36 -0300] Service Check (24 serviços)
───────────────────────────────────────────────────────────────
        ...
        Resumo: Todos os 24 serviços OK
```

### 3. Ver Todas as Verificações Recentes

Mostrar todas as verificações das últimas 5000 linhas do log:

```bash
./checksrv.sh -f -a
```

### 4. Quantidade Personalizada

Mostrar as últimas 10 verificações com detalhes completos:

```bash
./checksrv.sh -f -q 10
```

### 5. Verificação Mínima (para Cron)

Verificação silenciosa - só exibe saída se houver falhas:

```bash
./checksrv.sh -q 1
```

**Perfeito para monitoramento via cron:**

```bash
# Adicionar ao crontab
*/5 * * * * /usr/local/bin/checksrv -q 1 || echo "Falha de serviço detectada em $(hostname)" | mail -s "Alerta" admin@example.com
```

## Formatos de Saída

### Codificação por Cores

| Cor       | Significado            |
| ---------- | ---------------------- |
| 🟢 Verde  | Serviço OK             |
| 🔴 Vermelho | Serviço com Falha    |
| 🟡 Amarelo | Timestamps e cabeçalhos |
| 🔵 Azul   | Mensagens de processamento |
| Ciano     | Separadores de seção   |

### Indicadores de Status

| Símbolo | Status        | Descrição                                |
| -------- | ------------- | ----------------------------------------- |
| `[✓]`   | OK            | Serviço passou na verificação           |
| `[!]`   | FAILED        | Serviço falhou na verificação           |
| `+`     | Sucesso       | Teste de comando/socket aprovado        |
| `-`     | Falha         | Teste de comando/socket falhou          |
| `N/A`   | Não Aplicável | Verificação não disponível para o serviço |

## Desempenho

Otimizado para arquivos de log grandes:

| Métrica         | Perl Original | Esta Versão     |
| ---------------- | ------------- | ---------------- |
| Arquivo de 100MB | ~30-60s      | ~1-3s           |
| Uso de memória   | Alto (leitura completa) | Baixo (streaming) |
| 1000 verificações | Lento        | Instantâneo     |
| 50000+ verificações | Muito lento | < 5s            |

**Técnicas utilizadas:**

- `grep` + `tail` em vez de leitura completa do arquivo
- `awk` para análise eficiente
- Processamento em streaming (sem carregar o arquivo inteiro na memória)
- `tac` para leitura reversa (quando necessário)

## Solução de Problemas

### Nenhuma saída

```bash
# Verificar se o log existe
ls -la /var/log/chkservd.log

# Verificar se o chkservd está em execução
systemctl status chkservd
# ou
service chkservd status
```

### Permissão negada

```bash
# Executar como root ou com sudo
sudo ./checksrv.sh
```

### Script travando

O arquivo de log pode estar extremamente grande. O modo `-a` é limitado a 5000 linhas. Use `-q` para quantidades específicas.

### Sem cores na saída

As cores são ativadas por padrão. Se seu terminal não suportar cores, elas não aparecerão (mas a saída continuará funcionando).

## Serviços Monitorados

Serviços típicos do cPanel/WHM verificados:

| Categoria         | Serviços                                           |
| ----------------- | -------------------------------------------------- |
| **Servidor Web**  | httpd, apache_php_fpm, cpanel_php_fpm             |
| **Email**         | exim, imap, pop, lmtp, mailman, spamd             |
| **Banco de Dados**| mysql                                             |
| **DNS**           | named, dnsadmin                                   |
| **Segurança**     | cphulkd, lfd, p0f                                 |
| **Sistema**       | sshd, crond, rsyslogd, nscd                       |
| **cPanel**        | cpsrvd, cpdavd, cpanellogd, ipaliases, queueprocd |


## Créditos

- **Autor Original**: Matthew Harris (HostGator)
- **Data Original**: 2013-02-15
- **Reescrita em Bash**: 2026
- **Propósito**: Ferramenta de administração de sistemas para servidores cPanel/WHM

## Links

- Wiki original da HostGator: `https://gatorwiki.hostgator.com/Admin/RootBin#checkserv`
- Repositório original: `http://git.toolbox.hostgator.com/checkserv`

## Aviso Legal

> [!WARNING]
> Este software é fornecido "como está". Sempre garanta que você tem permissão explícita antes de executá-lo. O autor não é responsável por qualquer uso indevido, consequências legais ou impacto em dados causados por esta ferramenta.

## Tutorial Detalhado

Para um guia completo passo a passo, confira meu artigo completo:

👉 [**Verifique falhas de serviço no cPanel**](https://perciocastelo.com.br/blog/check-services-failures-on-cpanel.html)

## Licença

Este projeto está licenciado sob a **GNU General Public License v3.0**. Veja o arquivo [LICENSE](LICENSE) para mais detalhes.

---

**Nota**: Esta é uma reescrita não oficial e não suportada/patrocinada pela HostGator.