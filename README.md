# mapproxy-mapnik
This repository contains A docker image with [MapProxy](https://github.com/mapproxy/mapproxy) and [Mapnik](https://github.com/mapnik/mapnik) compiled to facilitate rendering of OSM carto style.
The style itself can be found in the following repo: https://github.com/MapColonies/openstreetmap-carto

In addition the repository contains an image for importing the static data required by the style.

## Deployment guide

### Building the images
1. Build the external data image:
```sh
docker build -t external-data --file=external-data/Dockerfile external-data/.
```
2. Build the mapproxy image:
```sh
docker build -t mapproxy-mapnik .
```

### Preparing the database
0. The guides assumes that both the DB and mapnik are running on docker on the same machine with a shared network between them. If you are trying to deploy to a already running DB you can  change the values accordingly.
1. Create A docker network:
```sh
docker network create mapproxy-mapnik
```
2. Run postgis container:
```sh
docker run -d --name mapnik-pg --network=mapproxy-mapnik -p 5432:5432 -e POSTGRES_PASSWORD=postgres postgis/postgis:14-3.3
```
3. Create a database for the OSM data:
```sh
docker run --rm --network=mapproxy-mapnik -e PGPASSWORD=postgres postgis/postgis:14-3.3 psql -h mapnik-pg -U postgres -c "CREATE DATABASE osm"
```
4. Enable the postgis and hstore extensions in your postgres database:
```bash
docker run --rm --network=mapproxy-mapnik -e PGPASSWORD=postgres postgis/postgis:14-3.3 psql -h mapnik-pg -d osm -U postgres -c "CREATE EXTENSION hstore; CREATE EXTENSION postgis;"
```
### Populating the database
1. Run the external loading image:
```sh
docker run --rm --network=mapproxy-mapnik -e PGPASSWORD=postgres  external-data --no-update --host mapnik-pg --database osm --username postgres
```
2. Load the OSM data into the database using osm2pgsql. You can use either the binary itself or the [osm2pgsql-wrapper](https://github.com/MapColonies/osm2pgsql-wrapper). Here we are using the binary itself for simplicity

    1. Fetch an OSM dump from geobafrik:
    ```sh
    wget http://download.geofabrik.de/asia/israel-and-palestine-latest.osm.pbf
    ```
    2. Load the OSM dump into the DB:
    ```sh
    osm2pgsql --create --host localhost --database osm --username postgres --password --slim --output=flex --style=openstreetmap.lua israel-and-palestine-latest.osm.pbf
    ```
### Running MapProxy
1. Run the following command to start the server pointing to the DB populated in the previous stage.
```sh
docker run --rm --network=mapproxy-mapnik -e PGHOST=mapnik-pg -e PGDATABASE=osm -e PGUSER=postgres -e PGPASSWORD=postgres -e PRODUCTION=false -p 8080:8080 mapproxy-mapnik
```

### Validating that everything is OK
1. Go to the MapProxy demo page at http://localhost:8080/demo/.
2. Change the Coordinate-System setting to `EPSG:4326`
3. Click on the `png` link.
4. Browse the map and check that it is working as intended. Be patient as the rendering of each image can take some time