# Gerente_de_Perfil

## Como usar o Gerenciador de Perfil

### 1. Cadastro de Perfis e Inicialização do Ambiente

Antes de iniciar, é necessário cadastrar pelo menos um perfil. Para isso, execute o script de cadastro:

```bash
chmod +x ./gerenciador_perfis.sh
./gerenciador_perfis.sh
```

Esse script irá solicitar:
- Nome do perfil
- Tarefas (diretório, comando, URL resultante, aplicativo para abrir o diretório)
- URLs gerais (Jira, GitHub, Gmail, etc.)
- Abrir terminais nos diretórios informados e rodar os comandos cadastrados
- Abrir aplicativos (ex: VSCode) se configurado na tarefa
- Abrir todas as URLs cadastradas no navegador Firefox

Você pode ver as opções de uso e ajuda rodando:

```bash
./iniciar_ambiente.sh --help
```

### 2. Inicialização Automática com o Sistema

Para que o ambiente seja iniciado automaticamente ao ligar o computador, é necessário criar um arquivo `.desktop` na pasta de autostart do seu sistema.

**Exemplo no Fedora Linux:**
`~/.config/autostart/iniciar-dev-env.desktop`

**Modelo:**
```ini
[Desktop Entry]
Type=Application
Name=Iniciar Ambiente de Desenvolvimento
Comment=Inicia os perfis de trabalho automaticamente
Exec=/caminho/para/seu/script/gerenciador_perfis.sh
Terminal=false
```

> Um modelo desse arquivo está disponível neste repositório.

**Importante:**
- Altere o caminho do `Exec` para o local correto do seu script.
- Certifique-se de que o script tem permissão de execução (`chmod +x gerenciador_perfis.sh`).
