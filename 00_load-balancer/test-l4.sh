echo "--- Hitting L4 LB 5x (watch server_name alternate)"

for i in 1 2 3 4 5; do
	curl -s http://localhost:8081/ | python3 -m json.tool
	echo
done
