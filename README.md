# limpeza-disco-mac

Skill de [Claude Code](https://claude.com/claude-code) que audita e libera espaço em disco no macOS **sem destruir o que importa**.

O fluxo é sempre o mesmo: **medir → categorizar → confirmar → executar**. Nenhum `rm` roda sem você ver o comando antes.

## Instalar

```bash
git clone git@github.com:nerigleston/limpeza-disco-mac.git ~/.claude/skills/limpeza-disco-mac
```

Reinicie o Claude Code e confirme com `/skills`.

Para compartilhar com uma equipe, clone em `.claude/skills/` dentro do repositório do projeto.

## Usar

Peça em linguagem natural — a skill dispara sozinha:

- "meu disco está cheio, me ajuda a liberar espaço"
- "o que está ocupando espaço no meu Mac?"
- "limpa os caches de Docker e npm"

Ou invoque direto com `/limpeza-disco-mac`.

### Só auditar, sem o Claude

O script não apaga nada — serve para ver os números antes de decidir:

```bash
bash ~/.claude/skills/limpeza-disco-mac/scripts/auditar.sh
```

## Por que não é só uma lista de comandos

Receita de limpeza é fácil de achar. O que essa skill carrega são as armadilhas que só aparecem quando você roda isso numa máquina real de trabalho:

- **`docker system prune --volumes` é o conselho mais repetido e o mais perigoso.** Volumes marcados como `dangling` costumam ser bancos Postgres, Redis e SQL Server de projetos ativos — o container sumiu, os dados não. Num caso real, 41 volumes "órfãos" eram todos bancos de dev, e o prune renderia só 2,5 GB.
- **`df -h /` mostra o número errado.** No macOS moderno `/` é o volume de sistema selado (~12 GB). O uso real está em `/System/Volumes/Data`.
- **Apps em `/Applications` podem pertencer ao `root`.** Um `rm -rf` sem privilégio apaga só a parte gravável e deixa o app quebrado pela metade — inclusive o desinstalador oficial.
- **`du` mede tamanho lógico, `df` mede o disco.** Com clones APFS, uma pasta de 23 GB pode liberar bem menos. Reporte sempre o ganho medido.
- **Projeto sem git remote não tem backup nenhum.** E 80–95% do tamanho costuma ser `node_modules` ou venv — apagar só o miolo entrega quase todo o ganho e preserva o código.
- **Arquivos com `(1)`, `(2)` no nome quase nunca são cópias.** De 79 candidatos num caso real, só 12 eram idênticos. Confirme com `cmp`, não pelo nome.
- **No Chrome, só `Service Worker` é seguro.** `WebStorage` e `IndexedDB` guardam sessões e dados offline.
- **O WhatsApp costuma ser o maior item do Mac** e ninguém espera. Em um caso real, `Message/Media` tinha 22 GB — mais que o Docker.

A skill também sinaliza `.pfx`, `.pem`, `.key` e `.ovpn` esquecidos em `~/Downloads`. Não apaga nada disso — só avisa que estão num lugar ruim. É um achado que costuma valer mais que os megabytes.

## Estrutura

```
limpeza-disco-mac/
├── SKILL.md            # procedimento e armadilhas (o que o Claude lê)
├── scripts/auditar.sh  # auditoria, somente leitura
└── README.md
```

## Requisitos

macOS. Docker, Homebrew, npm, pnpm, uv, Go, .NET, Xcode e afins são todos opcionais — o script detecta o que existe e ignora o resto sem erro.

## Aviso

Remoções são definitivas: não passam pela Lixeira. A skill foi escrita para ser conservadora e pedir confirmação, mas leia o que for proposto antes de aprovar. A decisão final é sempre sua.
