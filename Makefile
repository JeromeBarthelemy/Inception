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
	rm -rf $(HOME)/data/mariadb $(HOME)/data/wordpress
	-docker image rm -f mariadb wordpress nginx

re: fclean all

logs:
	$(COMPOSE) logs -f

ps:
	$(COMPOSE) ps
