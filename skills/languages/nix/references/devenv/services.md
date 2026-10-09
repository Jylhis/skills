# devenv Services Reference

Complete configuration reference for commonly used devenv services. Each service runs as a process under devenv's native process manager (devenv 2.x default), named after the service (`postgres`, `redis`, `mysql`, ...), so other processes and tasks can depend on `devenv:processes:<service>`.

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
  # No port option; pass mongod flags directly (default: [ "--noauth" ])
  additionalArgs = [ "--port" "27017" "--noauth" ];
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

Custom processes use `exec` for the command and native process-manager options for the rest (the `process-compose.*` attrset only applies with `process.manager.implementation = "process-compose"`):

```nix
processes.api = {
  exec = "./run-server.sh";
  env.PORT = "8080";          # was process-compose.environment
  cwd = "./backend";          # was process-compose.working_dir
  ready = {                   # was process-compose.readiness_probe
    http.get = {
      port = 8080;
      path = "/health";
    };
    initial_delay = 3;
    period = 5;
  };
  restart = {                 # was process-compose.availability
    on = "on_failure";
    max = 5;
  };
  shutdown.signal = 2;        # SIGINT; devenv 2.3+
};
```

Other readiness probes: `ready.exec = "pg_isready -d template1";` and `ready.notify = true;` (sd_notify `READY=1`). With allocated `ports` and no explicit probe, a TCP check is used.

## Service Dependency Ordering

Use `after` with `devenv:processes:<name>` to control startup order:

```nix
processes.api = {
  exec = "./run-api.sh";
  after = [
    "devenv:processes:postgres"
    "devenv:processes:redis"
  ];
};

processes.worker = {
  exec = "./run-worker.sh";
  after = [
    "devenv:processes:api"
    "devenv:processes:redis@started"
  ];
};
```

Dependency suffixes (and their process-compose equivalents):
- `@ready` (default) - readiness probe passes (`process_healthy`)
- `@started` - process has started (`process_started`)
- `@completed` - process exited, whatever the exit code (`process_completed`)
- `@succeeded` - task (or one-shot process) exited with code 0 (`process_completed_successfully`)

For one-off setup such as migrations, use a task with `after = [ "devenv:processes:postgres" ]` plus `wantedBy = [ "devenv:processes:postgres" ]` (2.4+) so it also runs under a plain `devenv up`.

## Port Configuration and Discovery

Service `port` options are base ports. The native manager allocates the first free port at or above the base, so two projects can run PostgreSQL at the same time. Read the allocated value from `config.processes.<name>.ports.<port>.value` (PostgreSQL, Redis and MySQL use the port name `main`) rather than hardcoding the number. PostgreSQL listens only on a unix socket unless `listen_addresses` is set, and only then allocates `ports.main`. Services also export their own variables, for example `PGPORT` for PostgreSQL; since 2.4 `devenv shell` and direnv see the port of the running service.

```nix
{ config, ... }: {
  services.postgres.port = 5432;   # base port
  services.redis.port = 6379;

  processes.api = {
    ports.http.allocate = 8080;
    exec = "python -m uvicorn app:main --port ${toString config.processes.api.ports.http.value}";
  };
}
```

To fail instead of moving to another port, set `strict_ports: true` in `devenv.yaml` or run `devenv up --strict-ports`.

## Environment Variables for Connection Strings

Define connection strings in `env` so all processes and shell sessions can access them:

```nix
{ config, ... }:
let
  pgPort = toString config.processes.postgres.ports.main.value;
  redisPort = toString config.processes.redis.ports.main.value;
in {
  services.postgres = {
    enable = true;
    listen_addresses = "127.0.0.1";  # TCP (and ports.main) only exist when set
    port = 5432;
    initialDatabases = [{ name = "myapp"; }];
  };

  services.redis = {
    enable = true;
    port = 6379;
  };

  env.DATABASE_URL = "postgres://localhost:${pgPort}/myapp";
  env.REDIS_URL = "redis://127.0.0.1:${redisPort}";
  env.MONGO_URL = "mongodb://127.0.0.1:27017/myapp";
  env.RABBITMQ_URL = "amqp://guest:guest@127.0.0.1:5672";
  env.ELASTICSEARCH_URL = "http://127.0.0.1:9200";
  env.MINIO_ENDPOINT = "http://127.0.0.1:9000";
  env.SMTP_HOST = "127.0.0.1";
  env.SMTP_PORT = "1025";
}
```

This keeps connection configuration in one place and avoids hardcoding URLs in application code.
