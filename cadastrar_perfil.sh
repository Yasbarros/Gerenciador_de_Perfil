#!/bin/bash

# --- Verificação de Argumentos (HELP via Dialog) ---
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    # Verifica se o dialog está instalado antes de tentar abrir
    if command -v dialog &> /dev/null; then
        dialog --title "Help - Gerenciador de Perfil" --msgbox \
"Script de Cadastro\n\n\
Descrição:\n\
Este script permite criar perfis de ambiente de desenvolvimento.\n\
As configurações são salvas em: ~/.dev_profiles.json 20 75 \n\n\
Primeira etapa: rode o ambiente de cadastro ./cadastrar_perfil.sh e siga as instruções para criar um perfil.\n\n\
Segunda etapa: para iniciar o ambiente, use ./iniciar_ambiente.sh e selecione o perfil criado. \n\n\
Terceira etapa: é necessário criar um arquivo .desktop no diretório apropriado do seu sistema operacional para carregar o ambiente automaticamente. Mais instruções podem ser encontradas na documentação (README)." 20 75
    else
        echo "Gerenciador de Perfil - Script de Cadastro"
        echo "Uso: ./cadastrar_perfil.sh --help"
        echo "Nota: Instale o 'dialog' para ver esta ajuda em modo gráfico."
    fi
    exit 0
fi

# --- Verificação de Dependências ---
if ! command -v dialog &> /dev/null || ! command -v jq &> /dev/null; then
    echo "ERRO: 'dialog' e 'jq' são necessários."
    echo "Instale-os com: sudo apt-get install dialog jq"
    exit 1
fi

CONFIG_FILE="$HOME/.dev_profiles.json"
[ -f "$CONFIG_FILE" ] || echo '{"perfis":[]}' > "$CONFIG_FILE"

# --- Início do Cadastro do Perfil ---
NOME_PERFIL=$(dialog --stdout --inputbox "Digite um nome para o novo perfil (ex: Projeto_Backend):" 8 60)
[ -z "$NOME_PERFIL" ] && exit 0

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
clear
