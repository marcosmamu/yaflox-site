#!/bin/bash
# ══════════════════════════════════════════════════════════════════════
#  PUBLICA A HOME INSTITUCIONAL — A PASTA INTEIRA, E NAO UM ARQUIVO
#
#  A versao anterior copiava so o index.html. Funcionou enquanto o site
#  era um arquivo; no dia em que ganhou uma pasta `assets`, ela nao foi
#  publicada — SEM ERRO E SEM AVISO. O deploy dizia "codigo de saida: 0"
#  e a pasta nao estava la. Falha silenciosa e a pior especie: o site
#  parece publicado, e o que falta vira um 404 que alguem caca depois.
#
#  ═══ POR QUE NAO HA GIT_SSH_COMMAND AQUI ═══
#
#  A primeira versao deste script forcava a chave
#  /root/.ssh/profitlab_deploy. Essa e a deploy key do repositorio
#  profit-lab, e deploy key do GitHub vale para UM repositorio so — daí
#  "Repository not found", que e como o GitHub diz "sem permissao".
#
#  O clone em /opt/yaflox-site ja tem a sua propria autenticacao
#  configurada, e ela funciona (foi por ela que os arquivos chegaram).
#  Entao o certo e nao mandar nada: o git usa o que ja esta ali.
#  Forcar credencial onde ja existe uma que funciona so troca uma que
#  da certo por um palpite.
# ══════════════════════════════════════════════════════════════════════
set -euo pipefail

REPO=/opt/yaflox-site
SITE=/var/www/yaflox

test -d "$REPO/.git" || { echo "nao achei o repositorio em $REPO"; exit 1; }

# ═══ O FETCH E A CONDICAO PARA PUBLICAR ═══
#
# Se buscar falhar, o script PARA aqui e nao toca no site. Isso
# importa por causa do --delete la embaixo: publicar a partir de um
# repositorio em estado duvidoso poderia apagar o site inteiro.
# Com `set -e` isso ja aconteceria; a mensagem existe para dizer
# POR QUE nada foi publicado.
if ! git -C "$REPO" fetch --quiet origin; then
  echo "nao consegui buscar do GitHub — NADA foi publicado."
  echo "o site continua com a versao anterior, intacta."
  exit 1
fi

RAMO="$(git -C "$REPO" symbolic-ref --short HEAD 2>/dev/null || echo main)"
git -C "$REPO" reset --hard --quiet "origin/$RAMO"

mkdir -p "$SITE"

command -v rsync >/dev/null || { echo "rsync nao esta instalado"; exit 1; }

# --delete: o site passa a ser o espelho do repositorio. Sem ele, um
# arquivo apagado no git ficaria vivo no servidor para sempre.
#
# As exclusoes sao coisas que vivem no repositorio e nao no site.
# Publicar um .sh junto com a home seria entregar o script de deploy
# para quem pedisse a URL dele.
rsync -a --delete \
  --exclude '.git' \
  --exclude '.github' \
  --exclude '*.sh' \
  --exclude '*.txt' \
  --exclude 'README.md' \
  "$REPO"/ "$SITE"/

chown -R www-data:www-data "$SITE" 2>/dev/null || true

echo "publicado em $SITE:"
find "$SITE" -type f | sed 's|^|  |'
