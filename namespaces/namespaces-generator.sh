#!/bin/sh

# For line in file, check its not an empty string.
cat namespaces.txt | while read namespace_name || [[ -n $namespace_name ]];
do
  # If the namespace does not already exist 
  if [[ ! -f namespace-$namespace_name.yaml ]]
  then
    # Create the namespace definition
    cat namespace.yaml.template | sed "s/NAMESPACE_NAME/$namespace_name/" > namespace-$namespace_name.yaml
    echo "Created Namespace $namespace_name"
  fi
done