# ---------------------------------------------------------------------------- #
#                                  INCEPTION                                    #
# ---------------------------------------------------------------------------- #

COMPOSE   = docker compose -f srcs/docker-compose.yml
DB_DIR    = $(HOME)/data/mariadb
WP_DIR    = $(HOME)/data/wordpress

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
	-docker image rm -f mariadb:1.0 wordpress:1.0 nginx:1.0

re: fclean all

logs:
	$(COMPOSE) logs -f

ps:
	$(COMPOSE) ps
