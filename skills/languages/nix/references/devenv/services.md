# devenv Services Reference

Complete configuration reference for commonly used devenv services.

## Table of Contents

- [PostgreSQL](#postgresql)
- [MySQL](#mysql)
- [Redis](#redis)
- [Elasticsearch](#elasticsearch)
- [MinIO](#minio)
- [RabbitMQ](#rabbitmq)
- [MongoDB](#mongodb)
- [Temporal](#temporal)
- [Nginx](#nginx)
- [Mailpit](#mailpit)
- [Process Configuration Patterns](#process-configuration-patterns)
- [Service Dependency Ordering](#service-dependency-ordering)
- [Port Configuration and Discovery](#port-configuration-and-discovery)
- [Environment Variables for Connection Strings](#environment-variables-for-connection-strings)

## PostgreSQL

```nix
services.postgres = {
  enable = true;
  listen_addresses = "127.0.0.1";
  port = 5432;
  initialDatabases = [
    { name = "myapp_dev"; }
    { name = "myapp_test"; }
  ];
  extensions = ext: [ ext.postgis ext.pgvector ];
  settings = {
    log_connections = true;
    log_statement = "all";
  };
};
```

## MySQL

```nix
services.mysql = {
  enable = true;
  initialDatabases = [
    { name = "myapp_dev"; }
  ];
  settings = {
    mysqld = {
      port = 3306;
      bind-address = "127.0.0.1";
      innodb_buffer_pool_size = "256M";
    };
  };
};
```

## Redis

```nix
services.redis = {
  enable = true;
  port = 6379;
  bind = "127.0.0.1";
};
```

## Elasticsearch

```nix
services.elasticsearch = {
  enable = true;
  port = 9200;
};
```

## MinIO

```nix
services.minio = {
  enable = true;
  buckets = [ "uploads" "backups" ];
  region = "us-east-1";
};
```

## RabbitMQ

```nix
services.rabbitmq = {
  enable = true;
  port = 5672;
  managementPlugin.enable = true;
  managementPlugin.port = 15672;
};
```

## MongoDB

```nix
services.mongodb = {
  enable = true;
  port = 27017;
};
```

## Temporal

```nix
services.temporal = {
  enable = true;
};
```

## Nginx

```nix
services.nginx = {
  enable = true;
  httpConfig = ''
    server {
      listen 8080;
      location / {
        proxy_pass http://127.0.0.1:3000;
      }
      location /api {
        proxy_pass http://127.0.0.1:4000;
      }
    }
  '';
};
```

## Mailpit

Email testing service that captures outgoing emails:

```nix
services.mailpit = {
  enable = true;
};
```

Mailpit provides a web UI for viewing captured emails and an SMTP server for sending. Configure your application to send mail through Mailpit's SMTP port.

## Process Configuration Patterns

Custom processes use `exec` for the command and `process-compose` for advanced options:

```nix
processes.api = {
  exec = "./run-server.sh";
  process-compose = {
    environment = [ "PORT=8080" ];
    working_dir = "./backend";
    log_location = "/tmp/api.log";
    readiness_probe = {
      http_get = {
        host = "127.0.0.1";
        port = 8080;
        path = "/health";
      };
      initial_delay_seconds = 3;
      period_seconds = 5;
    };
  };
};
```

## Service Dependency Ordering

Use `depends_on` with conditions to control startup order:

```nix
processes.api = {
  exec = "./run-api.sh";
  process-compose = {
    depends_on.postgres.condition = "process_healthy";
    depends_on.redis.condition = "process_healthy";
  };
};

processes.worker = {
  exec = "./run-worker.sh";
  process-compose = {
    depends_on.api.condition = "process_healthy";
    depends_on.redis.condition = "process_healthy";
  };
};
```

Available conditions:
- `process_started` - process has started (default)
- `process_healthy` - process readiness probe passes
- `process_completed_successfully` - process exited with code 0

## Port Configuration and Discovery

Use environment variables to coordinate ports between services and application code:

```nix
{ ... }: {
  env.PG_PORT = "5432";
  env.REDIS_PORT = "6379";
  env.API_PORT = "8080";

  services.postgres.port = 5432;
  services.redis.port = 6379;

  processes.api.exec = "python -m uvicorn app:main --port $API_PORT";
}
```

## Environment Variables for Connection Strings

Define connection strings in `env` so all processes and shell sessions can access them:

```nix
{ config, ... }: {
  services.postgres = {
    enable = true;
    port = 5432;
    initialDatabases = [{ name = "myapp"; }];
  };

  services.redis = {
    enable = true;
    port = 6379;
  };

  env.DATABASE_URL = "postgres://localhost:5432/myapp";
  env.REDIS_URL = "redis://127.0.0.1:6379";
  env.MONGO_URL = "mongodb://127.0.0.1:27017/myapp";
  env.RABBITMQ_URL = "amqp://guest:guest@127.0.0.1:5672";
  env.ELASTICSEARCH_URL = "http://127.0.0.1:9200";
  env.MINIO_ENDPOINT = "http://127.0.0.1:9000";
  env.SMTP_HOST = "127.0.0.1";
  env.SMTP_PORT = "1025";
}
```

This keeps connection configuration in one place and avoids hardcoding URLs in application code.
