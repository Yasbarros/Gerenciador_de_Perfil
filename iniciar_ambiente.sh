
CONFIG_FILE="$HOME/.dev_profiles.json"
NAVEGADOR="firefox"

if [ ! -f "$CONFIG_FILE" ]; then echo "Configuração não encontrada."; exit 1; fi
mapfile -t nomes_perfis < <(jq -r '.perfis[].nome' "$CONFIG_FILE")
num_perfis=${#nomes_perfis[@]}
if [ "$num_perfis" -eq 0 ]; then echo "Nenhum perfil cadastrado."; exit 1; fi
if [ "$num_perfis" -eq 1 ]; then
    perfil_selecionado="${nomes_perfis[0]}"
else
    menu_opts=()
    for i in "${!nomes_perfis[@]}"; do menu_opts+=("$((i+1))" "${nomes_perfis[$i]}"); done
    escolha=$(dialog --stdout --menu "Escolha o perfil para iniciar:" 15 60 0 "${menu_opts[@]}")
    [ -z "$escolha" ] && exit 0
    perfil_selecionado="${nomes_perfis[$((escolha-1))]}"
fi

echo "Iniciando ambiente para o perfil: $perfil_selecionado"
perfil_json=$(jq ".perfis[] | select(.nome==\"$perfil_selecionado\")" "$CONFIG_FILE")

todas_urls=()

num_tarefas=$(echo "$perfil_json" | jq '.tarefas | length')
for (( i=0; i<num_tarefas; i++ )); do
    diretorio=$(echo "$perfil_json" | jq -r ".tarefas[$i].diretorio")
    comando=$(echo "$perfil_json" | jq -r ".tarefas[$i].comando")
    url_resultante=$(echo "$perfil_json" | jq -r ".tarefas[$i].url_resultante")

    work_dir="${diretorio:-$HOME}"

    comando_final="cd \"$work_dir\" && echo 'Executando no diretório: $work_dir' && $comando; exec bash"

    if [ -z "$comando" ]; then
        gnome-terminal --working-directory="$work_dir" &
    else
        gnome-terminal -- bash -c "$comando_final" &
    fi

    if [ ! -z "$url_resultante" ]; then
        todas_urls+=("$url_resultante")
    fi
    sleep 1
done

mapfile -t urls_gerais_arr < <(echo "$perfil_json" | jq -r '.urls_gerais[]')
for url in "${urls_gerais_arr[@]}"; do
    [ ! -z "$url" ] && todas_urls+=("$url")
done

if [ ${#todas_urls[@]} -gt 0 ]; then
    echo "Aguardando 5 segundos para os servidores iniciarem..."
    sleep 5
    echo "Abrindo ${#todas_urls[@]} URLs no Firefox: ${todas_urls[*]}"
    $NAVEGADOR "${todas_urls[@]}" &
fi

echo "Ambiente '$perfil_selecionado' iniciado!"
