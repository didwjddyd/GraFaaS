#!/bin/bash

# OpenFaaS Gateway URL
GATEWAY_URL="http://127.0.0.1:8080"

# Loop through each function
echo "Fetching function details from OpenFaaS..."
FUNCTIONS=$(curl -u admin:ghks7120 -s "$GATEWAY_URL/system/functions")

# Check if curl was successful
if [ $? -ne 0 ]; then
    echo "Error fetching functions from OpenFaaS."
    exit 1
fi

# Output the fetched functions for debugging
echo "Fetched functions: $FUNCTIONS"

# Check if the response is empty
if [ -z "$FUNCTIONS" ]; then
    echo "No functions found or empty response."
    exit 1
fi

# Loop through each function
for row in $(echo "$FUNCTIONS" | jq -r '.[] | @base64'); do
    _jq() {
        echo ${row} | base64 --decode | jq -r ${1}
    }

    FUNCTION_NAME=$(_jq '.name')
    # FPROCESS는 제공된 JSON에 없으므로 주석 처리
    # FPROCESS=$(_jq '.fprocess')

    echo "Function: $FUNCTION_NAME"

    # Get the container ID for the function
    CONTAINER_ID=$(docker ps -q -f "name=$FUNCTION_NAME")
    
    # Check if the container is running
    if [ -z "$CONTAINER_ID" ]; then
        echo "No running container found for function $FUNCTION_NAME."
        continue
    fi

    # Get the PID of the container
    PID=$(docker inspect --format '{{ .State.Pid }}' "$CONTAINER_ID")

    if [ -z "$PID" ]; then
        echo "No PID found for container $CONTAINER_ID."
        continue
    fi

    # Set the output file for strace
    OUTPUT_FILE="${FUNCTION_NAME}_strace_output.log"
    
    echo "Attaching strace to PID: $PID"

    # Run strace on the PID of the function's container
    strace -ttt -q -o "$OUTPUT_FILE" -p "$PID" &

    # Print the PID of the strace command
    echo "strace is running for $FUNCTION_NAME with PID: $!"

done

# Wait for all strace commands to finish
wait
echo "Strace completed. Output saved to individual log files."
    fi

    # Get the PID of the container
    PID=$(docker inspect --format '{{ .State.Pid }}' "$CONTAINER_ID")

    if [ -z "$PID" ]; then
        echo "No PID found for container $CONTAINER_ID."
        continue
    fi

    # Set the output file for strace
    OUTPUT_FILE="${FUNCTION_NAME}_strace_output.log"
    
    echo "Attaching strace to PID: $PID"

    # Run strace on the PID of the function's container
    strace -ttt -q -o "$OUTPUT_FILE" -p "$PID" &

    # Print the PID of the strace command
    echo "strace is running for $FUNCTION_NAME with PID: $!"

done

# Wait for all strace commands to finish
wait
echo "Strace completed. Output saved to individual log files."

