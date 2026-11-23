#!/bin/bash
# ==============================================================================
# diagnose.sh – Phase 2 Extension F: systematic, layer-by-layer fault diagnosis
#
# Run on a CLIENT Mac (Mac 4 or Mac 1), from the repo root:
#   ./scripts/diagnose.sh                 # full check, top to bottom
#   ./scripts/diagnose.sh --ip 10.7.31.100  # skip DNS, test an edge by IP
#                                           (isolates "is it DNS or not?")
# Order follows the course method: DNS -> TCP -> TLS -> HTTP/application,
# with a Layer-0 reachability check first. Nothing here changes any setting.
# The first FAIL is the layer to fix; layers below a failure are still shown
# where they can run, because they narrow the cause further.
# ==============================================================================
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/team.env"
CA="$ROOT/MAC-2/certs/ca.crt"
PORT="${DIAG_PORT:-$EDGE_PORT}"   # DIAG_PORT only for local testing
EDGES="$MAC2_IP $MAC3_IP"          # valid answers: primary edge or standby edge
FORCE_IP=""; [ "$1" = "--ip" ] && FORCE_IP="$2"
FIRST_FAIL=""
pass(){ echo "  [PASS] $*"; }
fail(){ echo "  [FAIL] $*"; [ -z "$FIRST_FAIL" ] && FIRST_FAIL="$CUR"; }
info(){ echo "  [INFO] $*"; }
hdr(){ CUR="$1"; echo; echo "== $1"; }

echo "Diagnosing https://$DOMAIN:$PORT  from $(hostname -s) ($(ipconfig getifaddr en0 2>/dev/null || echo 'no en0 IP'))  $(date '+%F %T')"

# ---------------------------------------------------------------- Layer 0
hdr "L0 LINK/IP  - am I on the LAN, can I reach the servers?"
ME=$(ipconfig getifaddr en0 2>/dev/null)
[ -n "$ME" ] && pass "en0 has IP $ME (gateway $(route -n get default 2>/dev/null | awk '/gateway/{print $2}'))" || fail "no IPv4 on en0 (Wi-Fi off / not joined)"
for h in "Mac1-DNS:$MAC1_IP" "Mac2-edge:$MAC2_IP" "Mac3-backupDNS/standby:$MAC3_IP" "Mac4-backendB:$MAC4_IP"; do
  n=${h%%:*}; ip=${h#*:}
  ping -c1 -t2 "$ip" >/dev/null 2>&1 && pass "ping $n $ip" || info "ping $n $ip no reply (host down, wrong IP in team.env, or ICMP blocked)"
done

# ---------------------------------------------------------------- Layer 1
hdr "L1 DNS  - does the name resolve, and to an edge?"
if [ -n "$FORCE_IP" ]; then
  IP="$FORCE_IP"; info "DNS skipped (--ip $IP). If this works but the normal run fails, the fault is DNS."
else
  grep -v '^\s*#' /etc/hosts | grep -qw "$DOMAIN" && fail "/etc/hosts overrides $DOMAIN: $(grep -w "$DOMAIN" /etc/hosts | grep -v '^\s*#' | head -1)"
  for s in "primary:$MAC1_IP" "backup:$MAC3_IP"; do
    n=${s%%:*}; ip=${s#*:}
    a=$(dig @"$ip" "$DOMAIN" +short +time=2 +tries=1 2>&1 | tail -1)
    case "$a" in
      *"timed out"*|*"no servers"*|"") info "$n DNS $ip: NO ANSWER (dnsmasq stopped / host down / UDP 53 blocked)";;
      *refused*) info "$n DNS $ip: REFUSED";;
      *) echo " $EDGES " | grep -q " $a " && pass "$n DNS $ip -> $a" || fail "$n DNS $ip -> $a  (NOT an edge IP: wrong record)";;
    esac
  done
  IP=$(dscacheutil -q host -a name "$DOMAIN" 2>/dev/null | awk '/ip_address/{print $2; exit}')
  if [ -z "$IP" ]; then
    fail "system resolver cannot resolve $DOMAIN (client DNS config: $(scutil --dns | awk '/domain   : team1.test/{f=1} f&&/nameserver/{printf $3" "} /^$/{f=0}')$(networksetup -getdnsservers Wi-Fi 2>/dev/null | tr '\n' ' '))"
  elif echo " $EDGES " | grep -q " $IP "; then pass "system resolver: $DOMAIN -> $IP"
  else fail "system resolver: $DOMAIN -> $IP (NOT an edge; stale cache? try: sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder)"; fi
fi

# ---------------------------------------------------------------- Layer 4
hdr "L4 TCP  - is anything listening on $IP:$PORT?"
if [ -z "$IP" ]; then info "skipped (no IP to connect to)"; else
  out=$(nc -G 3 -w 3 -vz "$IP" "$PORT" 2>&1)
  case "$out" in
    *succeeded*) pass "TCP connect $IP:$PORT (3-way handshake OK)";;
    *refused*)   fail "TCP $IP:$PORT REFUSED -> host up, nothing listening (nginx stopped / wrong port)";;
    *)           fail "TCP $IP:$PORT TIMEOUT -> packets dropped (firewall/pf) or host unreachable";;
  esac
fi

# ---------------------------------------------------------------- Layer 5/6
hdr "L5/6 TLS  - handshake + certificate trust"
if [ -z "$IP" ]; then info "skipped"; else
  s=$(openssl s_client -connect "$IP:$PORT" -servername "$DOMAIN" -CAfile "$CA" </dev/null 2>&1)
  if echo "$s" | grep -q "Verify return code: 0 (ok)"; then
    pass "handshake OK, cert chains to Team1 Root CA: $(echo "$s" | awk -F'subject=' '/subject=/{print $2; exit}' | grep -o 'CN *= *[^,]*')"
  elif echo "$s" | grep -qE "connect:errno|Connection refused|timed out"; then info "TLS not reached (TCP failed)"
  else fail "TLS problem: $(echo "$s" | grep -m1 -E 'Verify return code|verify error|alert|error' )"; fi
  c=$(curl -s -o /dev/null -w '%{http_code}' "https://$DOMAIN:$PORT/" --connect-to "$DOMAIN:$PORT:$IP:$PORT" 2>&1; echo " rc=$?")
  case "$c" in *"rc=60"*) fail "THIS Mac does not trust the Root CA (curl error 60) -> install MAC-2/certs/ca.crt in System keychain";;
               *"rc=0"*) pass "system trust store accepts the certificate (no -k needed)";; esac
fi

# ---------------------------------------------------------------- Layer 7
hdr "L7 HTTP/APP  - does the edge get an answer from a backend? (uses repo CA, so it works even if L5/6 trust failed)"
if [ -z "$IP" ]; then info "skipped"; else
  H=$(curl -s -m 8 --cacert "$CA" -D - -o /dev/null --connect-to "$DOMAIN:$PORT:$IP:$PORT" "https://$DOMAIN:$PORT/api/status" -w 'code=%{http_code}\n' 2>&1 | tr -d '\r')
  code=$(echo "$H" | awk -F= '/^code=/{print $2}'); edge=$(echo "$H" | awk 'tolower($1)=="x-edge:"{print $2}'); be=$(echo "$H" | awk 'tolower($1)=="x-backend:"{print $2}')
  case "$code" in
    200) pass "HTTP 200 from edge=${edge:-?} backend=${be:-?}";;
    502) fail "HTTP 502 Bad Gateway from edge=${edge:-?} -> edge OK, it cannot reach ANY backend (backends down / wrong upstream IP or port / pf blocking the edge)";;
    504) fail "HTTP 504 Gateway Timeout -> backend reachable but too slow / packets dropped";;
    000|"") info "no HTTP response (lower layer failed)";;
    *) fail "HTTP $code from edge=${edge:-?} backend=${be:-?}";;
  esac
  echo "  -- backends as seen from THIS client (timeout here is NORMAL while Ext C pf is on):"
  for b in "A:$MAC3_IP:$BACKEND_A_PORT" "B:$MAC4_IP:$BACKEND_B_PORT"; do
    IFS=: read n bip bport <<<"$b"
    r=$(nc -G 3 -w 3 -vz "$bip" "$bport" 2>&1)
    case "$r" in *succeeded*) info "Backend $n $bip:$bport listening";; *refused*) info "Backend $n $bip:$bport REFUSED (process not running)";; *) info "Backend $n $bip:$bport timeout (pf isolation or host down)";; esac
  done
fi

echo
if [ -z "$FIRST_FAIL" ]; then echo "VERDICT: all layers healthy."
else echo "VERDICT: first failing layer = ${FIRST_FAIL%% *}  -> fix this layer first (see docs/EXT_F_TROUBLESHOOTING_RUNBOOK.md)"; fi
