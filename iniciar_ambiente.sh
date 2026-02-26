```bash
#!/bin/bash

# ===============================
# Script: iniciar_ambiente.sh
# Descrição: Inicia ambientes de trabalho conforme perfis cadastrados, abrindo terminais, navegadores e aplicativos.
# ===============================

# --- Ajuda/Help ---
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo -e "\nUSO: ./iniciar_ambiente.sh [opções]\n"
    echo "Este script inicializa ambientes de desenvolvimento conforme perfis cadastrados."
    echo "\nPASSOS PARA FUNCIONAR:"
    echo "1. Cadastre pelo menos um perfil rodando: ./cadastrar_perfil.sh"
    echo "2. Execute este script para iniciar o ambiente."
    echo "3. (Opcional) Para iniciar automaticamente com o sistema, crie um arquivo .desktop em ~/.config/autostart. Veja modelo no README."
    echo "\nO script irá:"
    echo "- Abrir terminais em diretórios e executar comandos."
    echo "- Abrir URLs no navegador Firefox."
    echo "- Abrir aplicativos (ex: VSCode) se configurado na tarefa."
    echo -e "\nOpções:\n  -h, --help    Mostra esta mensagem de ajuda.\n"
    exit 0
fi

# --- Variáveis Globais ---
CONFIG_FILE="$HOME/.dev_profiles.json"
NAVEGADOR="firefox"

# --- Verificação de Existência do Arquivo de Perfis ---
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Configuração não encontrada. Cadastre um perfil antes de iniciar."
    exit 1
fi

# --- Seleção do Perfil ---
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

# --- Execução das Tarefas do Perfil ---
# Para cada tarefa: abre terminal, executa comando, abre app se configurado, coleta URLs
TODAS_URLS=()
NUM_TAREFAS=$(echo "$PERFIL_JSON" | jq '.tarefas | length')
for (( I=0; I<NUM_TAREFAS; I++ )); do
    DIRETORIO=$(echo "$PERFIL_JSON" | jq -r ".tarefas[$I].diretorio")
    COMANDO=$(echo "$PERFIL_JSON" | jq -r ".tarefas[$I].comando")
    URL_RESULTANTE=$(echo "$PERFIL_JSON" | jq -r ".tarefas[$I].url_resultante")
    ABRIR_APP=$(echo "$PERFIL_JSON" | jq -r ".tarefas[$I].abrir_app")

    WORK_DIR="${DIRETORIO:-$HOME}"
    COMANDO_FINAL="cd \"$WORK_DIR\" && echo 'Executando no diretório: $WORK_DIR' && $COMANDO; exec bash"

    # Abre terminal
    if [ -z "$COMANDO" ]; then
        gnome-terminal --working-directory="$WORK_DIR" &
    else
        gnome-terminal -- bash -c "$COMANDO_FINAL" &
    fi

    # Abre aplicativo, se configurado
    if [ ! -z "$ABRIR_APP" ]; then
        (cd "$WORK_DIR" && eval "$ABRIR_APP" &)
    fi

    # Coleta URL resultante
    if [ ! -z "$URL_RESULTANTE" ]; then
        TODAS_URLS+=("$URL_RESULTANTE")
    fi
    sleep 1
done

# --- Coleta URLs Gerais ---
mapfile -t URLS_GERAIS_ARR < <(echo "$PERFIL_JSON" | jq -r '.urls_gerais[]')
for URL in "${URLS_GERAIS_ARR[@]}"; do
    [ ! -z "$URL" ] && TODAS_URLS+=("$URL")
done

# --- Abre todas as URLs no Firefox ---
if [ ${#TODAS_URLS[@]} -gt 0 ]; then
    echo "Aguardando 5 segundos para os servidores iniciarem..."
    sleep 5
    echo "Abrindo ${#TODAS_URLS[@]} URLs no Firefox: ${TODAS_URLS[*]}"
    $NAVEGADOR "${TODAS_URLS[@]}" &
fi

echo "Ambiente '$PERFIL_SELECIONADO' iniciado!"
```
