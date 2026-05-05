#!/bin/bash

SERVER="127.0.0.1"
SUPPORTED_TYPES=("A" "AAAA" "CNAME" "PTR" "MX" "TXT" "NS" "SRV")

# ═══════════════════════════════════════════
#  MOTEUR D'AFFICHAGE (COULEURS ET ESPACES)
# ═══════════════════════════════════════════

function color() {
    declare -A c=([red]=31 [green]=32 [yellow]=33 [blue]=34 [cyan]=36 [white]=37 [magenta]=35 [bold]=1)
    echo -e "\e[${c[$2]:-37}m${1}\e[0m"
}

function blank() { echo ""; }

function sep() {
    color "  ──────────────────────────────────────────────────────────" "white"
}

function header() {
    clear
    blank
    color "  ╔══════════════════════════════════════════════════════╗" "cyan"
    color "  ║          🌐 GESTION DNS — SAMBA ACTIVE DIRECTORY     ║" "bold"
    color "  ╚══════════════════════════════════════════════════════╝" "cyan"
    blank
}

function section() {
    blank
    color "  ─── $1" "yellow"
    blank
}

function confirm() {
    blank
    read -p "   $(color "Confirmar l'opération ?" "magenta") [o/N] " _c
    [[ "$_c" == "o" || "$_c" == "O" ]]
}

# ═══════════════════════════════════════════
#  FONCTIONS UTILES (LISTAGE ET FILTRES)
# ═══════════════════════════════════════════

function list_zones() {
    color "   Zones Directes :" "cyan"
    samba-tool dns zonelist $SERVER -P | grep "pszZoneName" | cut -d ':' -f 2 | sed 's/^[[:space:]]*//' | grep -vE "in-addr\.arpa|_msdcs" | while read -r z; do echo "     • $z"; done
    blank
    color "   Zones Inverses :" "cyan"
    samba-tool dns zonelist $SERVER -P | grep "pszZoneName" | grep "in-addr\.arpa" | cut -d ':' -f 2 | sed 's/^[[:space:]]*//' | while read -r z; do echo "     • $z"; done
}

function pick_zone() {
    local varname="$1"
    local zone
    blank
    read -p "   Zone (? pour lister) : " zone
    if [[ "$zone" == "?" ]]; then
        blank
        list_zones
        blank
        read -p "   Nom de la zone : " zone
    fi
    [[ -z "$zone" ]] && { color "   Erreur : Aucune zone spécifiée." "red"; return 1; }
    printf -v "$varname" '%s' "$zone"
}

function list_records_inline() {
    local zone="$1"
    RECORDS_LIST=()

    local output
    output=$(samba-tool dns query $SERVER "$zone" @ ALL -P 2>/dev/null)

    blank
    sep
    printf "   \e[36m%-4s %-25s %-8s %s\e[0m\n" "ID" "NOM (HOST)" "TYPE" "VALEUR"
    sep

    local name=""

    while IFS= read -r line; do
        # Nombre del host
        if [[ "$line" =~ Name= ]]; then
            name=$(echo "$line" | sed -n 's/.*Name=\([^,]*\).*/\1/p')
        fi

        # Líneas con datos reales (A, AAAA, CNAME, etc.)
        if [[ "$line" =~ ^[[:space:]]*(A|AAAA|CNAME|PTR|MX|TXT|SRV): ]]; then
            type=$(echo "$line" | cut -d ':' -f1 | xargs)
            value=$(echo "$line" | cut -d ':' -f2- | sed 's/(.*//g' | xargs)

            if [[ -n "$name" && "$name" != "@" ]]; then
                RECORDS_LIST+=("$name|$type|$value")
            fi
        fi
    done <<< "$output"

    if (( ${#RECORDS_LIST[@]} == 0 )); then
        echo "   (Aucun enregistrement trouvé)"
    else
        local i=1
        for entry in "${RECORDS_LIST[@]}"; do
            IFS='|' read -r n t v <<< "$entry"
            printf "   %-4s %-25s \e[33m%-8s\e[0m %s\n" "$i)" "$n" "$t" "$v"
            (( i++ ))
        done
    fi
    sep
}

# ═══════════════════════════════════════════
#  ACTIONS PRINCIPALES
# ═══════════════════════════════════════════

function add_record() {
    section "AJOUTER UN ENREGISTREMENT"
    local zone
    pick_zone zone || return

    blank
    color "   Types supportés : ${SUPPORTED_TYPES[*]}" "white"
    read -p "   Type d'enregistrement : " g_type
    g_type="${g_type^^}"
    
    read -p "   Nom d'hôte (ex: pc01) : " g_host
    read -p "   Valeur (IP ou Cible)  : " g_value

    blank
    color "   RÉCAPITULATIF :" "cyan"
    echo "   • Zone   : $zone"
    echo "   • Host   : $g_host"
    echo "   • Type   : $g_type"
    echo "   • Valeur : $g_value"
    
    confirm || return

    blank
    samba-tool dns add $SERVER "$zone" "$g_host" "$g_type" "$g_value" -P \
        && color "   ✔ Succès : Enregistrement ajouté." "green" \
        || color "   ✘ Échec : Erreur lors de l'ajout." "red"
    blank
    read -p "Appuyez sur Entrée pour continuer..."
}

function delete_record() {
    section "SUPPRIMER UN ENREGISTREMENT"
    local zone
    pick_zone zone || return
    list_records_inline "$zone"

    blank
    read -p "   Nom de l'hôte à supprimer : " host
    read -p "   Type (ex: A, CNAME) : " type
    read -p "   Valeur exacte : " val

    confirm || return

    blank
    samba-tool dns delete $SERVER "$zone" "$host" "${type^^}" "$val" -P \
        && color "   ✔ Succès : Enregistrement supprimé." "green" \
        || color "   ✘ Échec : Impossible de supprimer." "red"
    blank
    read -p "Appuyez sur Entrée para continuer..."
}

# ═══════════════════════════════════════════
#  MENU PRINCIPAL
# ═══════════════════════════════════════════

function main() {
    [[ $EUID -ne 0 ]] && color "   Erreur : Ce script doit être lancé en ROOT." "red" && exit 1

    while true; do
        header
        echo "    1) 📑 Lister les enregistrements"
        echo "    2) ➕ Ajouter un enregistrement"
        echo "    3) ➖ Supprimer un enregistrement"
        echo "    4) 🔄 Modifier un enregistrement"
        echo "    5) 🚪 Quitter"
        blank
        read -p "   Votre choix : " opcion

        case $opcion in
            1) section "CONSULTATION"; if pick_zone z; then list_records_inline "$z"; fi; blank; read -p "Entrée pour revenir au menu...";;
            2) add_record ;;
            3) delete_record ;;
            4) section "MODIFICATION"; color "   Astuce : Supprimez puis recréez l'enregistrement." "yellow"; sleep 2 ;;
            5) blank; color "   Au revoir !" "green"; blank; exit 0 ;;
            *) color "   Choix invalide." "red"; sleep 1 ;;
        esac
    done
}

main