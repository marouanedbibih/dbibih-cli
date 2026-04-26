#!/bin/bash

DOCKERFILE_TEMPLATES_DIR="/usr/local/bin/templates/docker"

SUBCOMMAND=$1
TECHNOLOGY=$2
PROJECT_NAME=$3

# Function to initialize a Dockerfile
init_dockerfile() {
    # Validate inputs
    if [[ -z "$TECHNOLOGY" || -z "$PROJECT_NAME" ]]; then
        echo "Usage: dbibih init dockerfile <technology> <project-name>"
        echo "Example: dbibih init dockerfile reactjs web"
        exit 1
    fi

    # Construct the template path
    TEMPLATE_FILE="$DOCKERFILE_TEMPLATES_DIR/Dockerfile.$TECHNOLOGY"

    # Check if the template exists
    if [[ ! -f "$TEMPLATE_FILE" ]]; then
        echo "Error: No template found for technology '$TECHNOLOGY'."
        exit 1
    fi

    # Ensure the "docker" folder exists
    DOCKER_FOLDER="./docker"
    if [[ ! -d "$DOCKER_FOLDER" ]]; then
        echo "📁 'docker' folder does not exist. Creating it now..."
        mkdir -p "$DOCKER_FOLDER"
        echo "✅ 'docker' folder created."
    fi

    # Destination Dockerfile
    DEST_FILE="$DOCKER_FOLDER/Dockerfile.$PROJECT_NAME"

    # Copy the template to the destination file
    cp "$TEMPLATE_FILE" "$DEST_FILE"

    echo "✅ Dockerfile for '$TECHNOLOGY' ($PROJECT_NAME) created: $DEST_FILE"
}

# Main command dispatcher
case "$SUBCOMMAND" in
    init)
        init_dockerfile
        ;;
    *)
        echo "Usage: dbibih dockerfile init <technology> <project-name>"
        ;;
esac