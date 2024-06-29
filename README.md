# Rick and Morty

## Descripción

`rickandmorty.sh` es un script en Bash diseñado para consultar información sobre personajes de la serie **Rick and Morty** desde la API [Rick and Morty](https://rickandmortyapi.com/). Permite buscar personajes por sus IDs o nombres, con opciones para múltiples entradas.

## Requisitos

- **Bash** (4.0 o superior)
- **jq** (para procesar JSON)

### Instalación de `jq`

Si no tienes `jq` instalado, ejecuta:

```bash
sudo apt install jq
```

## Uso

Ejecuta el script con las siguientes opciones:

```bash
./rickandmorty.sh [OPCIONES] [VALORES]
```

### Opciones

- `-i`, `--id ID1,ID2,...`: Busca personajes por sus IDs (múltiples IDs separados por comas).
- `-n`, `--name "Nombre1","Nombre2",...`: Busca personajes por sus nombres (múltiples nombres separados por comas).
- `-h`, `--help`: Muestra el mensaje de ayuda y sale.

### Ejemplos

- Buscar por IDs:

  ```bash
  ./rickandmorty.sh -i 1,2,3
  ```

- Buscar por nombres:

  ```bash
  ./rickandmorty.sh -n "Rick Sanchez","Morty Smith"
  ```

- Buscar por ID y nombres:

  ```bash
  ./rickandmorty.sh -i 1 -n "Morty Smith","Beth Smith"
  ```

## Notas

- Al buscar por nombre, el resultado será una lista de personajes.
- Si se proporcionan tanto IDs como nombres, se imprimirá la búsqueda combinada.
- Los resultados se almacenan en un archivo de caché (`personajes.json`) para mejorar el rendimiento en búsquedas futuras.

## Autor

Este script fue desarrollado para practicar el uso de Bash y consumir APIs públicas.