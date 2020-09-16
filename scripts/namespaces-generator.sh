#!/bin/sh

# For line in file, check its not an empty string.
cat namespaces/namespaces.txt | while read namespace_name || [[ -n $namespace_name ]];
do
  # If the namespace does not already exist 
  if [[ ! -f namespaces/namespace-$namespace_name.yaml ]]
  then
    # Create the namespace definition
    cat namespaces/namespace.yaml.template | sed "s/NAMESPACE_NAME/$namespace_name/" > namespaces/namespace-$namespace_name.yaml
    echo "Created Namespace $namespace_name"
  fi
done