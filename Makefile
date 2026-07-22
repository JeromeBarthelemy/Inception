# ---------------------------------------------------------------------------- #
#                                  INCEPTION                                    #
# ---------------------------------------------------------------------------- #

COMPOSE   = docker compose -f srcs/docker-compose.yml
DB_DIR    = $(HOME)/data/mariadb
WP_DIR    = $(HOME)/data/wordpress
IMAGES    = mariadb:1.0 wordpress:1.0 nginx:1.0 \
            redis:1.0 adminer:1.0 static:1.0 ftp:1.0 netdata:1.0

.PHONY: all build up down clean fclean re logs ps

all: up

up:
	mkdir -p $(DB_DIR) $(WP_DIR)
	$(COMPOSE) up -d --build

build:
	$(COMPOSE) build

down:
	$(COMPOSE) down

clean: down
	$(COMPOSE) down -v

fclean: clean
	sudo rm -rf $(HOME)/data/mariadb $(HOME)/data/wordpress
	-docker image rm -f $(IMAGES)

re: fclean all

logs:
	$(COMPOSE) logs -f

ps:
	$(COMPOSE) ps
