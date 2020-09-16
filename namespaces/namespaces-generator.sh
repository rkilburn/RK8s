cat namespaces-to-create.txt | while read namespace_name 
do
  if [[ -z  $namespace_name  ]] 
  then 
    continue
  else
    cat namespace.yaml.template | sed "s/NAMESPACE_NAME/$namespace_name/" > namespace-$namespace_name.yaml
    echo $namespace_name >> namespaces-created.txt
  fi
done

echo "" > namespaces-to-create.txt