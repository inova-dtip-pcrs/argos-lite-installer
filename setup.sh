#!/bin/bash
set -e
trap 'echo "❌ Erro na execução. Abortando setup."; exit 1' ERR

# --- Funções utilitárias ---

# Atualiza variável no arquivo .env
update_env_var() {
    local var_name="$1"
    local new_value="$2"
    local env_file="$HOME/argos_lite/.env"

    if [ ! -f "$env_file" ]; then
        echo "Erro: Arquivo $env_file não encontrado."
        return 1
    fi

    # Escapa barras verticais e trata espaços
    new_value="${new_value//|/\\|}"
    [[ "$new_value" == *" "* ]] && new_value="'$new_value'"

    if grep -q "^${var_name}=" "$env_file"; then
        sed -i "s|^${var_name}=.*|${var_name}=${new_value}|" "$env_file"
        echo "Variável $var_name atualizada para: $new_value"
    else
        echo "Variável $var_name não encontrada no arquivo $env_file."
        return 1
    fi
}

# Função para configurar os dados do estado
configurar_estado() {
    local sigla="$1"
    if [[ -z "${estados[$sigla]}" ]]; then
        echo "Erro: Sigla '$sigla' não encontrada na base de dados."
        return 1
    fi

    IFS='|' read -r -a dados <<< "${estados[$sigla]}"
    update_env_var "ESTADO" "${dados[0]}"
    update_env_var "estado_extenso" "'${dados[1]}'"
    update_env_var "capital_estado" "'${dados[2]}'"
    update_env_var "dominio_email" "${dados[3]}"
    update_env_var "brasao_site" "${dados[4]}"
    update_env_var "brasao_oficio" "${dados[5]}"
    update_env_var "header_estado_oficio" "'${dados[6]}'"

    echo "✅ Configuração do estado '${dados[1]}' aplicada com sucesso!"
}

# Função para validar recursos do sistema
validar_recursos() {
    echo "🔍 Validando recursos do sistema..."
    
    # Verificar RAM (mínimo 4GB)
    local ram_mb=$(free -m | awk '/Mem:/ {print $2}')
    if [ "$ram_mb" -lt 3900 ]; then
        echo "⚠️  AVISO: RAM insuficiente - Encontrado: ${ram_mb}MB, Mínimo recomendado: 4GB"
        read -p "Continuar mesmo assim? (s/n): " continuar
        if [ "$continuar" != "s" ]; then
            exit 1
        fi
    else
        echo "✅ RAM: ${ram_mb}MB"
    fi

    # Verificar espaço em disco (mínimo 20GB)
    local disco_kb=$(df / --output=avail | tail -1)
    local disco_gb=$((disco_kb / 1024 / 1024))
    if [ "$disco_gb" -lt 19 ]; then
        echo "⚠️  AVISO: Espaço em disco insuficiente - Encontrado: ${disco_gb}GB, Mínimo: 20GB"
        read -p "Continuar mesmo assim? (s/n): " continuar
        if [ "$continuar" != "s" ]; then
            exit 1
        fi
    else
        echo "✅ Espaço em disco: ${disco_gb}GB"
    fi

    # Verificar Ubuntu 24.04
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        if [ "$VERSION_ID" != "24.04" ]; then
            echo "⚠️  AVISO: Sistema testado no Ubuntu 24.04. Versão detectada: $VERSION_ID"
            read -p "Continuar mesmo assim? (s/n): " continuar
            if [ "$continuar" != "s" ]; then
                exit 1
            fi
        else
            echo "✅ Ubuntu $VERSION_ID"
        fi
    fi
}

# --- Validação inicial ---
validar_recursos

# Verificar comandos essenciais
for cmd in curl git gpg python3; do
    if ! command -v $cmd >/dev/null 2>&1; then
        echo "📦 Instalando $cmd..."
        sudo apt-get update
        sudo apt-get install -y $cmd
    fi
done

# --- Tabela de estados ---
declare -A estados=(
   # Formato: "SIGLA|estado_extenso|capital_estado|dominio_email|brasao_site|brasao_oficio|header_estado_oficio"
   ["AC"]="AC|Acre|Rio Branco|policiacivil.ac.gov.br|brasao_AC.png|logo_oficio_AC.png|Estado do Acre"
   ["AL"]="AL|Alagoas|Maceió|pc.al.gov.br|brasao_AL.png|logo_oficio_AL.png|Estado de Alagoas"
   ["AP"]="AP|Amapá|Macapá|policiacivil.ap.gov.br|brasao_AP.png|logo_oficio_AP.png|Estado do Amapá"
   ["AM"]="AM|Amazonas|Manaus|policiacivil.am.gov.br|brasao_AM.png|logo_oficio_AM.png|Estado do Amazonas"
   ["BA"]="BA|Bahia|Salvador|pc.ba.gov.br|brasao_BA.png|logo_oficio_BA.png|Estado da Bahia"
   ["CE"]="CE|Ceará|Fortaleza|policiacivil.ce.gov.br|brasao_CE.png|logo_oficio_CE.png|Estado do Ceará"
   ["DF"]="DF|Distrito Federal|Brasília|pcdf.df.gov.br|brasao_DF.png|logo_oficio_DF.png|Distrito Federal"
   ["ES"]="ES|Espírito Santo|Vitória|pc.es.gov.br|brasao_ES.png|logo_oficio_ES.png|Estado do Espírito Santo"
   ["GO"]="GO|Goiás|Goiânia|policiacivil.go.gov.br|brasao_GO.png|logo_oficio_GO.png|Estado de Goiás"
   ["MA"]="MA|Maranhão|São Luís|pc.ma.gov.br|brasao_MA.png|logo_oficio_MA.png|Estado do Maranhão"
   ["MT"]="MT|Mato Grosso|Cuiabá|policiacivil.mt.gov.br|brasao_MT.png|logo_oficio_MT.png|Estado de Mato Grosso"
   ["MS"]="MS|Mato Grosso do Sul|Campo Grande|pc.ms.gov.br|brasao_MS.png|logo_oficio_MS.png|Estado de Mato Grosso do Sul"
   ["MG"]="MG|Minas Gerais|Belo Horizonte|pc.mg.gov.br|brasao_MG.png|logo_oficio_MG.png|Estado de Minas Gerais"
   ["PA"]="PA|Pará|Belém|policiacivil.pa.gov.br|brasao_PA.png|logo_oficio_PA.png|Estado do Pará"
   ["PB"]="PB|Paraíba|João Pessoa|pc.pb.gov.br|brasao_PB.png|logo_oficio_PB.png|Estado da Paraíba"
   ["PR"]="PR|Paraná|Curitiba|pc.pr.gov.br|brasao_PR.png|logo_oficio_PR.png|Estado do Paraná"
   ["PE"]="PE|Pernambuco|Recife|policiacivil.pe.gov.br|brasao_PE.png|logo_oficio_PE.png|Estado de Pernambuco"
   ["PI"]="PI|Piauí|Teresina|pc.pi.gov.br|brasao_PI.png|logo_oficio_PI.png|Estado do Piauí"
   ["RJ"]="RJ|Rio de Janeiro|Rio de Janeiro|pcivil.rj.gov.br|brasao_RJ.png|logo_oficio_RJ.png|Estado do Rio de Janeiro"
   ["RN"]="RN|Rio Grande do Norte|Natal|policiacivil.rn.gov.br|brasao_RN.png|logo_oficio_RN.png|Estado do Rio Grande do Norte"
   ["RO"]="RO|Rondônia|Porto Velho|pc.ro.gov.br|brasao_RO.png|logo_oficio_RO.png|Estado de Rondônia"
   ["RR"]="RR|Roraima|Boa Vista|policiacivil.rr.gov.br|brasao_RR.png|logo_oficio_RR.png|Estado de Roraima"
   ["RS"]="RS|Rio Grande do Sul|Porto Alegre|pc.rs.gov.br|brasao_RS.png|logo_oficio_RS.png|Estado do Rio Grande do Sul"
   ["SC"]="SC|Santa Catarina|Florianópolis|pc.sc.gov.br|brasao_SC.png|logo_oficio_SC.png|Estado de Santa Catarina"
   ["SP"]="SP|São Paulo|São Paulo|policiacivil.sp.gov.br|brasao_SP.png|logo_oficio_SP.png|Estado de São Paulo"
   ["SE"]="SE|Sergipe|Aracaju|pc.se.gov.br|brasao_SE.png|logo_oficio_SE.png|Estado de Sergipe"
   ["TO"]="TO|Tocantins|Palmas|ssp.to.gov.br|brasao_TO.png|logo_oficio_TO.png|Estado do Tocantins"
)

# --- Execução principal ---
main() {
    echo "🚀 Iniciando instalação do ARGOS Lite..."

    # --- Docker ---
    echo "🔍 Verificando instalação do Docker..."
    docker_needs_install=false

    if command -v docker &> /dev/null; then
        echo "✅ Docker encontrado."

        if snap list 2>/dev/null | grep -q "^docker"; then
            echo "⚠️  Docker via SNAP detectado — removendo..."
            sudo snap remove docker || true
            docker_needs_install=true
        elif ! dpkg -l | grep -q "docker-ce"; then
            echo "⚠️  Docker instalado manualmente — reinstalando via APT."
            sudo apt-get remove -y docker docker.io podman-docker containerd runc || true
            docker_needs_install=true
        fi
    else
        echo "❌ Docker não encontrado — instalando..."
        docker_needs_install=true
    fi

    if ! docker compose version &>/dev/null; then
        echo "⚠️  docker compose não encontrado — instalando plugin."
        docker_needs_install=true
    fi

    if [ "$docker_needs_install" = true ]; then
        echo "📦 Instalando Docker via APT..."
        sudo apt-get update
        sudo apt-get install -y ca-certificates curl pass gnupg2
        sudo install -m 0755 -d /etc/apt/keyrings
        sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
        sudo chmod a+r /etc/apt/keyrings/docker.asc

        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
        https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo \"${UBUNTU_CODENAME:-$VERSION_CODENAME}\") stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        sudo usermod -aG docker $USER
        echo "⚠️  Execute 'newgrp docker' ou faça logout/login para aplicar as alterações do grupo docker."
    else
        echo "✅ Docker já instalado corretamente."
    fi

    # --- Configuração do pass / GPG ---
    if pass ls &>/dev/null; then
        echo "✅ 'pass' já configurado."
    else
        echo "🔧 Configurando 'pass'..."
        gpg --batch --gen-key <<EOF
Key-Type: RSA
Key-Length: 4096
Name-Real: Argos lite
Expire-Date: 0
%no-protection
%commit
EOF
        keyid=$(gpg --list-keys --with-colons | awk -F: '/^pub:/ {print $5; exit}')
        pass init "$keyid"
    fi

    mkdir -p ~/.docker
    echo '{ "credsStore": "pass" }' > ~/.docker/config.json
    echo 'export GPG_TTY=$(tty)' >> ~/.bashrc
    export GPG_TTY=$(tty)
    gpgconf --launch gpg-agent

    # --- SSH ---
    if [ -f "$HOME/.ssh/id_ed25519" ]; then
        echo "✅ Chave SSH existente."
    else
        echo "🔧 Gerando chave SSH..."
        ssh-keygen -t ed25519 -C "Argos Lite" -f ~/.ssh/id_ed25519 -N "" <<< y >/dev/null 2>&1
    fi

    # Adicionar GitHub ao known_hosts automaticamente
    echo "🔧 Adicionando GitHub ao known_hosts..."
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null
    chmod 600 ~/.ssh/known_hosts

    if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
        echo "✅ Autenticação SSH já configurada."
    else
        echo "🔑 Adicione a chave abaixo ao GitHub (https://github.com/settings/keys):"
        cat ~/.ssh/id_ed25519.pub
        echo ""
        echo "⚠️  Aguarde a configuração da chave SSH no GitHub..."
        while true; do
            read -p "Pressione Enter para testar conexão SSH após adicionar a chave..." -n 1
            echo ""
            if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
                echo "✅ Conexão SSH com GitHub estabelecida!"
                break
            else
                echo "❌ Falha na autenticação — verifique se a chave foi adicionada corretamente."
                echo "Deseja tentar novamente? (s/n): "
                read -n 1 tentar_novamente
                echo ""
                if [ "$tentar_novamente" != "s" ]; then
                    echo "⚠️  Continuando sem confirmação SSH. Certifique-se de configurar manualmente."
                    break
                fi
            fi
        done
    fi

    # --- Clone do projeto ---
    if [ -d "$HOME/argos_lite" ]; then
        echo "✅ Repositório 'argos_lite' já clonado."
    else
        echo "📦 Clonando repositório..."
        git clone git@github.com:inova-dtip-pcrs/argos_lite.git "$HOME/argos_lite"
    fi

    # --- Configurar docker-credential-pass ANTES do login ---
    echo "🔧 Configurando docker-credential-pass..."
    chmod +x "$HOME/argos_lite/run.sh" "$HOME/argos_lite/redist/docker-credential-pass"

    # Adicionar ao PATH temporariamente para esta sessão
    export PATH="$HOME/argos_lite/redist:$PATH"

    # Adicionar ao PATH permanentemente no .bashrc
    if ! grep -q "argos_lite/redist" ~/.bashrc; then
        echo 'export PATH="$HOME/argos_lite/redist:$PATH"' >> ~/.bashrc
        echo "✅ PATH atualizado no .bashrc"
    fi

    # Verificar se o docker-credential-pass está acessível
    if command -v docker-credential-pass &> /dev/null; then
        echo "✅ docker-credential-pass configurado corretamente"
    else
        echo "⚠️  Aviso: docker-credential-pass não encontrado no PATH"
        echo "💡 Usando caminho absoluto como fallback..."
    fi

    # --- Configuração do GitHub Container Registry ---
    echo "🔑 Configuração do GitHub Container Registry"
    if docker-credential-pass list 2>/dev/null | grep -q '"ghcr.io"'; then
        echo "✅ Já autenticado no GHCR."
    else
        echo "📝 Para acessar as imagens Docker, é necessário um token GitHub com permissão 'read:packages'"
        echo "📖 Como obter: GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)"
        echo ""
        read -p "Digite seu token GitHub (ghp_...): " github_token
        if [ -n "$github_token" ]; then
            # Garantir que o PATH está configurado para esta sessão
            export PATH="$HOME/argos_lite/redist:$PATH"
            
            echo "$github_token" | docker login ghcr.io -u USERNAME --password-stdin
            if [ $? -eq 0 ]; then
                echo "✅ Login no GHCR realizado com sucesso!"
            else
                echo "❌ Falha no login no GHCR. Verifique:"
                echo "   - O token está correto e tem permissão 'read:packages'"
                echo "   - Conexão com a internet"
                echo "   - Execute manualmente depois: docker login ghcr.io"
                exit 1
            fi
        else
            echo "❌ Token não fornecido. Não será possível baixar as imagens."
            exit 1
        fi
    fi

    # --- Teste containers ---
    cd "$HOME/argos_lite"
    echo "📥 Baixando imagens Docker..."

    # Verificar se o usuário tem permissão no Docker
    if ! docker info >/dev/null 2>&1; then
        echo "⚠️  Permissão do Docker não detectada. Tentando executar com permissões temporárias..."
        
        # Executa o pull com sg (similar ao newgrp mas não-interativo)
        if command -v sg &> /dev/null; then
            sg docker -c "cd '$HOME/argos_lite' && docker compose pull" || {
                echo "❌ Falha no pull. Adicione seu usuário ao grupo docker:"
                echo "   sudo usermod -aG docker $USER"
                echo "   Depois faça logout/login e execute novamente"
                exit 1
            }
        else
            echo "❌ É necessário ter permissão para usar o Docker. Execute:"
            echo "   sudo usermod -aG docker $USER"
            echo "   Depois faça logout/login e execute novamente: $HOME/setup.sh"
            exit 1
        fi
    else
        docker compose pull || { 
            echo "❌ Falha no pull das imagens. Verifique:"; 
            echo "   - Conexão com a internet";
            echo "   - Login no GHCR: docker login ghcr.io";
            exit 1; 
        }
    fi
    echo "✅ Imagens Docker baixadas com sucesso!"

    # --- Serviço systemd ---
    if systemctl list-unit-files | grep -q "^argos-lite.service"; then
        echo "✅ Serviço 'argos-lite' já existe."
    else
        echo "⚙️  Criando serviço 'argos-lite'..."
        sed "s|{{HOME}}|$HOME|g" "$HOME/argos_lite/redist/argos-lite.service" | \
        sudo tee /etc/systemd/system/argos-lite.service > /dev/null
        sudo systemctl daemon-reload
        sudo systemctl enable argos-lite
    fi

    if systemctl is-active --quiet argos-lite; then
        echo "✅ Serviço 'argos-lite' já em execução."
    else
        echo "▶️  Iniciando serviço 'argos-lite'..."
        sudo systemctl start argos-lite
    fi

    # --- Configuração do .env ---
    if [ ! -f "$HOME/argos_lite/.env" ]; then
        echo "⚠️  Arquivo .env não encontrado — algumas configurações podem faltar."
    else
        SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_hex(32))")
        update_env_var "SECRET_KEY" "$SECRET_KEY"

        read -p "Digite a sigla da UF (ex: RS, SP, RJ): " uf_sigla
        uf_sigla=$(echo "$uf_sigla" | tr '[:lower:]' '[:upper:]')
        configurar_estado "$uf_sigla"

        echo "Digite o nome do setor responsável pela instalação do Argos. Ex: 'Divisão de Inovação'"
        read -p "Setor: " setor_ti
        echo "Digite o e-mail do setor responsável pela instalação do Argos. Ex: 'dtip-inovacao@pc.rs.gov.br'"
        read -p "E-mail: " email_ti
        update_env_var "email_ti" "$email_ti"
        update_env_var "setor_ti" "$setor_ti"

        IMPORT_TOKEN=$(python3 -c "import secrets; print(secrets.token_hex(32))")
        update_env_var "IMPORT_TOKEN" "$IMPORT_TOKEN"
    fi

    # --- Cron para atualizações ---
    (crontab -l 2>/dev/null; echo "0 2 * * * $HOME/argos_lite/run.sh") | crontab -

    # --- Resumo final ---
    ip_address=$(hostname -I | awk '{print $1}')

    echo ""
    echo "🎉 Instalação e verificação concluídas!"
    echo "---------------------------------------------"
    echo "📦 Serviço: argos-lite"
    echo "🌐 Endereço local: http://localhost"
    echo "🌐 Endereço de rede: http://${ip_address:-desconhecido}"
    echo "📁 Diretório: $HOME/argos_lite"
    echo "---------------------------------------------"
    echo "💡 Dica: use 'sudo systemctl status argos-lite' para monitorar o serviço."
    echo ""
    echo "⚠️  IMPORTANTE: Execute 'newgrp docker' ou faça logout/login para aplicar as alterações do grupo docker."
}

main "$@"
