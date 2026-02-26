```bash
#!/bin/bash

# ===============================
# Script: cadastrar_perfil.sh
# Descrição: Cadastra perfis de ambiente de desenvolvimento, incluindo tarefas, comandos, URLs e apps.
# ===============================

# --- Verificação de dependências ---
if ! command -v dialog &> /dev/null || ! command -v jq &> /dev/null; then
    echo "ERRO: 'dialog' e 'jq' são necessários."
    echo "Instale-os com: sudo apt-get install dialog jq"
    exit 1
fi

# --- Inicialização do arquivo de configuração ---
CONFIG_FILE="$HOME/.dev_profiles.json"
[ -f "$CONFIG_FILE" ] || echo '{"perfis":[]}' > "$CONFIG_FILE"

# --- Cadastro do nome do perfil ---
nome_perfil=$(dialog --stdout --inputbox "Digite um nome para o novo perfil (ex: Projeto_Backend):" 8 60)
[ -z "$nome_perfil" ] && exit 0

# --- Loop para cadastro de tarefas ---
tarefas_json="[]"
while true; do
    dialog --yesno "Você deseja adicionar uma nova tarefa de inicialização para o perfil '$nome_perfil'?\n\n(Ex: abrir um projeto, rodar um comando, etc.)" 10 70
    if [ $? -ne 0 ]; then
        break
    fi

    # --- Cadastro dos detalhes da tarefa ---
    diretorio=$(dialog --stdout --title "Tarefa: Diretório" --inputbox "Qual o diretório de trabalho para esta tarefa?\n(Deixe em branco se não for necessário)" 8 70)

    comando=$(dialog --stdout --title "Tarefa: Comando" --inputbox "Qual comando deve ser executado neste diretório?\n(Deixe em branco para apenas abrir o terminal)" 8 70)

    url_resultante=""
    if [ ! -z "$comando" ]; then
        url_resultante=$(dialog --stdout --title "Tarefa: URL Resultante" --inputbox "Se o comando acima gera um link (ex: localhost), digite-o aqui para abrir no navegador:" 8 70)
    fi

    # --- Pergunta se deve abrir o diretório em algum app ---
    abrir_app=""
    dialog --yesno "Você deseja abrir o diretório informado em algum aplicativo? (ex: VSCode, Nautilus, etc.)" 8 60
    if [ $? -eq 0 ]; then
        abrir_app=$(dialog --stdout --inputbox "Digite o comando para abrir o diretório (ex: code . ou nautilus .):" 8 60)
    fi

    # --- Monta o objeto da tarefa e adiciona ao array ---
    tarefa_atual=$(jq -n \
        --arg dir "$diretorio" \
        --arg cmd "$comando" \
        --arg url "$url_resultante" \
        --arg app "$abrir_app" \
        '{diretorio: $dir, comando: $cmd, url_resultante: $url, abrir_app: $app}')

    tarefas_json=$(echo "$tarefas_json" | jq ". += [$tarefa_atual]")
done

# --- Cadastro das URLs gerais do perfil ---
urls_gerais=$(dialog --stdout --title "URLs Gerais" --inputbox "Agora, digite os endereços web gerais para este perfil (Jira, GitHub, etc.), separados por espaço:" 10 80)

# --- Montagem do objeto do perfil e salvamento ---
novo_perfil=$(jq -n \
    --arg nome "$nome_perfil" \
    --argjson tarefas "$tarefas_json" \
    --arg urls "$urls_gerais" \
    '{
        nome: $nome,
        tarefas: $tarefas,
        urls_gerais: ($urls | split(" "))
    }')

# --- Atualiza o arquivo de configuração, substituindo perfil se já existir ---
jq --argjson novo "$novo_perfil" '
    .perfis = [.perfis[] | select(.nome != $novo.nome)] + [$novo]
' "$CONFIG_FILE" > tmp.$$.json && mv tmp.$$.json "$CONFIG_FILE"

dialog --msgbox "Perfil '$nome_perfil' cadastrado com sucesso!" 6 60
clear
```
