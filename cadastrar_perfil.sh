#!/bin/bash

# --- Verificação de Dependências ---
if ! command -v dialog &> /dev/null || ! command -v jq &> /dev/null; then
    echo "ERRO: 'dialog' e 'jq' são necessários."
    echo "Instale-os com: sudo apt-get install dialog jq"
    exit 1
fi

CONFIG_FILE="$HOME/.dev_profiles.json"
[ -f "$CONFIG_FILE" ] || echo '{"perfis":[]}' > "$CONFIG_FILE"

# --- Início do Cadastro do Perfil ---
nome_perfil=$(dialog --stdout --inputbox "Digite um nome para o novo perfil (ex: Projeto_Backend):" 8 60)
[ -z "$nome_perfil" ] && exit 0

# --- Loop para Adicionar Tarefas ---
tarefas_json="[]"
while true; do
    dialog --yesno "Você deseja adicionar uma nova tarefa de inicialização para o perfil '$nome_perfil'?\n\n(Ex: abrir um projeto, rodar um comando, etc.)" 10 70
    if [ $? -ne 0 ]; then # Se o usuário escolher "Não"
        break
    fi

    # 1. Obter o diretório da tarefa
    diretorio=$(dialog --stdout --title "Tarefa: Diretório" --inputbox "Qual o diretório de trabalho para esta tarefa?\n(Deixe em branco se não for necessário)" 8 70)

    # 2. Obter o comando da tarefa
    comando=$(dialog --stdout --title "Tarefa: Comando" --inputbox "Qual comando deve ser executado neste diretório?\n(Deixe em branco para apenas abrir o terminal)" 8 70)

    # 3. Obter a URL resultante (opcional)
    url_resultante=""
    if [ ! -z "$comando" ]; then
        url_resultante=$(dialog --stdout --title "Tarefa: URL Resultante" --inputbox "Se o comando acima gera um link (ex: localhost), digite-o aqui para abrir no navegador:" 8 70)
    fi

    # Monta o objeto JSON para a tarefa atual
    tarefa_atual=$(jq -n \
        --arg dir "$diretorio" \
        --arg cmd "$comando" \
        --arg url "$url_resultante" \
        '{diretorio: $dir, comando: $cmd, url_resultante: $url}')

    # Adiciona a tarefa à lista de tarefas
    tarefas_json=$(echo "$tarefas_json" | jq ". += [$tarefa_atual]")
done

# --- Cadastro das URLs Gerais ---
urls_gerais=$(dialog --stdout --title "URLs Gerais" --inputbox "Agora, digite os endereços web gerais para este perfil (Jira, GitHub, etc.), separados por espaço:" 10 80)

# --- Montagem e Salvamento do Perfil ---
novo_perfil=$(jq -n \
    --arg nome "$nome_perfil" \
    --argjson tarefas "$tarefas_json" \
    --arg urls "$urls_gerais" \
    '{
        nome: $nome,
        tarefas: $tarefas,
        urls_gerais: ($urls | split(" "))
    }')

# Adiciona ou substitui o perfil no arquivo de configuração
# Remove perfil existente com o mesmo nome e adiciona o novo
jq --argjson novo "$novo_perfil" '
    .perfis = [.perfis[] | select(.nome != $novo.nome)] + [$novo]
' "$CONFIG_FILE" > tmp.$$.json && mv tmp.$$.json "$CONFIG_FILE"

dialog --msgbox "Perfil '$nome_perfil' cadastrado com sucesso!" 6 60
clear
