ARG MAPPROXY_BASE_IMAGE

FROM ubuntu:20.04

RUN apt-get update && apt install -y software-properties-common && \
  add-apt-repository ppa:deadsnakes/ppa && apt update && apt install -y python3.8 python3-pip \
  && apt-get install -y build-essential g++ python-dev autotools-dev libicu-dev libbz2-dev wget 

WORKDIR /boost
RUN wget https://boostorg.jfrog.io/artifactory/main/release/1.73.0/source/boost_1_73_0.tar.gz
RUN tar -zxvf boost_1_73_0.tar.gz
WORKDIR /boost/boost_1_73_0
RUN ./bootstrap.sh --prefix=/usr/local --with-python=/usr/bin/python3 --with-libraries=system,filesystem,thread,regex,program_options,python
RUN ./b2
RUN ./b2 install 

# workdir /cmake

# RUN wget https://github.com/Kitware/CMake/releases/download/v3.21.0/cmake-3.21.0.tar.gz
# RUN tar xvf cmake-3.21.0.tar.gz
# RUN cd cmake-3.21.0 && ./bootstrap -- -DCMAKE_USE_OPENSSL=OFF && make && make install

RUN apt-get install -y sqlite3 libsqlite3-dev cmake libtiff-dev libcurl4-openssl-dev

WORKDIR /proj
RUN wget https://download.osgeo.org/proj/proj-9.0.1.tar.gz
RUN tar -zxvf proj-9.0.1.tar.gz
RUN cd proj-9.0.1 && mkdir build && cd build && cmake -DBUILD_APPS=OFF -DBUILD_TESTING=OFF .. \
  && cmake --build . \
  && cmake --build . --target install
# && projsync --system-directory

WORKDIR /mapnik
RUN apt install -y git
RUN git clone https://github.com/mapnik/mapnik.git && cd mapnik && git checkout 9627432723dc847e15c45065af1ce43791d91575 \
  && git submodule update --init
RUN apt-get install -y git libharfbuzz-dev libfreetype-dev libxml2-dev

RUN sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' \
  && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - && apt-get update \
  && apt install -y libpq-dev postgresql-server-dev-13

# mb start from gdal?
RUN apt install -y libgdal-dev
# no need for build dir
RUN cd mapnik && cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DPostgreSQL_TYPE_INCLUDE_DIR=/usr/include/postgresql/ -DBUILD_TESTING=OFF -DUSE_JPEG=OFF \
    -DUSE_TIFF=OFF -DUSE_WEBP=OFF -DUSE_CAIRO=OFF -DBUILD_DEMO_VIEWER=OFF -DBUILD_DEMO_CPP=OFF -DBUILD_BENCHMARK=OFF \
    -DBUILD_UTILITY_GEOMETRY_TO_WKB=OFF -DBUILD_UTILITY_MAPNIK_INDEX=OFF -DBUILD_UTILITY_MAPNIK_RENDER=OFF \
    -DBUILD_UTILITY_OGRINDEX=OFF -DBUILD_UTILITY_PGSQL2SQLITE=OFF -DBUILD_UTILITY_SHAPEINDEX=OFF -DBUILD_UTILITY_SVG2PNG=OFF \
    && cmake --build build --target install
RUN alias python=python3 && cd mapnik && PYTHON=python3 ./configure JPEG=no TIFF=no WEBP=no CPP_TESTS=no BENCHMARK=no CAIRO=no DEMO=no PGSQL2SQLITE=no SHAPEINDEX=no \
  MAPNIK_INDEX=no SVG2PNG=no MAPNIK_RENDER=no \
  && make PYTHON=python3 && make install PYTHON=python3
# RUN cd mapnik && cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DPostgreSQL_TYPE_INCLUDE_DIR=/usr/include/postgresql/ -DBUILD_TESTING=OFF -DUSE_JPEG=OFF \
#     -DUSE_TIFF=OFF -DUSE_WEBP=OFF -DUSE_CAIRO=OFF -DBUILD_DEMO_VIEWER=OFF -DBUILD_DEMO_CPP=OFF -DBUILD_BENCHMARK=OFF \
#     -DBUILD_UTILITY_GEOMETRY_TO_WKB=OFF -DBUILD_UTILITY_MAPNIK_INDEX=OFF -DBUILD_UTILITY_MAPNIK_RENDER=OFF \
#     -DBUILD_UTILITY_OGRINDEX=OFF -DBUILD_UTILITY_PGSQL2SQLITE=OFF -DBUILD_UTILITY_SHAPEINDEX=OFF -DBUILD_UTILITY_SVG2PNG=OFF \
#     && cmake --build build --target install

WORKDIR /python-mapnik
RUN git clone https://github.com/koordinates/python-mapnik
RUN cd python-mapnik && python3 setup.py develop

RUN cd /mapnik/mapnik && cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DPostgreSQL_TYPE_INCLUDE_DIR=/usr/include/postgresql/ -DBUILD_TESTING=OFF -DUSE_JPEG=OFF \
    -DUSE_TIFF=OFF -DUSE_WEBP=OFF -DUSE_CAIRO=OFF -DBUILD_DEMO_VIEWER=OFF -DBUILD_DEMO_CPP=OFF -DBUILD_BENCHMARK=OFF \
    -DBUILD_UTILITY_GEOMETRY_TO_WKB=OFF -DBUILD_UTILITY_MAPNIK_INDEX=OFF -DBUILD_UTILITY_MAPNIK_RENDER=OFF \
    -DBUILD_UTILITY_OGRINDEX=OFF -DBUILD_UTILITY_PGSQL2SQLITE=OFF -DBUILD_UTILITY_SHAPEINDEX=OFF -DBUILD_UTILITY_SVG2PNG=OFF \
    && cmake --build build --target install

WORKDIR /mapproxy

ENV \
    # Run
    PROCESSES=6 \
    THREADS=10 \
    # Run using uwsgi. This is the default behaviour. Alternatively run using the dev server. Not for production settings
    PRODUCTION=true \
    TELEMETRY_TRACING_ENABLED='false' \
    # Set telemetry endpoint
    TELEMETRY_ENDPOINT='localhost:4317' \
    OTEL_RESOURCE_ATTRIBUTES='service.name=mapcolonies,application=mapproxy' \
    OTEL_SERVICE_NAME='mapproxy' \
    TELEMETRY_SAMPLING_RATIO_DENOMINATOR=1000

COPY mapproxy/requirements.txt requirements.txt
RUN pip3 install -r requirements.txt

COPY mapproxy/uwsgi.ini /settings/uwsgi.default.ini
COPY mapproxy/. .
RUN chmod a+x start.sh
RUN sed -i -e "s/'+init=%s' % str(query\.srs\.srs_code\.lower())/'+proj=longlat +datum=WGS84 +no_defs +type=crs'/g" /usr/local/lib/python3.8/dist-packages/mapproxy/source/mapnik.py
RUN apt install -y curl zip
COPY carto/mapnik.xml /carto/mapnik.xml
RUN git clone https://github.com/gravitystorm/openstreetmap-carto.git /tmp/openstreetmap-carto  \ 
    && cd /tmp/openstreetmap-carto \
    && git checkout tags/v5.6.1 -b flex/master \
    && cp -r symbols patterns /carto/ \
    && cp scripts/get-fonts.sh /carto/ \
    && cd /carto \
    && chmod +x get-fonts.sh \
    && ./get-fonts.sh \
    && rm -r /tmp/openstreetmap-carto
    
