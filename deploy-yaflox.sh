#!/bin/bash
# ══════════════════════════════════════════════════════════════════════
#  PUBLICA A HOME INSTITUCIONAL — A PASTA INTEIRA, E NAO UM ARQUIVO
#
#  A versao anterior copiava so o index.html. Isso funcionou enquanto o
#  site era um arquivo; no dia em que ganhou uma pasta `assets`, ela
#  simplesmente nao foi publicada — SEM ERRO E SEM AVISO. O deploy
#  dizia "codigo de saida: 0" e a pasta nao estava la.
#
#  Falha silenciosa e a pior especie: o site parece publicado, e o que
#  falta so aparece como um 404 que alguem vai cacar depois.
#
#  Agora copia tudo, e o --delete tira do site o que saiu do
#  repositorio — senao um arquivo apagado no git fica vivo no servidor
#  para sempre.
# ══════════════════════════════════════════════════════════════════════
set -euo pipefail

REPO=/opt/yaflox-site
SITE=/var/www/yaflox
CHAVE=/root/.ssh/profitlab_deploy

export GIT_SSH_COMMAND="ssh -i $CHAVE -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"

test -d "$REPO/.git" || { echo "nao achei o repositorio em $REPO"; exit 1; }

git -C "$REPO" fetch --quiet origin
git -C "$REPO" reset --hard --quiet origin/main

mkdir -p "$SITE"

# --delete: o site passa a ser o espelho do repositorio.
# As exclusoes sao coisas que vivem no repositorio e nao no site: o
# proprio .git, os scripts de operacao e o README. Publicar um .sh
# junto com a home seria entregar o script de deploy para quem pedir.
rsync -a --delete \
  --exclude '.git' \
  --exclude '.github' \
  --exclude '*.sh' \
  --exclude 'README.md' \
  "$REPO"/ "$SITE"/

chown -R www-data:www-data "$SITE" 2>/dev/null || true

echo "publicado em $SITE:"
find "$SITE" -type f | sed 's|^|  |'
