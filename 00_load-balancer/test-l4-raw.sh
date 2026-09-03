echo "--- Sending raw non-HTTP payload to L4 LB (proves no HTTP parsing) ---"
printf "Hello there\n" | nc -w1 localhost 8081 || true
