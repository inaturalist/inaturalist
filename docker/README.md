
### Local environment

Local environment will run locally:
- Postgresql
- Elastic Search
- Redis
- Memcached
- iNaturalist - Rails application
- iNaturalist API - NodeJS application

Start the local environment by using the `docker-compose.local.yml` compose file
```
docker compose -f docker-compose.local.yml up -d
```

After the first start, you need to initialize the Postgresql database and the Elastic Search indices. \
Be really careful, these commands will delete all data.

To initialize the Postgresql database, run the following commands:
```
docker compose -f docker-compose.local.yml run -ti rails rake db:drop
docker compose -f docker-compose.local.yml run -ti rails rake db:setup
```

To initialize the Elastic Search indices, run the following commands:
```
docker compose -f docker-compose.local.yml run -ti rails rake es:rebuild
```

Then restart the rails and node applications
```
docker compose -f docker-compose.local.yml up -d rails
docker compose -f docker-compose.local.yml up -d api
```

### Staging environment

Staging environment will run locally:
- Redis
- Memcached
- iNaturalist - Rails application
- iNaturalist API - NodeJS application

The staging environment should connect to existing Postgresql database and Elastic Search.

Edit the `docker-compose.staging.yml` compose file \
For both `rails` and `api` services: 
- Set the Postgresql password of inaturalist user in `INAT_DB_PASS` environment property
- Set the Postgresql IP in `extra_host` section: `pg:255.255.255.255`
- Set the Elastic Search IP in `extra_host` section: `es:255.255.255.255`

Start the staging environment by using the `docker-compose.staging.yml` compose file
```
docker compose -f docker-compose.staging.yml up -d
```

