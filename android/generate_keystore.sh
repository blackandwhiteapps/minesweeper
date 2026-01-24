#!/bin/bash

# Script to generate Android signing keystore
# Run this from the android directory

echo "Generating Android signing keystore..."
echo ""
echo "You will be prompted to enter:"
echo "  - Keystore password (save this securely!)"
echo "  - Key password (can be same as keystore password)"
echo "  - Your name and organization details"
echo ""
echo "Press Enter to continue..."
read

keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload

if [ $? -eq 0 ]; then
    echo ""
    echo "✓ Keystore generated successfully!"
    echo ""
    echo "Next steps:"
    echo "1. Copy key.properties.template to key.properties:"
    echo "   cp key.properties.template key.properties"
    echo ""
    echo "2. Edit key.properties and add your passwords"
    echo ""
    echo "3. Build your release:"
    echo "   flutter build appbundle --release"
else
    echo ""
    echo "✗ Keystore generation failed. Please try again."
    exit 1
fi

