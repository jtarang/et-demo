rm -r manifests/*.yaml
rm .env

export TELEPORT_ADDRESS="nebula-dash.teleport.sh:443"
export TELEPORT_JOIN_TOKEN=$(tctl tokens add --type=node --format=text)
export ENVIRONMENT_TAG="local"

echo "TELEPORT_ADDRESS=${TELEPORT_ADDRESS}" >> .env
echo "TELEPORT_JOIN_TOKEN=${TELEPORT_JOIN_TOKEN}" >> .env
echo "ENVIRONMENT_TAG=${ENVIRONMENT_TAG}" >> .env


docker compose build

kompose convert -f docker-compose.yaml -o manifests
#docker compose up --build 
