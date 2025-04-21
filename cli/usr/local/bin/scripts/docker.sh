#!/bin/bash
find_docker_files() {
    COMPOSE_FILES=$(find . -type f -name "docker-compose*.yml" 2>/dev/null)
    if [[ -z "$COMPOSE_FILES" ]]; then
        COMPOSE_FILES=$(find . -type f -name "compose*.yml" 2>/dev/null)
    fi

    DOCKERFILES=$(find . -type f -name "Dockerfile*" 2>/dev/null)
    if [[ -z "$DOCKERFILES" ]]; then
        DOCKERFILES=$(find . -type f -name "dockerfile*" 2>/dev/null)
    fi

    clear

    if [[ -n "$COMPOSE_FILES" ]]; then
        echo -e "\033[1;32m📦 Found Docker-Compose Files:\033[0m"
        echo -e "\033[1;37m──────────────────────────────────────────────────────\033[0m"
        echo "$COMPOSE_FILES" | tr ' ' '\n' | while read line; do
            echo -e "\033[1;33m$line\033[0m"
        done
        echo -e "\033[1;37m──────────────────────────────────────────────────────\033[0m"
    else
        echo -e "\033[1;31m🚫 No docker-compose files found.\033[0m"
    fi

    echo "" 

    if [[ -n "$DOCKERFILES" ]]; then
        echo -e "\033[1;32m🐳 Found Dockerfiles:\033[0m"
        echo -e "\033[1;37m──────────────────────────────────────────────────────\033[0m"
        echo "$DOCKERFILES" | tr ' ' '\n' | while read line; do
            echo -e "\033[1;33m$line\033[0m"
        done
        echo -e "\033[1;37m──────────────────────────────────────────────────────\033[0m"
    else
        echo -e "\033[1;31m🚫 No Dockerfiles found.\033[0m"
    fi
}


run_docker_infra() {
    COMPOSE_FILE=$(find . -type f -name "docker-compose.yml" 2>/dev/null)

    if [[ -z "$COMPOSE_FILE" ]]; then
        COMPOSE_FILE=$(find . -type f -name "compose.yml" 2>/dev/null)
    fi

    if [[ -n "$COMPOSE_FILE" ]]; then
        echo -e "\033[1;32m🚀 Running Docker Infrastructure:\033[0m"
        echo -e "\033[1;37m──────────────────────────────────────────────────────\033[0m"
        echo -e "\033[1;33m📄 File: $COMPOSE_FILE\033[0m"
        echo ""

        echo -e "\033[1;34m🧹 → Pruning old containers...\033[0m"
        docker compose -f "$COMPOSE_FILE" down --remove-orphans

        echo -e "\033[1;34m🔧 → Building and starting services...\033[0m"
        docker compose -f "$COMPOSE_FILE" up --build

        echo -e "\033[1;37m──────────────────────────────────────────────────────\033[0m"
    else
        echo -e "\033[1;31m🚫 No docker-compose.yml or compose.yml found to run.\033[0m"
    fi
}

run_docker_infra() {
    COMPOSE_FILE=$(find . -type f -name "docker-compose.yml" 2>/dev/null)

    if [[ -z "$COMPOSE_FILE" ]]; then
        COMPOSE_FILE=$(find . -type f -name "compose.yml" 2>/dev/null)
    fi

    if [[ -n "$COMPOSE_FILE" ]]; then
        echo -e "\033[1;32m🚀 Running Docker Infrastructure:\033[0m"
        echo -e "\033[1;37m──────────────────────────────────────────────────────\033[0m"
        echo -e "\033[1;33m📄 File: $COMPOSE_FILE\033[0m"
        echo ""

        echo -e "\033[1;34m🧹 → Pruning old containers...\033[0m"
        docker compose -f "$COMPOSE_FILE" down --remove-orphans

        echo -e "\033[1;34m🔧 → Building and starting services...\033[0m"
        docker compose -f "$COMPOSE_FILE" up --build

        echo -e "\033[1;37m──────────────────────────────────────────────────────\033[0m"
    else
        echo -e "\033[1;31m🚫 No docker-compose.yml or compose.yml found to run.\033[0m"
    fi
}

run_docker_dev() {
    # Find environment variables
    ENV_FILE=$(find . -type f -name ".env.dev" 2>/dev/null)
    # Find the infrastructure compose file
    COMPOSE_FILE_INFRA=$(find . -type f \( -name "docker-compose.yml" -o -name "compose.yml" \) | head -n 1 2>/dev/null)

    # Find the development compose file
    COMPOSE_FILE_DEV=$(find . -type f \( -name "docker-compose.dev.yml" -o -name "compose.dev.yml" \) | head -n 1 2>/dev/null)

    # Check if both compose files exist
    if [[ -z "$COMPOSE_FILE_INFRA" ]]; then
        echo -e "\033[1;31m🚫 No docker-compose.yml or compose.yml found for infrastructure.\033[0m"
        return 1
    fi

    if [[ -z "$COMPOSE_FILE_DEV" ]]; then
        echo -e "\033[1;31m🚫 No docker-compose.dev.yml or compose.dev.yml found for development.\033[0m"
        return 1
    fi

    # Display the files being used
    echo -e "\033[1;32m🚀 Running Docker Development Environment:\033[0m"
    echo -e "\033[1;37m──────────────────────────────────────────────────────\033[0m"
    echo -e "\033[1;33m📄 Infrastructure File: $COMPOSE_FILE_INFRA\033[0m"
    echo -e "\033[1;33m📄 Development File: $COMPOSE_FILE_DEV\033[0m"
    echo ""

    # Prune old containers
    echo -e "\033[1;34m🧹 → Pruning old containers...\033[0m"
    docker compose -f "$COMPOSE_FILE_INFRA" -f "$COMPOSE_FILE_DEV" down --remove-orphans

    # Build and start services
    echo -e "\033[1;34m🔧 → Building and starting services...\033[0m"
    docker compose -f "$COMPOSE_FILE_INFRA" -f "$COMPOSE_FILE_DEV" --env-file "$ENV_FILE" up --build

    echo -e "\033[1;37m──────────────────────────────────────────────────────\033[0m"
}



case $1 in
find)
    find_docker_files
    ;;
run)
    case $2 in
    infra)
        run_docker_infra
        ;;
    dev)
        run_docker_dev
        ;;
    *)
        echo -e "\033[1;31m❌ Invalid argument for 'docker run'. Use 'infra'.\033[0m"
        exit 1
        ;;
    esac
    ;;
*)
    echo -e "\033[1;33m📖 Usage: dbibih docker {find}|{run}\033[0m"
    exit 1
    ;;
esac