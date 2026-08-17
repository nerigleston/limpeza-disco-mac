---
name: limpeza-disco-mac
description: Audita e libera espaço em disco no macOS com segurança, em fluxo mapear → confirmar → executar. Use quando o usuário disser que o disco está cheio, pedir para liberar/limpar espaço, perguntar o que está ocupando o disco, ou mencionar caches de Docker, npm, pnpm, Xcode, Homebrew, WhatsApp e afins.
---

# Limpeza de disco no macOS

Libera espaço sem destruir nada importante. A regra que sustenta tudo: **medir antes, mostrar o comando, confirmar, só então apagar.**

## Princípio inegociável

Nunca execute um `rm` que o usuário não tenha visto e aprovado. Ganho de espaço nunca justifica risco de perda de dados — quando os dois entrarem em conflito, pare e pergunte.

Antes de qualquer remoção, responda para si mesmo: **isso se regenera sozinho?** Cache, build, `node_modules`, venv e imagem de container: sim. Banco de dados, código sem git, documento, foto: não. O segundo grupo só sai com autorização explícita e informada.

## Fluxo

### 1. Auditar (nunca apaga nada)

Execute `scripts/auditar.sh`. Ele mede tudo e não remove nada.

Ao ler o resultado, **use a linha de `/System/Volumes/Data`, não a de `/`.** No macOS moderno `/` é o volume de sistema selado e mostra ~12 GB usados, um número irrelevante. O uso real está no volume de dados.

### 2. Categorizar

Separe os achados em três grupos e apresente-os assim ao usuário:

- **Regenerável** — caches, builds, `node_modules`, venvs, imagens de container. Baixo risco.
- **Decisão do usuário** — vídeos, downloads, projetos, apps. Você lista e mede; quem decide é ele.
- **Não tocar** — bancos de dados, código sem git, credenciais, documentos.

Ordene por tamanho e diga sempre o que se perde, não só o que se ganha.

### 3. Confirmar e executar

Mostre o comando exato antes de rodar. Meça o espaço livre antes e depois de cada etapa e reporte o valor real — nunca o esperado.

## Armadilhas verificadas em uso real

Cada item abaixo custou um erro real. Não pule nenhum.

### Docker: nunca use `--volumes`

`docker system prune -a --volumes` é o conselho mais repetido da internet e o mais perigoso. Volumes aparecem como `dangling` quando o container que os montava foi removido — mas **os dados continuam lá**. Em uma máquina real, os 41 volumes "órfãos" eram bancos Postgres, SQL Server e Redis de projetos ativos, e o prune renderia só 2,5 GB.

Use apenas:
```bash
docker system df              # sempre medir antes
docker builder prune -af      # build cache — costuma ser o maior ganho
docker image prune -af        # imagens sem container
```

Para volumes, liste com `docker system df -v` e leve nome por nome ao usuário. Volumes com nome descritivo (`app_postgres_data`) são quase sempre dados reais.

**O espaço não aparece na hora.** No macOS o Docker roda numa VM; liberar dentro dela não encolhe o arquivo de disco imediatamente. Meça, avise que pode demorar, e remeça depois — em uso real, 14,7 GB liberados na VM levaram minutos para refletir no host.

### Verifique o dono antes de apagar apps

Apps em `/Applications` podem pertencer ao `root`. Um `rm -rf` sem privilégio apaga a parte gravável, falha no resto e **deixa o app quebrado pela metade** — inclusive o desinstalador oficial.

```bash
ls -ld "/Applications/Nome.app"    # SEMPRE antes do rm
```

Se o dono for `root`, não rode `sudo` por conta própria: entregue o comando ao usuário para ele executar. Apps grandes costumam ter suporte extra em `/Library/Application Support/<Fabricante>` — meça e inclua na conta.

### `du` mede tamanho lógico, `df` mede o disco

Em APFS, arquivos clonados compartilham blocos: `du` conta cada um por inteiro, o disco libera só uma vez. Uma pasta de 23 GB pode render bem menos.

**Reporte sempre o ganho medido pelo `df`, nunca o tamanho que o `du` mostrava.** Se a diferença for grande, diga isso em vez de inventar explicação.

### Pastas de projeto: apague o miolo, não a pasta

Antes de remover qualquer pasta de projeto:

```bash
[ -d "$p/.git" ] && git -C "$p" remote -v      # tem backup remoto?
du -sh "$p"/node_modules "$p"/.venv "$p"/venv  # o que realmente pesa?
```

Quase sempre 80–95% do tamanho é `node_modules` ou venv, e o código são poucos KB. Apagar só isso entrega quase todo o ganho e preserva o trabalho. Um projeto **sem git ou sem remote não tem backup nenhum** — trate como insubstituível.

Cuidado com o teste em pipeline: `git ... | head || echo` avalia o status do `head`, não do `git`. Teste `[ -d "$p/.git" ]` diretamente.

### Duplicatas: compare o conteúdo, não o nome

Arquivos com `(1)`, `(2)` no nome frequentemente **não** são cópias. Em um caso real, de 79 candidatos apenas 12 eram idênticos.

```bash
cmp -s "$copia" "$original" && echo "idêntico — pode remover"
```

Recompare no momento de apagar, não só na análise.

### Instaladores: confirme que o app está instalado

`.dmg` e `.pkg` em Downloads são descarte fácil — depois de verificar que o app existe em `/Applications`.

### `simctl` exige Xcode completo

`xcrun simctl delete unavailable` falha se só há Command Line Tools. Verifique com `xcode-select -p` e `ls -d /Applications/Xcode*.app`. Sem Xcode instalado, `~/Library/Developer/CoreSimulator/Devices` é resíduo órfão e pode ir inteiro.

### WhatsApp costuma ser o maior item — e ninguém espera

Verifique sempre:
```bash
du -sh ~/Library/Group\ Containers/group.net.whatsapp.WhatsApp.shared/Message/Media
```
Em uma máquina real eram 22 GB — mais que o Docker. Remova **apenas** `Message/Media`; os bancos (`ChatStorage.sqlite`), o índice de busca e os stickers ficam. Mídia apagada pode não estar mais disponível para rebaixar: avise antes.

Para identificar os grupos que mais ocupam, copie o banco e leia a cópia:
```bash
cp ~/Library/Group\ Containers/group.net.whatsapp.WhatsApp.shared/ChatStorage.sqlite /tmp/cs.sqlite
sqlite3 /tmp/cs.sqlite "SELECT ZPARTNERNAME FROM ZWACHATSESSION WHERE ZCONTACTJID='<jid>';"
```
Apague a cópia ao terminar — ela contém as mensagens do usuário.

### Feche o app antes de mexer nos dados dele

Cheque com `pgrep -x` antes de tocar em Chrome, Zed, CapCut, WhatsApp ou Docker.

### Chrome: só o `Service Worker`

`Default/Service Worker` é cache de PWAs e costuma ser vários GB — sai sem afetar senhas, cookies, histórico ou extensões. **Não** remova `WebStorage`, `IndexedDB` nem `Local Storage`: ali ficam sessões e dados offline, e apagá-los desloga sites e pode perder rascunhos.

### Locks de cache

`uv cache clean` falha se outro processo `uv` estiver ativo (um servidor MCP, por exemplo). Confirme com `pgrep -fl uv` e use `--force` quando o processo for legítimo e o cache for só download.

## Alvos por categoria

**Baixo risco** — `docker builder prune -af`, `docker image prune -af`, `brew cleanup -s`, `npm cache clean --force`, `pnpm store prune`, `uv cache clean`, `dotnet nuget locals all --clear`, `go clean -cache -modcache`, `~/Library/Developer/Xcode/DerivedData`, `node_modules` e venvs de projetos parados, `.dmg` de apps já instalados.

**Confirmar antes** — WhatsApp `Message/Media`, Chrome `Service Worker`, `~/.rustup/toolchains` (só se não usa Rust), `~/Library/Python/3.x` (leva junto CLIs instaladas via pip — liste antes), caches do CapCut em `~/Movies/CapCut/User Data/Cache` (os projetos ficam em `Projects` e devem ser preservados), wallpapers aéreos em `com.apple.idleassetsd`, apps grandes em `/Applications`, Downloads.

**Nunca sem autorização explícita e informada** — volumes Docker, projetos sem git remote, `~/Documents`, `~/Movies`, chaves e certificados.

## Segurança, além do espaço

Downloads costuma acumular material sensível: `.pfx`, `.pem`, `.key`, `.ovpn`, backups de banco. **Não apague nem mova** — mas avise o usuário de que estão num lugar inadequado. É um achado que vale mais que os megabytes.

## Relatório final

Ao terminar, informe: espaço livre antes e depois (medido, não estimado), ganho por etapa, o que foi preservado e por quê, o que ficou pendente e o comando exato para concluir. Se algo falhou ou rendeu menos que o previsto, diga com todas as letras.
