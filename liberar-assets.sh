#!/bin/bash
# ══════════════════════════════════════════════════════════════════════
#  ENSINA O NGINX ONDE FICAM OS ARQUIVOS DA HOME (fonte, imagem, css)
#
#  Sem esta regra, o pedido de /assets/... cai no bloco do Profit Lab,
#  que pede senha — e a fonte volta 401 em vez de carregar.
#
#  O `^~` existe para esta regra GANHAR daquela. Sem ele, o nginx
#  escolhe a outra e nada muda.
#
#  Para desfazer:  bash /root/desfazer-assets.sh
# ══════════════════════════════════════════════════════════════════════
set -euo pipefail

CONF=/etc/nginx/sites-enabled/profitlab
test -f "$CONF" || { echo "nao achei $CONF — parei"; exit 1; }

# ── 1. o caminho de volta, ANTES de mexer ─────────────────────────────
[ -f /root/profitlab.nginx.antes-do-assets ] || cp "$CONF" /root/profitlab.nginx.antes-do-assets
cat > /root/desfazer-assets.sh <<'FIM_DESFAZER'
set -e
cp /root/profitlab.nginx.antes-do-assets /etc/nginx/sites-enabled/profitlab
nginx -t && systemctl reload nginx
echo "desfeito — o nginx voltou ao que era"
FIM_DESFAZER
echo "· caminho de volta pronto: bash /root/desfazer-assets.sh"

# ── 2. a pasta precisa EXISTIR antes ──────────────────────────────────
# Regra apontando para prateleira vazia troca 401 por 404, e a pessoa
# acha que o conserto falhou quando o que falta e o arquivo.
if [ ! -d /var/www/yaflox/assets ]; then
  echo
  echo ">>> PAREI: /var/www/yaflox/assets nao existe."
  echo "    A fonte ainda nao chegou no servidor."
  echo "    Faca o Passo 1 (criar assets/fonts no repositorio e dar Push),"
  echo "    espere 5 minutos, e rode este script de novo."
  exit 1
fi
echo "· a pasta /var/www/yaflox/assets existe"

# ── 3. a regra ────────────────────────────────────────────────────────
python3 - <<'FIM_PATCH'
p = "/etc/nginx/sites-enabled/profitlab"
s = open(p, encoding="utf-8").read()
if "location ^~ /assets/" in s:
    print("· a regra ja estava la — nada a fazer")
else:
    bloco = """    # Os arquivos da home institucional: fonte, imagem, css.
    #
    # A home responde por `location = /`, que casa com a barra EXATA e
    # mais nada. Entao /assets/... nao casava com ela, nao casava com o
    # /profitlab/, e caia no `location /` — que pede senha. Era por isso
    # que a fonte voltava 401 em vez de carregar.
    #
    # O ^~ faz esta regra ganhar daquele `location /`. Sem ele, o nginx
    # escolhe o outro e nada muda.
    #
    # `root` e nao `alias`: a raiz e /var/www/yaflox e o nginx completa
    # com /assets/..., que e onde o arquivo esta. O alias faria o mesmo,
    # e erra por uma barra a mais ou a menos no fim — que e o engano
    # mais comum de nginx e nao da erro nenhum, so 404.
    location ^~ /assets/ {
        root /var/www/yaflox;
        auth_basic off;
        expires 30d;
        access_log off;
    }

"""
    # A PRIMEIRA ocorrencia, de proposito: o arquivo tem dois server
    # blocks (o do site e o redirect da porta 80 que o certbot criou), e
    # a regra tem de entrar no primeiro.
    alvo = "location = /profitlab"
    if alvo not in s:
        alvo = "location /profitlab"
    assert alvo in s, "nao achei o bloco do profitlab — pare e me mostre o arquivo"
    i = s.index(alvo)
    # recua ate o comeco da linha, para nao quebrar a indentacao
    ini = s.rfind("\n", 0, i) + 1
    s = s[:ini] + bloco + s[ini:]
    open(p, "w", encoding="utf-8").write(s)
    print("· regra inserida no nginx")
FIM_PATCH

# ── 4. conferir ANTES de recarregar ───────────────────────────────────
# nginx -t le a configuracao inteira e recusa se houver erro. Recarregar
# sem isso e como virar a chave sem olhar: o site cai e so se descobre
# depois.
nginx -t
systemctl reload nginx
echo "· nginx recarregado"

echo
curl -s -o /dev/null -w 'home:     %{http_code}\n' -L https://yaflox.com/
curl -s -o /dev/null -w 'fonte:    %{http_code}\n' -L https://yaflox.com/assets/fonts/cormorant-600.woff2
curl -s -o /dev/null -w 'profitlab:%{http_code}\n' -L https://yaflox.com/profitlab/
echo
echo "O que eu espero: home 200, fonte 200, profitlab 401 (esse 401 e a senha, e esta certo)."
echo "Se algo estiver estranho: bash /root/desfazer-assets.sh"
