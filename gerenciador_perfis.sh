#!/bin/bash

CONFIG_FILE="$HOME/.dev_profiles.json"
NAVEGADOR="firefox"

# -------------------------------
# FUNÇÃO: INICIAR AMBIENTE
# -------------------------------
iniciar_ambiente() {

    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Configuração não encontrada."
        exit 1
    fi

    mapfile -t NOMES_PERFIS < <(jq -r '.perfis[].nome' "$CONFIG_FILE")
    NUM_PERFIS=${#NOMES_PERFIS[@]}

    if [ "$NUM_PERFIS" -eq 0 ]; then
        echo "Nenhum perfil cadastrado."
        exit 1
    fi

    if [ "$NUM_PERFIS" -eq 1 ]; then
        PERFIL_SELECIONADO="${NOMES_PERFIS[0]}"
    else
        MENU_OPTS=()
        for I in "${!NOMES_PERFIS[@]}"; do
            MENU_OPTS+=("$((I+1))" "${NOMES_PERFIS[$I]}")
        done
        ESCOLHA=$(dialog --stdout --menu "Escolha o perfil para iniciar:" 15 60 0 "${MENU_OPTS[@]}")
        [ -z "$ESCOLHA" ] && exit 0
        PERFIL_SELECIONADO="${NOMES_PERFIS[$((ESCOLHA-1))]}"
    fi

    echo "Iniciando ambiente para o perfil: $PERFIL_SELECIONADO"

    PERFIL_JSON=$(jq ".perfis[] | select(.nome==\"$PERFIL_SELECIONADO\")" "$CONFIG_FILE")

    TODAS_URLS=()
    NUM_TAREFAS=$(echo "$PERFIL_JSON" | jq '.tarefas | length')

    for (( I=0; I<NUM_TAREFAS; I++ )); do
        DIRETORIO=$(echo "$PERFIL_JSON" | jq -r ".tarefas[$I].diretorio")
        APP=$(echo "$PERFIL_JSON" | jq -r ".tarefas[$I].app")
        COMANDO=$(echo "$PERFIL_JSON" | jq -r ".tarefas[$I].comando")
        URL_RESULTANTE=$(echo "$PERFIL_JSON" | jq -r ".tarefas[$I].url_resultante")

        WORK_DIR="${DIRETORIO:-$HOME}"
        
        # Verificar se o diretório existe
        if [ ! -d "$WORK_DIR" ]; then
            echo "Aviso: Diretório não encontrado: $WORK_DIR"
        fi

        # Abrir aplicativo
        if [ ! -z "$APP" ] && [ "$APP" != "null" ]; then
            if [ "$APP" = "terminal" ]; then
                # Abrir terminal no diretório
                if command -v gnome-terminal &> /dev/null; then
                    (cd "$WORK_DIR" && gnome-terminal --working-directory="$WORK_DIR") &
                elif command -v xterm &> /dev/null; then
                    (cd "$WORK_DIR" && xterm -e "cd '$WORK_DIR' && bash") &
                else
                    echo "Terminal não encontrado"
                fi
            else
                # Abrir aplicativo normal
                (cd "$WORK_DIR" && nohup "$APP" >/dev/null 2>&1 &)
            fi
        fi

        # Executar comando
        if [ ! -z "$COMANDO" ] && [ "$COMANDO" != "null" ]; then
            (cd "$WORK_DIR" && nohup $COMANDO >/dev/null 2>&1 &)
        fi

        # Abrir URL específica da tarefa
        if [ ! -z "$URL_RESULTANTE" ] && [ "$URL_RESULTANTE" != "null" ]; then
            TODAS_URLS+=("$URL_RESULTANTE")
        fi

        sleep 1
    done

    # Adicionar URLs gerais
    URLS_GERAIS_ARR=()
    while IFS= read -r URL; do
        if [ ! -z "$URL" ] && [ "$URL" != "null" ]; then
            URLS_GERAIS_ARR+=("$URL")
        fi
    done < <(echo "$PERFIL_JSON" | jq -r '.urls_gerais[]? // empty')

    # Adicionar URLs gerais à lista
    for URL in "${URLS_GERAIS_ARR[@]}"; do
        TODAS_URLS+=("$URL")
    done

    # Abrir todas as URLs no navegador
    if [ ${#TODAS_URLS[@]} -gt 0 ]; then
        sleep 3
        echo "Abrindo URLs no navegador..."
        for URL in "${TODAS_URLS[@]}"; do
            # Verificar se é uma URL válida
            if [[ "$URL" =~ ^https?:// ]] || [[ "$URL" =~ ^www\. ]] || [[ -f "$URL" ]]; then
                $NAVEGADOR "$URL" &
                sleep 1
            else
                echo "URL inválida ignorada: $URL"
            fi
        done
    fi

    echo "Ambiente '$PERFIL_SELECIONADO' iniciado!"
}

# -------------------------------
# FUNÇÃO: CADASTRAR PERFIL
# -------------------------------
cadastrar_perfil() {

    if ! command -v dialog &> /dev/null || ! command -v jq &> /dev/null; then
        echo "ERRO: 'dialog' e 'jq' são necessários."
        exit 1
    fi

    [ -f "$CONFIG_FILE" ] || echo '{"perfis":[]}' > "$CONFIG_FILE"

    NOME_PERFIL=$(dialog --stdout --inputbox "Digite um nome para o novo perfil:" 8 60)
    [ -z "$NOME_PERFIL" ] && exit 0

    TAREFAS_JSON="[]"

    while true; do
        dialog --yesno "Adicionar nova tarefa?" 8 50
        [ $? -ne 0 ] && break

        DIRETORIO=$(dialog --stdout --inputbox "Diretório de trabalho:" 8 60 "$HOME")
        APP=$(dialog --stdout --inputbox "Aplicativo (ex: code, firefox, terminal):" 8 60)
        COMANDO=$(dialog --stdout --inputbox "Comando para executar (opcional):" 8 60)
        URL_RESULTANTE=$(dialog --stdout --inputbox "URL para abrir após o comando (opcional):" 8 60)

        TAREFA_ATUAL=$(jq -n \
            --arg dir "$DIRETORIO" \
            --arg app "$APP" \
            --arg cmd "$COMANDO" \
            --arg url "$URL_RESULTANTE" \
            '{diretorio:$dir, app:$app, comando:$cmd, url_resultante:$url}')

        TAREFAS_JSON=$(echo "$TAREFAS_JSON" | jq ". += [$TAREFA_ATUAL]")
    done

    # Adicionar URLs gerais
    URLS_GERAIS="[]"
    while true; do
        dialog --yesno "Adicionar URL geral?" 8 50
        [ $? -ne 0 ] && break
        
        URL=$(dialog --stdout --inputbox "URL geral (ex: https://exemplo.com):" 8 60)
        if [ ! -z "$URL" ]; then
            URLS_GERAIS=$(echo "$URLS_GERAIS" | jq ". + [\"$URL\"]")
        fi
    done

    NOVO_PERFIL=$(jq -n \
        --arg nome "$NOME_PERFIL" \
        --argjson tarefas "$TAREFAS_JSON" \
        --argjson urls "$URLS_GERAIS" \
        '{nome:$nome, tarefas:$tarefas, urls_gerais:$urls}')

    jq --argjson novo "$NOVO_PERFIL" '
        .perfis = [.perfis[] | select(.nome != $novo.nome)] + [$novo]
    ' "$CONFIG_FILE" > tmp.$$.json && mv tmp.$$.json "$CONFIG_FILE"

    dialog --msgbox "Perfil cadastrado com sucesso!" 6 40
}

# -------------------------------
# FUNÇÃO: LISTAR PERFIS
# -------------------------------
listar_perfis() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Nenhum perfil cadastrado."
        exit 1
    fi
    
    echo "Perfis cadastrados:"
    jq -r '.perfis[].nome' "$CONFIG_FILE" | nl
}

# -------------------------------
# FUNÇÃO: REMOVER PERFIL
# -------------------------------
remover_perfil() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Nenhum perfil cadastrado."
        exit 1
    fi
    
    NOMES_PERFIS=$(jq -r '.perfis[].nome' "$CONFIG_FILE")
    
    if [ -z "$NOMES_PERFIS" ]; then
        echo "Nenhum perfil para remover."
        exit 1
    fi
    
    PERFIL_REMOVER=$(dialog --stdout --menu "Escolha o perfil para remover:" 15 60 0 \
        $(jq -r '.perfis | to_entries[] | "\(.key+1) \(.value.nome)"' "$CONFIG_FILE"))
    
    if [ ! -z "$PERFIL_REMOVER" ]; then
        jq "del(.perfis[$((PERFIL_REMOVER-1))])" "$CONFIG_FILE" > tmp.$$.json && mv tmp.$$.json "$CONFIG_FILE"
        dialog --msgbox "Perfil removido com sucesso!" 6 40
    fi
}

# -------------------------------
# FUNÇÃO: TESTAR CONFIGURAÇÃO
# -------------------------------
testar_configuracao() {
    echo "Verificando dependências..."
    
    if ! command -v jq &> /dev/null; then
        echo "❌ jq não está instalado"
        echo "   Instale com: sudo apt install jq"
    else
        echo "✅ jq está instalado"
    fi
    
    if ! command -v dialog &> /dev/null; then
        echo "❌ dialog não está instalado"
        echo "   Instale com: sudo apt install dialog"
    else
        echo "✅ dialog está instalado"
    fi
    
    if ! command -v firefox &> /dev/null; then
        echo "⚠️ Firefox não encontrado. Você pode mudar a variável NAVEGADOR no script"
    else
        echo "✅ Firefox está instalado"
    fi
    
    if [ -f "$CONFIG_FILE" ]; then
        echo "✅ Arquivo de configuração encontrado"
    else
        echo "ℹ️ Arquivo de configuração será criado ao cadastrar um perfil"
    fi
}

# -------------------------------
# MENU PRINCIPAL
# -------------------------------
menu_principal() {
    if ! command -v dialog &> /dev/null; then
        echo "ERRO: 'dialog' é necessário para o menu interativo"
        exit 1
    fi
    
    ESCOLHA=$(dialog --stdout --menu "Gerenciador de Perfis" 15 60 0 \
        1 "Iniciar ambiente" \
        2 "Cadastrar novo perfil" \
        3 "Listar perfis" \
        4 "Remover perfil" \
        5 "Testar configuração" \
        6 "Sair")
    
    case "$ESCOLHA" in
        1) iniciar_ambiente ;;
        2) cadastrar_perfil ;;
        3) listar_perfis ;;
        4) remover_perfil ;;
        5) testar_configuracao ;;
        6) exit 0 ;;
        *) exit 0 ;;
    esac
}

# -------------------------------
# CONTROLE DE ARGUMENTOS
# -------------------------------
case "$1" in
    --cadastrar)
        cadastrar_perfil
        ;;
    --iniciar)
        iniciar_ambiente
        ;;
    --listar)
        listar_perfis
        ;;
    --remover)
        remover_perfil
        ;;
    --testar)
        testar_configuracao
        ;;
    --menu)
        menu_principal
        ;;
    *)
        echo "Gerenciador de Perfis de Desenvolvimento"
        echo ""
        echo "Uso:"
        echo "./gerenciador_perfis.sh [opção]"
        echo ""
        echo "Opções:"
        echo "  --cadastrar   Cadastrar um novo perfil"
        echo "  --iniciar     Iniciar um perfil existente"
        echo "  --listar      Listar perfis cadastrados"
        echo "  --remover     Remover um perfil"
        echo "  --testar      Testar configuração do sistema"
        echo "  --menu        Abrir menu interativo"
        echo "  (sem opção)   Mostrar esta ajuda"
        ;;
esac
