#!/bin/bash

function revisar_jq () {
    if ! command -v jq > /dev/null; then
        echo "jq no fue encontrado. Si desea continuar instale jq con el siguiente comando:"
        echo "sudo apt install jq"
        exit 1
    fi
}

function mostrar_ayuda () {
    echo
    echo "Nombre del script: Ejercicio5.sh"
    echo "Descripción: Script para consultar información relacionada a la serie Rick and Morty desde la API https://rickandmortyapi.com/."
    echo "Modo de uso: ./ejercicio5.sh [OPCIONES] [VALORES]"
    echo "Opciones:"
    echo "-h, --help                  Muestra este mensaje de ayuda y sale."
    echo "-i, --id ID1,ID2,...        Busca personajes por su ID. Se pueden proporcionar múltiples IDs separados por comas. El formato del ID debe ser un número entero."
    echo "-n, --name "Nombre1","Nombre2",...   Busca personajes por su nombre. Se pueden proporcionar múltiples nombres separados por comas. El formato del nombre debe comenzar con una palabra y puede contener más palabras separadas por espacios."
    echo
    echo "Ejemplos de uso:"
    echo "./rick_and_morty.sh -i 1,2,3                Busca personajes por sus IDs 1, 2 y 3."
    echo "./rick_and_morty.sh -n \"Rick Sanchez\",\"Morty Smith\"    Busca personajes por sus nombres "Rick Sanchez" y "Morty Smith"."
    echo "./rick_and_morty.sh -i 1 -n \"Morty Smith\",\"Beth Smith\"  Busca personajes por su ID 1 y nombres "Morty Smith" y "Adjudicator Rick"."
    echo
    echo "Notas:"
    echo "- Al buscar por nombre, el resultado será una lista de personajes."
    echo "- Si se proporcionan tanto IDs como nombres, se imprimira la búsqueda combinada."
}

function parsear_argumentos () {
    if [[ "$#" == 0 ]]; then
        echo "No se pasaron los argumentos necesarios. Por favor use -h o --help para ver el modo de uso."
        exit 1
    elif [[ "$#" > 4 ]]; then
        echo "Se pasaron argumentos demas. Por favor use -h o --help para ver el modo de uso."
        exit 1
    fi

    options=$(getopt -o i:n:h --l help,id:,nombre: -- "$@" 2> /dev/null)

    if [ "$?" != "0" ]; then
        echo 'Opcion invalida. Intente -h o --help para ver mas informacion.'
        exit 1
    fi

    local readonly DELIMITADOR=","
    local FLAG="false";

    eval set -- "$options"
    while true; do
        case "$1" in
            -i | --id)
                if [[ -z "$2" || "$2" == -* ]]; then
                    echo "Error falta el argumento para la opcion "$1""
                    exit 1;
                fi
                IFS="$DELIMITADOR" read -r -a ids_array <<< "$2"
                FLAG="true";
                shift 2
                ;;
            -n | --nombre)
                if [[ -z "$2" || "$2" == -* ]]; then
                    echo "Error falta el argumento para la opcion "$1""
                    exit 1;
                fi
                nombres=$(echo "$2")
                IFS="$DELIMITADOR" read -r -a nombres_array <<< "$nombres"
                FLAG="true";
                shift 2
                ;;
            -h | --help)
                mostrar_ayuda
                FLAG="true";
                exit 0
                ;;
            --)
                shift
                break
                ;;
            *)
                echo "Argumentos invalidos. Intente -h o --help para ver mas informacion."
                exit 1
                ;;
        esac
    done

    if [[ "$FLAG" != "true" ]]; then
        echo "No se ingreso ningun argumento. Intente -h o --help para ver mas informacion."
        exit 1
    fi
}

function inicializar_cache() {
    if [[ ! -f $CACHE ]]; then
        echo "{\"personajes\": [],\"idsPorNombre\": {}}" > $CACHE
    fi
}

function mostrar_personajes() {
    for personaje in "${!personajes[@]}"; do
        echo "$personaje"
    done
}

function guardar_personaje_en_array () {
    personaje=$(jq '{id, name, status, species, gender, origin: .origin.name, location: .location.name}' <<< "$1")
    personaje="${personaje//[\{\}\",]/}" #elimina los caracteres '{' '}' ',' '"'
    personajes[$personaje]=1
}

function descargar_informacion_por_id () {
    local query="$API_URL/${1}"
    local respuesta=$(wget --server-response -qO- "$query" 2>&1)
    local codigo_estado=$(echo "$respuesta" | awk '/^  HTTP/{print $2}')

    if [[ "$codigo_estado" = "200" ]]; then
        respuesta=$(echo "$respuesta" | awk '/^{/,/^}$/' | jq)  #awk '/^{/,/^}$/' elimina el encabezado de https
        archivo=$(jq --argjson pers "$respuesta" '.personajes += [$pers] | .' <<< "$archivo")
        guardar_personaje_en_array "$respuesta"
    else
        echo "ERROR: $codigo_estado. Verifique su conexion a internet o el id:\"${1}\""
    fi
}

function descargar_informacion_por_nombre () {
    local query="$API_URL/?name=${1}"
    local key="$1"


    while true; do
        local respuesta=$(wget --server-response -qO- "$query" 2>&1)
        local codigo_estado=$(echo "$respuesta" | awk '/^  HTTP/{print $2}')

        if [[ "$codigo_estado" = "200" ]]; then
            local next_info=$(echo "$respuesta" | awk '/^{/,/^}$/') #awk '/^{/,/^}$/' elimina el encabezado de http
            local proxima_pagina=$(jq -r '.info.next' <<< "$next_info")
            respuesta=$(echo "$respuesta" | awk '/^{/,/^}$/' | jq '.results')   
            local ids_a_agregar=$(echo "$respuesta" | jq -c '[.[].id]')
            archivo=$(jq --arg key "$key" --argjson ids "$ids_a_agregar" '.idsPorNombre[$key] += $ids' <<< "$archivo")

            for id in $(echo "$ids_a_agregar" | jq -r '.[]'); do
                local busqueda=$(jq --argjson id "$id" '.personajes[] | select(.id == $id) | {id, name, status, species, gender, origin: .origin.name, location: .location.name}'<<<"$archivo")

                if [[ -z "$busqueda" ]]; then
                    personaje=$(jq --argjson id "$id" '.[] | select(.id == $id)' <<< "$respuesta")
                    archivo=$(jq --argjson pers "$personaje" '.personajes += [$pers] | .' <<< "$archivo")
                    guardar_personaje_en_array "$personaje"
                else
                    personaje="${busqueda//[\{\}\",]/}"
                    personajes[$personaje]=1
                fi
            done
        	
            if [[ "$proxima_pagina" != "null" ]]; then
                query="$proxima_pagina"
            else
                break
            fi
        else
            echo "ERROR: $codigo_estado. Verifique su conexion a internet o el nombre:\"${1}\""
            break
        fi
    done
}

function buscar_personaje_por_nombre () {
    local nombre="$1"
    local nombre_a_buscar="\"${nombre}\""
    local personaje=$(jq '.idsPorNombre.'"$nombre_a_buscar"'' <<< "$archivo")

    if [[ "$personaje" != "null" ]]; then
        for pers in $(echo "$personaje" | jq -c '.[]'); do
            local perso=$(jq --argjson pers "$pers" '.personajes[] | select(.id == $pers) | {id, name, status, species, gender, origin: .origin.name, location: .location.name}'<<<"$archivo")
            perso="${perso//[\{\}\",]/}"
            personajes[$perso]=1
        done
    else
        descargar_informacion_por_nombre "$nombre"
    fi
}

function buscar_personaje_por_id () {
    local id_a_buscar="$1"
    local personaje=$(jq --argjson id "$id_a_buscar" '.personajes[] | select(.id == $id) | {id, name, status, species, gender, origin: .origin.name, location: .location.name}'<<<"$archivo")

    if [[ -n "$personaje" ]]; then
        personaje="${personaje//[\{\}\",]/}"
        personajes[$personaje]=1
    else
        descargar_informacion_por_id "$id_a_buscar"
    fi
}

function procesar_ids_y_nombres() {
    local id nombre
    for id in "${ids_array[@]}"; do
        if [[ "$id" =~ ^[0-9]+$ ]]; then
            buscar_personaje_por_id "$id"
        else
            echo "ERROR. El ID: \"${id}\" no es valido. Tiene que ser un numero. Por favor, asegúrate de que el id tiene el formato correcto. Intente -h o --help para ver mas informacion."
        fi
    done

    for nombre in "${nombres_array[@]}"; do
        if [[ "$nombre" =~ ^[[:alpha:]]+( [[:alpha:]]+)*$ ]]; then
            buscar_personaje_por_nombre "$nombre"
        else
            echo "ERROR. El NOMBRE: \"${nombre}\" no es valido. Debe comenzar con una palabra y puede contener más palabras separadas por espacios. Por favor, asegúrate de que el nombre esté formateado correctamente. Intente -h o --help para ver mas informacion."
        fi
    done
}

function main () {
    local readonly API_URL="https://rickandmortyapi.com/api/character"
    declare -A personajes
    local readonly CACHE="personajes.json"

    revisar_jq
    parsear_argumentos "$@"
    inicializar_cache
    local archivo=$(cat "$CACHE")
    procesar_ids_y_nombres
    echo "$archivo" > "$CACHE"
    mostrar_personajes
}

main "$@"