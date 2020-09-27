kubectl label node rk8s-c1 --overwrite \
    node.kubernetes.io/instance-type=vm \
    topology.kubernetes.io/region=uk-south \
    topology.kubernetes.io/zone=uk-south-a \
    storage=ceph-a

kubectl label node rk8s-c2 --overwrite \
    node.kubernetes.io/instance-type=vm \
    topology.kubernetes.io/region=uk-south \
    topology.kubernetes.io/zone=uk-south-b \
    storage=ceph-a

kubectl label node rk8s-c3 --overwrite \
    node.kubernetes.io/instance-type=vm \
    topology.kubernetes.io/region=uk-south \
    topology.kubernetes.io/zone=uk-south-c \
    storage=ceph-a

kubectl label node rk8s-n1 --overwrite \
    node.kubernetes.io/instance-type=vm \
    topology.kubernetes.io/region=uk-south \
    topology.kubernetes.io/zone=uk-south-a \
    storage=ceph-a

kubectl label node rk8s-n2 --overwrite \
    node.kubernetes.io/instance-type=vm \
    topology.kubernetes.io/region=uk-south \
    topology.kubernetes.io/zone=uk-south-b \
    storage=ceph-a

kubectl label node rk8s-n3 --overwrite \
    node.kubernetes.io/instance-type=vm \
    topology.kubernetes.io/region=uk-south \
    topology.kubernetes.io/zone=uk-south-c \
    storage=ceph-a

