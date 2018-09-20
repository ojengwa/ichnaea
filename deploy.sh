#!/bin/bash
set -e


# First, let's make sure that Docker Compose has been installed.
if ! [ -x "$(command -v docker-compose)" ]; then
  echo "Please install Docker Compose and try again."
  exit 1
fi

# Let's do the important things.
case "$1" in

  # Pull (download) service and application images.
  build)

    case "$2" in

      # Pulls (downloads) the application container from the Docker Registry
      ichnaea)
        docker pull mozilla/location:latest;
        ;;

      # Pulls (downloads) the the custom mysql container from the Docker Registry
      mysql)
        docker pull mozilla/location_mysql:latest;
      ;;

      # Pulls (downloads) the the redis container from the Docker Registry
      redis)
        docker pull mozilla/location_redis:latest;
      ;;

    esac
    ;;

  # Builds and starts some/all of our containers.
  start)

    case "$2" in

      # Builds and starts the scheduler container.
      scheduler)
        SCHEDULER_ID="$(docker ps -a -q --filter name=location_scheduler)"
        if [ ! -z "$SCHEDULER_ID" ]; then
          $0 stop scheduler
        fi
        docker run -d \
          -e "REDIS_HOST=`docker inspect --format '{{ .NetworkSettings.IPAddress }}' location_redis`" \
          -e "DB_HOST=`docker inspect --format '{{ .NetworkSettings.IPAddress }}' location_mysql`" \
          -e "DB_USER=location" -e "DB_PWD=location" \
          --name="location_scheduler" mozilla/location scheduler
        ;;

      # Builds and starts the web container.
      web)
        WEB_ID="$(docker ps -a -q --filter name=location_web)"
        if [ ! -z "$WEB_ID" ]; then
          $0 stop web
        fi
        docker run -d \
          -e "REDIS_HOST=`docker inspect --format '{{ .NetworkSettings.IPAddress }}' location_redis`" \
          -e "DB_HOST=`docker inspect --format '{{ .NetworkSettings.IPAddress }}' location_mysql`" \
          -e "DB_USER=location" -e "DB_PWD=location" \
          -p 8000:8000/tcp --name="location_web" mozilla/location web
        ;;

      # Builds and starts the worker container.
      worker)
        WORKER_ID="$(docker ps -a -q --filter name=location_worker)"
        if [ ! -z "$WORKER_ID" ]; then
          $0 stop worker
        fi
        docker run -d \
          -e "REDIS_HOST=`docker inspect --format '{{ .NetworkSettings.IPAddress }}' location_redis`" \
          -e "DB_HOST=`docker inspect --format '{{ .NetworkSettings.IPAddress }}' location_mysql`" \
          -e "DB_USER=location" -e "DB_PWD=location" \
          --name="location_worker" mozilla/location worker
        ;;

      # Builds and starts the services supporting the application container.
      services)
        MYSQL_ID="$(docker ps -a -q --filter name=location_mysql)"
        if [ ! -z "$MYSQL_ID" ]; then
          $0 stop services
        fi
        docker run -d -p 3306:3306/tcp --name="location_mysql" \
          -e "MYSQL_ROOT_PASSWORD=location" -e "MYSQL_DATABASE=location" \
          -e "MYSQL_USER=location" -e "MYSQL_PASSWORD=location" mysql
        REDIS_ID="$(docker ps -a -q --filter name=location_redis)"
        if [ ! -z "$REDIS_ID" ]; then
          $0 stop services
        fi
        docker run -d -p 6379:6379/tcp --name="location_redis" redis
        ;;

      # Pulls, builds and starts all containers.
      *)
        $0 $1 services
        $0 $1 scheduler
        $0 $1 worker
        $0 $1 web
        ;;

    esac
    ;;

  # Stops some/all of our containers.
  stop)

    case "$2" in

      # Kills and removes the scheduler container.
      scheduler)
        SCHEDULER_ID="$(docker ps -a -q --filter name=location_scheduler)"
        if [ ! -z "$SCHEDULER_ID" ]; then
          docker kill location_scheduler >/dev/null
          docker rm location_scheduler >/dev/null
        fi
        ;;

      # Kills and removes the web container.
      web)
        WEB_ID="$(docker ps -a -q --filter name=location_web)"
        if [ ! -z "$WEB_ID" ]; then
          docker kill location_web >/dev/null
          docker rm location_web >/dev/null
        fi
        ;;

      # Kills and removes the worker container.
      worker)
        WORKER_ID="$(docker ps -a -q --filter name=location_worker)"
        if [ ! -z "$WORKER_ID" ]; then
          docker kill location_worker >/dev/null
          docker rm location_worker >/dev/null
        fi
        ;;

      # Stops the service containers.
      services)
        MYSQL_ID="$(docker ps -a -q --filter name=location_mysql)"
        if [ ! -z "$MYSQL_ID" ]; then
          docker kill location_mysql >/dev/null
          docker rm location_mysql >/dev/null
        fi
        REDIS_ID="$(docker ps -a -q --filter name=location_redis)"
        if [ ! -z "$REDIS_ID" ]; then
          docker kill location_redis >/dev/null
          docker rm location_redis >/dev/null
        fi
        ;;

      # Kills and removes all containers.
      *)
        $0 $1 scheduler
        $0 $1 web
        $0 $1 worker
        $0 $1 services
        ;;

    esac
    ;;

  # Restarts some/all of the containers.
  restart)

    case "$2" in

      # Restarts the scheduler container.
      scheduler)
        $0 stop scheduler
        $0 start scheduler
        ;;

      # Restarts the web container.
      web)
        $0 stop web
        $0 start web
        ;;

      # Restarts the worker container.
      worker)
        $0 stop worker
        $0 start worker
        ;;

      # Restarts the services.
      services)
        $0 stop services
        $0 start services
        ;;

      # Restarts all containers.
      *)
        $0 stop
        $0 start
        ;;

    esac
    ;;

  # Runs command inside the container.
  run)
    $0 start services
    docker run -it --rm \
        -e "REDIS_HOST=`docker inspect --format '{{ .NetworkSettings.IPAddress }}' location_redis`" \
        -e "DB_HOST=`docker inspect --format '{{ .NetworkSettings.IPAddress }}' location_mysql`" \
        -e "DB_USER=location" -e "DB_PWD=location" \
        --name="location_shell" \
        --volume `pwd`/docs/build/html:/app/docs/build/html \
        --volume `pwd`/ichnaea/content/static/tiles:/app/ichnaea/content/static/tiles \
        mozilla/location $2 $3 $4 $5 $6 $7 $8 $9
    ;;

  # Runs alembic inside the container.
  alembic)
    $0 run alembic $2 $3 $4 $5 $6 $7 $8 $9
    ;;

  # Updates CSS resources using a special node container.
  css)
    docker run -it --rm \
        --volume `pwd`:/app mozilla/location_node \
        make -f node.make css
    ;;

  # Update the docs inside the container.
  docs)
    $0 run docs
    ;;

  # Updates JS resources using a special node container.
  js)
    docker run -it --rm \
        --volume `pwd`:/app mozilla/location_node \
        make -f node.make js
    ;;

  local_map)
    $0 run local_map
    ;;

  # Open a shell inside the container.
  shell)
    $0 run shell
    ;;

  # Run the tests inside the container.
  test)
    $0 run test $2 $3 $4 $5 $6 $7 $8 $9
    ;;

  # Shows usage information.
  help)
    echo "Usage: $0 {build|start|stop|restart|run|alembic|css|docs|js|local_map|shell|test|help}"
    ;;

  # Shows help message.
  *)
    $0 help
    ;;

esac
