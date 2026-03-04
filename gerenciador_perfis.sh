#!/bin/bash

# --- Variáveis Globais ---
CONFIG_FILE="$HOME/.dev_profiles.json"
NAVEGADOR="firefox" # Pode ser configurado pelo usuário

# --- Função para verificar e instalar dependências universalmente ---
install_package() {
    local package_name=$1
    if ! command -v "$package_name" &> /dev/null; then
        echo "Verificando e instalando a dependência: $package_name..."
        if command -v apt-get &> /dev/null; then
            echo "Detectado gerenciador de pacotes: apt-get"
            sudo apt-get update -y
            sudo apt-get install -y "$package_name"
        elif command -v dnf &> /dev/null; then
            echo "Detectado gerenciador de pacotes: dnf"
            sudo dnf install -y "$package_name"
        elif command -v yum &> /dev/null; then
            echo "Detectado gerenciador de pacotes: yum"
            sudo yum install -y "$package_name"
        elif command -v pacman &> /dev/null; then
            echo "Detectado gerenciador de pacotes: pacman"
            sudo pacman -Sy --noconfirm "$package_name"
        elif command -v zypper &> /dev/null; then
            echo "Detectado gerenciador de pacotes: zypper"
            sudo zypper install -y "$package_name"
        elif command -v apk &> /dev/null; then
            echo "Detectado gerenciador de pacotes: apk"
            sudo apk add "$package_name"
        elif command -v brew &> /dev/null; then
            echo "Detectado gerenciador de pacotes: brew (macOS)"
            brew install "$package_name"
        else
            echo "ERRO: Nenhum gerenciador de pacotes compatível encontrado para instalar $package_name. Por favor, instale manualmente." >&2
            exit 1
        fi

        if [ $? -eq 0 ]; then
            echo "$package_name instalado com sucesso."
        else
            echo "ERRO: Falha ao instalar $package_name. Por favor, instale manualmente." >&2
            exit 1
        fi
    else
        echo "$package_name já está instalado."
    fi
}

# --- Verificação e Instalação de Dependências Essenciais ---
install_package "dialog"
install_package "jq"

# --- Inicializa o arquivo de configuração se não existir ---
[ -f "$CONFIG_FILE" ] || echo '{"perfis":[]}' > "$CONFIG_FILE"

# --- Função para Cadastrar um Novo Perfil ---
cadastrar_perfil() {
    NOME_PERFIL=$(dialog --stdout --inputbox "Digite um nome para o novo perfil (ex: Projeto_Backend):" 8 60)
    [ -z "$NOME_PERFIL" ] && return 1 # Retorna se o nome estiver vazio

    TAREFAS_JSON="[]"
    while true; do
        dialog --yesno "Você deseja adicionar uma nova tarefa de inicialização para o perfil '$NOME_PERFIL'?\n\n(Ex: abrir um projeto, rodar um comando, etc.)" 10 70
        if [ $? -ne 0 ]; then
            break
        fi

        DIRETORIO=$(dialog --stdout --title "Tarefa: Diretório" --inputbox "Qual o diretório de trabalho para esta tarefa?\n(Deixe em branco se não for necessário)" 8 70)

        APP_ESCOLHIDO=$(dialog --stdout --title "Escolha o Aplicativo" --menu "Como deseja abrir este diretório?" 15 60 5 \
            "terminal" "Apenas abrir o terminal" \
            "code" "Abrir com VS Code" \
            "cursor" "Abrir com Cursor" \
            "subl" "Abrir com Sublime Text" \
            "outro" "Outro comando customizado")

        if [ "$APP_ESCOLHIDO" == "outro" ]; then
            APP_COMANDO=$(dialog --stdout --title "Comando Customizado" --inputbox "Digite o comando para abrir o editor (ex: pycharm, atom):" 8 70)
        else
            APP_COMANDO=$APP_ESCOLHIDO
        fi

        COMANDO=$(dialog --stdout --title "Tarefa: Comando de Execução" --inputbox "Qual comando deve ser executado no terminal?\n(Ex: npm run dev, docker-compose up)\nDeixe em branco se não houver comando." 10 70)

        URL_RESULTANTE=""
        if [ ! -z "$COMANDO" ]; then
            URL_RESULTANTE=$(dialog --stdout --title "Tarefa: URL Resultante" --inputbox "Se o comando acima gera um link (ex: localhost), digite-o aqui para abrir no navegador:" 8 70)
        fi

        TAREFA_ATUAL=$(jq -n \
            --arg dir "$DIRETORIO" \
            --arg app "$APP_COMANDO" \
            --arg cmd "$COMANDO" \
            --arg url "$URL_RESULTANTE" \
            '{diretorio: $dir, app: $app, comando: $cmd, url_resultante: $url}')

        TAREFAS_JSON=$(echo "$TAREFAS_JSON" | jq ". += [$TAREFA_ATUAL]")
    done

    URLS_GERAIS=$(dialog --stdout --title "URLs Gerais" --inputbox "Agora, digite os endereços web gerais para este perfil (Jira, GitHub, etc.), separados por espaço:" 10 80)

    NOVO_PERFIL=$(jq -n \
        --arg nome "$NOME_PERFIL" \
        --argjson tarefas "$TAREFAS_JSON" \
        --arg urls "$URLS_GERAIS" \
        '{
            nome: $nome,
            tarefas: $tarefas,
            urls_gerais: ($urls | split(" "))
        }')

    jq --argjson novo "$NOVO_PERFIL" \
        '.perfis = [.perfis[] | select(.nome != $novo.nome)] + [$novo]' "$CONFIG_FILE" > tmp.$$.json && mv tmp.$$.json "$CONFIG_FILE"

    dialog --msgbox "Perfil '$NOME_PERFIL' cadastrado com sucesso!" 6 60
    clear
}

# --- Função para Iniciar um Perfil Existente ---
iniciar_perfil() {
    mapfile -t NOMES_PERFIS < <(jq -r '.perfis[].nome' "$CONFIG_FILE")
    NUM_PERFIS=${#NOMES_PERFIS[@]}

    if [ "$NUM_PERFIS" -eq 0 ]; then
        dialog --msgbox "Nenhum perfil cadastrado. Por favor, cadastre um perfil primeiro." 6 60
        return 1
    fi

    local PERFIL_SELECIONADO
    if [ "$NUM_PERFIS" -eq 1 ]; then
        PERFIL_SELECIONADO="${NOMES_PERFIS[0]}"
    else
        MENU_OPTS=()
        for I in "${!NOMES_PERFIS[@]}"; do MENU_OPTS+=("$((I+1))" "${NOMES_PERFIS[$I]}"); done
        ESCOLHA=$(dialog --stdout --menu "Escolha o perfil para iniciar:" 15 60 0 "${MENU_OPTS[@]}")
        [ -z "$ESCOLHA" ] && return 1 # Retorna se a escolha estiver vazia
        PERFIL_SELECIONADO="${NOMES_PERFIS[$((ESCOLHA-1))]}"
    fi

    dialog --msgbox "Iniciando ambiente para o perfil: $PERFIL_SELECIONADO" 6 60
    PERFIL_JSON=$(jq ".perfis[] | select(.nome==\"$PERFIL_SELECIONADO\")" "$CONFIG_FILE")

    TODAS_URLS=()

    NUM_TAREFAS=$(echo "$PERFIL_JSON" | jq '.tarefas | length')
    for (( I=0; I<NUM_TAREFAS; I++ )); do
        DIRETORIO=$(echo "$PERFIL_JSON" | jq -r ".tarefas[$I].diretorio")
        APP=$(echo "$PERFIL_JSON" | jq -r ".tarefas[$I].app")
        COMANDO=$(echo "$PERFIL_JSON" | jq -r ".tarefas[$I].comando")
        URL_RESULTANTE=$(echo "$PERFIL_JSON" | jq -r ".tarefas[$I].url_resultante")

        WORK_DIR="${DIRETORIO:-$HOME}"

        # 1. ABRIR O EDITOR/APP SELECIONADO
        if [ "$APP" != "terminal" ] && [ ! -z "$APP" ] && [ "$APP" != "null" ]; then
            echo "Abrindo $APP em $WORK_DIR..."
            (cd "$WORK_DIR" && $APP . ) &
        fi

        # 2. EXECUTAR O COMANDO NO TERMINAL
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
        dialog --msgbox "Aguardando 5 segundos para os servidores iniciarem e abrindo ${#TODAS_URLS[@]} URLs no $NAVEGADOR..." 8 70
        sleep 5
        $NAVEGADOR "${TODAS_URLS[@]}" &
    fi

    dialog --msgbox "Ambiente '$PERFIL_SELECIONADO' iniciado!" 6 60
    clear
}

# --- Loop Principal do Menu ---
while true; do
    CHOICE=$(dialog --stdout --title "Gerenciador de Perfis de Desenvolvimento" --menu "Escolha uma opção:" 15 60 3 \
        "1" "Iniciar Perfil Existente" \
        "2" "Cadastrar Novo Perfil" \
        "3" "Sair")

    case $CHOICE in
        1)
            iniciar_perfil
            ;;
        2)
            cadastrar_perfil
            ;;
        3)
            clear
            echo "Saindo do Gerenciador de Perfis."
            exit 0
            ;;
        *)
            clear
            echo "Nenhuma opção selecionada. Saindo."
            exit 0
            ;;
    esac
done
