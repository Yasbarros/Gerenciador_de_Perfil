#!/bin/bash

CONFIG_FILE="$HOME/.dev_profiles.json"
NAVEGADOR="firefox"

# --- Verificação e Seleção de Perfil ---
if [ ! -f "$CONFIG_FILE" ]; then echo "Configuração não encontrada."; exit 1; fi
mapfile -t NOMES_PERFIS < <(jq -r '.perfis[].nome' "$CONFIG_FILE")
NUM_PERFIS=${#NOMES_PERFIS[@]}

if [ "$NUM_PERFIS" -eq 0 ]; then echo "Nenhum perfil cadastrado."; exit 1; fi
if [ "$NUM_PERFIS" -eq 1 ]; then
    PERFIL_SELECIONADO="${NOMES_PERFIS[0]}"
else
    MENU_OPTS=()
    for I in "${!NOMES_PERFIS[@]}"; do MENU_OPTS+=("$((I+1))" "${NOMES_PERFIS[$I]}"); done
    ESCOLHA=$(dialog --stdout --menu "Escolha o perfil para iniciar:" 15 60 0 "${MENU_OPTS[@]}")
    [ -z "$ESCOLHA" ] && exit 0
    PERFIL_SELECIONADO="${NOMES_PERFIS[$((ESCOLHA-1))]}"
fi

echo "Iniciando ambiente para o perfil: $PERFIL_SELECIONADO"
PERFIL_JSON=$(jq ".perfis[] | select(.nome==\"$PERFIL_SELECIONADO\")" "$CONFIG_FILE")

TODAS_URLS=()

# --- Execução das Tarefas ---
NUM_TAREFAS=$(echo "$PERFIL_JSON" | jq '.tarefas | length')
for (( I=0; I<NUM_TAREFAS; I++ )); do
    DIRETORIO=$(echo "$PERFIL_JSON" | jq -r ".tarefas[$I].diretorio")
    APP=$(echo "$PERFIL_JSON" | jq -r ".tarefas[$I].app")
    COMANDO=$(echo "$PERFIL_JSON" | jq -r ".tarefas[$I].comando")
    URL_RESULTANTE=$(echo "$PERFIL_JSON" | jq -r ".tarefas[$I].url_resultante")

    WORK_DIR="${DIRETORIO:-$HOME}"

    # 1. ABRIR O EDITOR/APP SELECIONADO
    if [ "$APP" != "terminal" ] && [ ! -z "$APP" ]; then
        echo "Abrindo $APP em $WORK_DIR..."
        # Executa o editor no diretório em background
        (cd "$WORK_DIR" && $APP . ) &
    fi

    # 2. EXECUTAR O COMANDO NO TERMINAL
    # Se houver um comando, abre um terminal para executá-lo
    if [ ! -z "$COMANDO" ] && [ "$COMANDO" != "null" ]; then
        COMANDO_FINAL="cd \"$WORK_DIR\" && echo 'Executando: $COMANDO' && $COMANDO; exec bash"
        gnome-terminal -- bash -c "$COMANDO_FINAL" &
    else
        # Se não houver comando, apenas abre o terminal na pasta se o app for "terminal"
        if [ "$APP" == "terminal" ]; then
            gnome-terminal --working-directory="$WORK_DIR" &
        fi
    fi

    # 3. COLETAR URLs
    if [ ! -z "$URL_RESULTANTE" ] && [ "$URL_RESULTANTE" != "null" ]; then
        TODAS_URLS+=("$URL_RESULTANTE")
    fi
    
    sleep 1
done

# --- Abrir URLs Gerais ---
mapfile -t URLS_GERAIS_ARR < <(echo "$PERFIL_JSON" | jq -r '.urls_gerais[]')
for URL in "${URLS_GERAIS_ARR[@]}"; do
    [ ! -z "$URL" ] && [ "$URL" != "null" ] && TODAS_URLS+=("$URL")
done

# --- Abrir Navegador ---
if [ ${#TODAS_URLS[@]} -gt 0 ]; then
    echo "Aguardando 5 segundos para os servidores iniciarem..."
    sleep 5
    echo "Abrindo ${#TODAS_URLS[@]} URLs no $NAVEGADOR..."
    $NAVEGADOR "${TODAS_URLS[@]}" &
fi

echo "Ambiente '$PERFIL_SELECIONADO' iniciado!"
