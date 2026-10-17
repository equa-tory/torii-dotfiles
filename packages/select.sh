#!/usr/bin/env bash
# A small checkbox list for the installer (plain bash 3.2, no dialog/fzf needed on a fresh machine).
# Fill ITEM_ID / ITEM_LABEL / ITEM_GROUP / ITEM_ON (1 or 0) first, then call `torii_select "title"`.
#   up/down or k/j  move     space  toggle (on a group title: the whole group)     a  all     n  none
#   enter  confirm           q or Esc  cancel
# Returns 0 on enter (ITEM_ON updated), 1 on cancel.

torii_select() {
  local title="$1" n=${#ITEM_ID[@]} i g j
  local ROW_KIND=() ROW_REF=()
  # a title row per group, followed by the group's items
  local seen=""
  for ((i = 0; i < n; i++)); do
    g="${ITEM_GROUP[i]}"
    case "|$seen|" in *"|$g|"*) continue ;; esac
    seen="$seen|$g"
    ROW_KIND+=(h); ROW_REF+=("$g")
    for ((j = 0; j < n; j++)); do
      [ "${ITEM_GROUP[j]}" = "$g" ] && { ROW_KIND+=(i); ROW_REF+=("$j"); }
    done
  done

  local rows=${#ROW_KIND[@]} cur=1 key rest drawn=0
  [ "${ROW_KIND[0]}" = h ] || cur=0
  printf '\033[?25l'
  trap 'printf "\033[?25h"' RETURN

  draw() {
    local r idx mark line k on all
    [ "$drawn" = 1 ] && printf '\033[%dA' $((rows + 3))
    printf '\033[2K\n\033[2K\033[1m%s\033[0m\n\033[2K  \033[2mup/down move · space toggle · a all · n none · enter install · q quit\033[0m\n' "$title"
    for ((r = 0; r < rows; r++)); do
      if [ "${ROW_KIND[r]}" = h ]; then
        g="${ROW_REF[r]}"; on=0; all=0
        for ((idx = 0; idx < n; idx++)); do [ "${ITEM_GROUP[idx]}" = "$g" ] && { all=$((all + 1)); [ "${ITEM_ON[idx]}" = 1 ] && on=$((on + 1)); }; done
        mark="[ ]"; [ "$on" -eq "$all" ] && mark="[x]"; { [ "$on" -gt 0 ] && [ "$on" -lt "$all" ]; } && mark="[-]"
        line=" $mark \033[1m$g\033[0m"
      else
        idx="${ROW_REF[r]}"; mark="[ ]"; [ "${ITEM_ON[idx]}" = 1 ] && mark="[x]"
        line="     $mark ${ITEM_LABEL[idx]}"
      fi
      if [ "$r" -eq "$cur" ]; then printf '\033[2K\033[7m%b\033[0m\n' "$line"; else printf '\033[2K%b\n' "$line"; fi
    done
    drawn=1
  }

  toggle() {
    local r="$cur" idx g v=1
    if [ "${ROW_KIND[r]}" = h ]; then
      g="${ROW_REF[r]}"
      for ((idx = 0; idx < n; idx++)); do [ "${ITEM_GROUP[idx]}" = "$g" ] && [ "${ITEM_ON[idx]}" = 0 ] && v=0; done
      [ "$v" = 1 ] && v=0 || v=1       # all on -> switch off, otherwise switch on
      for ((idx = 0; idx < n; idx++)); do [ "${ITEM_GROUP[idx]}" = "$g" ] && ITEM_ON[idx]=$v; done
    else
      idx="${ROW_REF[r]}"; [ "${ITEM_ON[idx]}" = 1 ] && ITEM_ON[idx]=0 || ITEM_ON[idx]=1
    fi
  }

  draw
  while IFS= read -rsn1 key; do
    case "$key" in
      "") printf '\n'; return 0 ;;                                  # enter
      " ") toggle ;;
      a|A) for ((i = 0; i < n; i++)); do ITEM_ON[i]=1; done ;;
      n|N) for ((i = 0; i < n; i++)); do ITEM_ON[i]=0; done ;;
      j) cur=$(((cur + 1) % rows)) ;;
      k) cur=$(((cur + rows - 1) % rows)) ;;
      q|Q) return 1 ;;
      $'\033')
        rest=""; IFS= read -rsn2 -t 0.05 rest || true
        case "$rest" in
          "[A") cur=$(((cur + rows - 1) % rows)) ;;
          "[B") cur=$(((cur + 1) % rows)) ;;
          "") return 1 ;;
        esac ;;
    esac
    draw
  done
  return 1
}
