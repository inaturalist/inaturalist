build :
	docker-compose build

clean :
	docker-compose down --remove-orphans
	docker image prune
	docker volume prune

services :
	docker-compose build --parallel es memcached redis pg
	docker-compose up -d es memcached redis pg
	docker-compose -f ../iNaturalistAPI/docker-compose.yml -f ../iNaturalistAPI/docker-compose.override.yml up --build

stop :
	docker-compose stop
