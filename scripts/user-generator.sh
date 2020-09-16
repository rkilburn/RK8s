#!/bin/sh

# For line in file, check its not an empty string.
cat users/users.txt | while read user_name || [[ -n $user_name ]];
do
  # If the user does not already exist 
  if [[ ! -f users/user-$user_name.yaml ]]
  then
    # Create the user definition
    cat users/user.yaml.template | sed "s/USER_NAME/$user_name/" > users/user-$user_name.yaml
    echo "Created User $user_name"
  fi
done