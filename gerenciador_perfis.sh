#!/bin/bash

# =============================================================================
# Gerenciador de Perfil - Script Unificado
# Descrição: Permite criar e iniciar perfis de ambiente de desenvolvimento.
# =============================================================================

CONFIG_FILE="$HOME/.dev_profiles.json"
NAVEGADOR="firefox"

# --- Verificação de Argumentos (HELP via Dialog) ---
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    if command -v dialog &> /dev/null; then
        dialog --title "Help - Gerenciador de Perfil" --msgbox \
"Script Unificado do Gerenciador de Perfil\n\n\
Descrição:\n\
Este script permite criar e iniciar perfis de ambiente de desenvolvimento.\n\
As configurações são salvas em: ~/.dev_profiles.json\n\n\
Uso:\n\
  ./gerenciadorPerfil.sh          Abre o menu principal\n\
  ./gerenciadorPerfil.sh --help   Exibe esta ajuda\n\n\
No menu principal você pode:\n\
  1. Cadastrar um novo perfil\n\
  2. Iniciar um perfil existente\n\
  3. Sair" 20 75
    else
        echo "Gerenciador de Perfil - Script Unificado"
        echo "Uso: ./gerenciadorPerfil.sh [--help]"
        echo "Nota: Instale o 'dialog' para ver esta ajuda em modo gráfico."
    fi
    exit 0
fi

# --- Verificação e Instalação de Dependências ---
DEPS_FALTANDO=()
command -v dialog &> /dev/null || DEPS_FALTANDO+=("dialog")
command -v jq &> /dev/null || DEPS_FALTANDO+=("jq")

if [ ${#DEPS_FALTANDO[@]} -gt 0 ]; then
    echo "Dependências não encontradas: ${DEPS_FALTANDO[*]}"
    echo "Tentando instalar automaticamente..."

    # Detecta o gerenciador de pacotes disponível
    if command -v apt-get &> /dev/null; then
        PKG_MANAGER="sudo apt-get install -y"
    elif command -v dnf &> /dev/null; then
        PKG_MANAGER="sudo dnf install -y"
    elif command -v yum &> /dev/null; then
        PKG_MANAGER="sudo yum install -y"
    elif command -v pacman &> /dev/null; then
        PKG_MANAGER="sudo pacman -S --noconfirm"
    elif command -v zypper &> /dev/null; then
        PKG_MANAGER="sudo zypper install -y"
    else
        echo "ERRO: Não foi possível detectar o gerenciador de pacotes."
        echo "Instale manualmente: ${DEPS_FALTANDO[*]}"
        exit 1
    fi

    echo "Usando: $PKG_MANAGER ${DEPS_FALTANDO[*]}"
    $PKG_MANAGER "${DEPS_FALTANDO[@]}"

    # Verifica se a instalação foi bem-sucedida
    for DEP in "${DEPS_FALTANDO[@]}"; do
        if ! command -v "$DEP" &> /dev/null; then
            echo "ERRO: Falha ao instalar '$DEP'. Instale manualmente e tente novamente."
            exit 1
        fi
    done

    echo "Dependências instaladas com sucesso!"
    sleep 1
fi

[ -f "$CONFIG_FILE" ] || echo '{"perfis":[]}' > "$CONFIG_FILE"

# =============================================================================
# FUNÇÃO: Cadastrar Perfil
# =============================================================================
cadastrar_perfil() {
    # --- Início do Cadastro do Perfil ---
    NOME_PERFIL=$(dialog --stdout --inputbox "Digite um nome para o novo perfil (ex: Projeto_Backend):" 8 60)
    [ -z "$NOME_PERFIL" ] && return

    # --- Loop para Adicionar Tarefas ---
    TAREFAS_JSON="[]"
    while true; do
        dialog --yesno "Você deseja adicionar uma nova tarefa de inicialização para o perfil '$NOME_PERFIL'?\n\n(Ex: abrir um projeto, rodar um comando, etc.)" 10 70
        if [ $? -ne 0 ]; then
            break
        fi

        # 1. Obter o diretório da tarefa
        DIRETORIO=$(dialog --stdout --title "Tarefa: Diretório" --inputbox "Qual o diretório de trabalho para esta tarefa?\n(Deixe em branco se não for necessário)" 8 70)

        # 2. ESCOLHA DO APLICATIVO/EDITOR
        APP_ESCOLHIDO=$(dialog --stdout --title "Escolha o Aplicativo" --menu "Como deseja abrir este diretório?" 15 60 5 \
            "terminal" "Apenas abrir o terminal" \
            "code" "Abrir com VS Code" \
            "cursor" "Abrir com Cursor" \
            "subl" "Abrir com Sublime Text" \
            "outro" "Outro comando customizado")

        # Se escolheu "outro", pergunta qual o comando
        if [ "$APP_ESCOLHIDO" == "outro" ]; then
            APP_COMANDO=$(dialog --stdout --title "Comando Customizado" --inputbox "Digite o comando para abrir o editor (ex: pycharm, atom):" 8 70)
        else
            APP_COMANDO=$APP_ESCOLHIDO
        fi

        # 3. Obter o comando de execução (ex: npm run dev)
        COMANDO=$(dialog --stdout --title "Tarefa: Comando de Execução" --inputbox "Qual comando deve ser executado no terminal?\n(Ex: npm run dev, docker-compose up)\nDeixe em branco se não houver comando." 10 70)

        # 4. Obter a URL resultante (opcional)
        URL_RESULTANTE=""
        if [ ! -z "$COMANDO" ]; then
            URL_RESULTANTE=$(dialog --stdout --title "Tarefa: URL Resultante" --inputbox "Se o comando acima gera um link (ex: localhost), digite-o aqui para abrir no navegador:" 8 70)
        fi

        # Monta o objeto JSON para a tarefa atual
        TAREFA_ATUAL=$(jq -n \
            --arg dir "$DIRETORIO" \
            --arg app "$APP_COMANDO" \
            --arg cmd "$COMANDO" \
            --arg url "$URL_RESULTANTE" \
            '{diretorio: $dir, app: $app, comando: $cmd, url_resultante: $url}')

        # Adiciona a tarefa à lista de tarefas
        TAREFAS_JSON=$(echo "$TAREFAS_JSON" | jq ". += [$TAREFA_ATUAL]")
    done

    # --- Cadastro das URLs Gerais ---
    URLS_GERAIS=$(dialog --stdout --title "URLs Gerais" --inputbox "Agora, digite os endereços web gerais para este perfil (Jira, GitHub, etc.), separados por espaço:" 10 80)

    # --- Montagem e Salvamento do Perfil ---
    NOVO_PERFIL=$(jq -n \
        --arg nome "$NOME_PERFIL" \
        --argjson tarefas "$TAREFAS_JSON" \
        --arg urls "$URLS_GERAIS" \
        '{
            nome: $nome,
            tarefas: $tarefas,
            urls_gerais: ($urls | split(" "))
        }')

    # Adiciona ou atualiza o perfil no arquivo de configuração
    jq --argjson novo "$NOVO_PERFIL" '
        .perfis = [.perfis[] | select(.nome != $novo.nome)] + [$novo]
    ' "$CONFIG_FILE" > tmp.$$.json && mv tmp.$$.json "$CONFIG_FILE"

    dialog --msgbox "Perfil '$NOME_PERFIL' cadastrado com sucesso!" 6 60
}

# =============================================================================
# FUNÇÃO: Iniciar Ambiente
# =============================================================================
iniciar_ambiente() {
    # --- Verificação e Seleção de Perfil ---
    if [ ! -f "$CONFIG_FILE" ]; then
        dialog --msgbox "Configuração não encontrada. Cadastre um perfil primeiro." 6 60
        return
    fi

    mapfile -t NOMES_PERFIS < <(jq -r '.perfis[].nome' "$CONFIG_FILE")
    NUM_PERFIS=${#NOMES_PERFIS[@]}

    if [ "$NUM_PERFIS" -eq 0 ]; then
        dialog --msgbox "Nenhum perfil cadastrado. Cadastre um perfil primeiro." 6 60
        return
    fi

    if [ "$NUM_PERFIS" -eq 1 ]; then
        PERFIL_SELECIONADO="${NOMES_PERFIS[0]}"
    else
        MENU_OPTS=()
        for I in "${!NOMES_PERFIS[@]}"; do MENU_OPTS+=("$((I+1))" "${NOMES_PERFIS[$I]}"); done
        ESCOLHA=$(dialog --stdout --menu "Escolha o perfil para iniciar:" 15 60 0 "${MENU_OPTS[@]}")
        [ -z "$ESCOLHA" ] && return
        PERFIL_SELECIONADO="${NOMES_PERFIS[$((ESCOLHA-1))]}"
    fi

    clear
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
            (cd "$WORK_DIR" && $APP . ) &
        fi

        # 2. EXECUTAR O COMANDO NO TERMINAL
        if [ ! -z "$COMANDO" ] && [ "$COMANDO" != "null" ]; then
            COMANDO_FINAL="cd \"$WORK_DIR\" && echo 'Executando: $COMANDO' && $COMANDO; exec bash"
            gnome-terminal -- bash -c "$COMANDO_FINAL" &
        else
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
}

# =============================================================================
# MENU PRINCIPAL
# =============================================================================
while true; do
    OPCAO=$(dialog --stdout --title "Gerenciador de Perfil" --menu \
        "Selecione uma opção:" 12 50 3 \
        1 "Cadastrar novo perfil" \
        2 "Iniciar ambiente" \
        3 "Sair")

    case $OPCAO in
        1) cadastrar_perfil ;;
        2) iniciar_ambiente ;;
        3|"") clear; exit 0 ;;
    esac
done
