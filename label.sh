kubectl label node rk-k8s-n1 \
    node.kubernetes.io/instance-type=b1ms \
    topology.kubernetes.io/region=uk-south \
    topology.kubernetes.io/zone=uk-south-a

kubectl label node rk-k8s-n2 \
    node.kubernetes.io/instance-type=b1ms \
    topology.kubernetes.io/region=uk-south \
    topology.kubernetes.io/zone=uk-south-b


kubectl label node rk-k8s-g1 \
    node.kubernetes.io/instance-type=n1 \
    topology.kubernetes.io/region=uk-south \
    topology.kubernetes.io/zone=uk-south-c \
    gpu=nvidia

