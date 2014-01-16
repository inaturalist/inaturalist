if [ "$TRAVIS" != "true" ]; then
    echo "This script should only be run under Travis"
    exit 1
fi
