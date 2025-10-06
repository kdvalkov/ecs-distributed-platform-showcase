#!/bin/bash

cat <<'EOF' >> /etc/ecs/ecs.config
ECS_CLUSTER=${cluster_name}
ECS_LOGLEVEL=debug
ECS_CONTAINER_INSTANCE_TAGS=${container_instance_tags}
ECS_ENABLE_TASK_IAM_ROLE=true
EOF
