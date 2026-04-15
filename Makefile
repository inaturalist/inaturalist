build :
	docker compose build

clean :
	docker compose down --remove-orphans
	docker image prune
	docker volume prune

services :
	docker compose build --parallel es memcached redis pg
	docker compose up -d es memcached redis pg

services-api :
	docker compose build --parallel es memcached redis pg
	docker compose up -d es memcached redis pg
ifdef API_PATH
	docker compose -f $(API_PATH)/docker-compose.yml -f $(API_PATH)/docker-compose.override.yml up --build
else
	docker compose -f ../iNaturalistAPI/docker-compose.yml -f ../iNaturalistAPI/docker-compose.override.yml up --build
endif

services-vision-api :
ifdef VISION_API_PATH
	docker compose -f $(VISION_API_PATH)/docker-compose.yml -f $(VISION_API_PATH)/docker-compose.override.yml up --build
else
	docker compose -f ../inatVisionAPI/docker-compose.yml -f ../inatVisionAPI/docker-compose.override.yml up --build
endif

stop :
	docker compose stop
