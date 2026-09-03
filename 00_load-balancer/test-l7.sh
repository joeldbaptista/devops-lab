echo "--- L7 Path routing ---"
echo "-> /v1/api"
curl -s http://localhost:8082/v1/api | python3 -m json.tool
echo "-> /v2/api"
curl -s http://localhost:8082/v2/api | python3 -m json.tool
echo "-> /static"
curl -s http://localhost:8082/static | python3 -m json.tool
