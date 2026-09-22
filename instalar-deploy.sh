#!/bin/bash
# Troca o deploy da home pela versao que copia a pasta inteira.
# Guarda o antigo antes, e publica uma vez para provar que funciona.
set -euo pipefail

ALVO=/usr/local/bin/deploy-yaflox.sh
NOVO="$(dirname "$0")/deploy-yaflox.sh"
test -f "$NOVO" || { echo "nao achei o deploy-yaflox.sh ao lado deste script"; exit 1; }

command -v rsync >/dev/null || { echo "instalando rsync..."; apt-get install -y -qq rsync; }

[ -f /root/deploy-yaflox.sh.antigo ] || cp "$ALVO" /root/deploy-yaflox.sh.antigo
cat > /root/desfazer-deploy.sh <<'FIM'
set -e
cp /root/deploy-yaflox.sh.antigo /usr/local/bin/deploy-yaflox.sh
chmod +x /usr/local/bin/deploy-yaflox.sh
echo "desfeito — o deploy voltou a versao anterior"
FIM
echo "· caminho de volta pronto: bash /root/desfazer-deploy.sh"

cp "$NOVO" "$ALVO"
chmod +x "$ALVO"
echo "· deploy trocado"

echo
echo "publicando agora:"
"$ALVO"
echo
curl -s -o /dev/null -w 'home:  %{http_code}\n' -L https://yaflox.com/
curl -s -o /dev/null -w 'css:   %{http_code}  (401 aqui e esperado ate rodar o liberar-assets.sh)\n' -L https://yaflox.com/fontes.css
