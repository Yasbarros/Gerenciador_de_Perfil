# Gerente_de_Perfil

## Como usar o Gerenciador de Perfil

### 1. Cadastro de Perfis

Antes de iniciar qualquer ambiente, é necessário cadastrar pelo menos um perfil. Para isso, execute o script de cadastro:

```bash
./cadastrar_perfil.sh
```

Esse script irá solicitar:
- Nome do perfil
- Tarefas (diretório, comando, URL resultante, aplicativo para abrir o diretório)
- URLs gerais (Jira, GitHub, Gmail, etc.)

### 2. Inicialização do Ambiente

Após cadastrar o perfil, execute o script de inicialização:

```bash
./iniciar_ambiente.sh
```

Esse script irá:
- Abrir terminais nos diretórios informados e rodar os comandos cadastrados
- Abrir aplicativos (ex: VSCode) se configurado na tarefa
- Abrir todas as URLs cadastradas no navegador Firefox

Você pode ver as opções de uso e ajuda rodando:

```bash
./iniciar_ambiente.sh --help
```

### 3. Inicialização Automática com o Sistema

Para que o ambiente seja iniciado automaticamente ao ligar o computador, é necessário criar um arquivo `.desktop` na pasta de autostart do seu sistema.

**Exemplo de arquivo:**  
`~/.config/autostart/iniciar-dev-env.desktop`

**Modelo:**
```ini
[Desktop Entry]
Type=Application
Name=Iniciar Ambiente de Desenvolvimento
Comment=Inicia os perfis de trabalho automaticamente
Exec=/caminho/para/seu/script/iniciar_ambiente.sh
Terminal=false
```

> Um modelo desse arquivo está disponível neste repositório.

**Importante:**
- Altere o caminho do `Exec` para o local correto do seu script.
- Certifique-se de que o script tem permissão de execução (`chmod +x iniciar_ambiente.sh`).
