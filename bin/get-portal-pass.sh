#!/bin/bash
# Get the list of secrets
secrets=$(aws secretsmanager list-secrets --query 'SecretList[].Name' --output text)

# Loop over the secrets
for secret in $secrets; do
  # Get the value of the secret
  value=$(aws secretsmanager get-secret-value --secret-id $secret --query SecretString --output text)
  echo "Secret: $secret"
  echo "Value: $value"
  echo ""
done
