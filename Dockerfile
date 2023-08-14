# build boost libraries for mapnik
FROM ubuntu:20.04 as boost_build

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y software-properties-common \
    build-essential g++ python3-dev autotools-dev libicu-dev libbz2-dev wget 

WORKDIR /boost
RUN wget https://boostorg.jfrog.io/artifactory/main/release/1.79.0/source/boost_1_79_0.tar.gz
RUN tar -zxvf boost_1_79_0.tar.gz
WORKDIR /boost/boost_1_79_0
# we make sure to build only required libs
RUN ./bootstrap.sh --prefix=/tmp/boost/ --with-python=/usr/bin/python3 --with-libraries=system,filesystem,thread,regex,program_options,python
RUN ./b2
RUN ./b2 install


# build proj - optional dependency of mapnik that is required in this case
FROM ubuntu:20.04 as proj_build

WORKDIR /proj
RUN apt update && apt install -y sqlite3 libsqlite3-dev cmake g++ wget
RUN wget https://download.osgeo.org/proj/proj-9.0.1.tar.gz
RUN tar -zxvf proj-9.0.1.tar.gz
RUN cd proj-9.0.1 && mkdir build && cd build && cmake -DCMAKE_INSTALL_PREFIX:PATH=/tmp/proj -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_APPS=OFF -DBUILD_TESTING=OFF -DENABLE_CURL=OFF -DENABLE_TIFF=OFF .. \
  && cmake --build . \
  && cmake --build . --target install


# build mapnik and pythin-mapnik
FROM ubuntu:20.04 as mapnik_build

# get the built libraries from previous stages
COPY --from=boost_build /tmp/boost/ /usr/local/
COPY --from=proj_build /tmp/proj/ /usr/local/

WORKDIR /mapnik
RUN apt-get update && apt install -y software-properties-common wget gpg-agent && \
  sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' \
  && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - &&  \
  add-apt-repository ppa:deadsnakes/ppa && apt update && apt install -y python3.8 \
  git libharfbuzz-dev libfreetype-dev libxml2-dev cmake g++ python3.8-venv python3-dev libpq-dev postgresql-server-dev-13 sqlite3 libsqlite3-dev

RUN git clone https://github.com/mapnik/mapnik.git . && git checkout 9627432723dc847e15c45065af1ce43791d91575 \
  && git submodule update --init

# we build mapnik twice because we need mapnik-config, and cmake doesnt build it, and for some reason mapnik doesnt work without the cmake compile
RUN cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX:PATH=/opt/mapnik -DPostgreSQL_TYPE_INCLUDE_DIR=/usr/include/postgresql/ -DBUILD_TESTING=OFF -DUSE_JPEG=OFF \
    -DUSE_TIFF=OFF -DUSE_WEBP=OFF -DUSE_PLUGIN_INPUT_GDAL=OFF -DUSE_PLUGIN_INPUT_OGR=OFF -DUSE_CAIRO=OFF -DBUILD_DEMO_VIEWER=OFF -DBUILD_DEMO_CPP=OFF -DBUILD_BENCHMARK=OFF \
    -DBUILD_UTILITY_GEOMETRY_TO_WKB=OFF -DBUILD_UTILITY_MAPNIK_INDEX=OFF -DBUILD_UTILITY_MAPNIK_RENDER=OFF \
    -DBUILD_UTILITY_OGRINDEX=OFF -DBUILD_UTILITY_PGSQL2SQLITE=OFF -DBUILD_UTILITY_SHAPEINDEX=OFF -DBUILD_UTILITY_SVG2PNG=OFF \
    && cmake --build build --target install
RUN alias python=python3 && PYTHON=python3 ./configure PREFIX=/opt/mapnik JPEG=no TIFF=no WEBP=no CPP_TESTS=no BENCHMARK=no CAIRO=no DEMO=no PGSQL2SQLITE=no SHAPEINDEX=no \
  MAPNIK_INDEX=no SVG2PNG=no MAPNIK_RENDER=no \
  && make PYTHON=python3 && make install PYTHON=python3

# check if needed
RUN cp -r /opt/mapnik/. /usr/local/

# we setup venv so its easier to copy python-mapnik
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

WORKDIR /python-mapnik
RUN git clone https://github.com/koordinates/python-mapnik .
RUN python3 setup.py develop && python3 setup.py install

RUN cd /mapnik && cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX:PATH=/opt/mapnik -DPostgreSQL_TYPE_INCLUDE_DIR=/usr/include/postgresql/ -DBUILD_TESTING=OFF -DUSE_JPEG=OFF \
    -DUSE_TIFF=OFF -DUSE_WEBP=OFF -DUSE_PLUGIN_INPUT_GDAL=OFF -DUSE_PLUGIN_INPUT_OGR=OFF -DUSE_CAIRO=OFF -DBUILD_DEMO_VIEWER=OFF -DBUILD_DEMO_CPP=OFF -DBUILD_BENCHMARK=OFF \
    -DBUILD_UTILITY_GEOMETRY_TO_WKB=OFF -DBUILD_UTILITY_MAPNIK_INDEX=OFF -DBUILD_UTILITY_MAPNIK_RENDER=OFF \
    -DBUILD_UTILITY_OGRINDEX=OFF -DBUILD_UTILITY_PGSQL2SQLITE=OFF -DBUILD_UTILITY_SHAPEINDEX=OFF -DBUILD_UTILITY_SVG2PNG=OFF \
    && cmake --build build --target install


# get and compile all the python deps in a seperate stage
FROM ubuntu:20.04 as python_deps

RUN apt update && apt install -y software-properties-common && \
  add-apt-repository ppa:deadsnakes/ppa && apt update && apt install -y python3.8 python3-pip python3.8-venv

# we setup venv so its easier to copy all the deps
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY mapproxy/requirements.txt requirements.txt
RUN pip3 install -r requirements.txt

# we edit mapproxy so it sends the right srs to mapnik
RUN sed -i -e "s/'+init=%s' % str(query\.srs\.srs_code\.lower())/'+proj=longlat +datum=WGS84 +no_defs +type=crs'/g" /opt/venv/lib/python3.8/site-packages/mapproxy/source/mapnik.py    


# fetching all the static resources required for the style
FROM ubuntu:20.04 as style

RUN apt update && apt install -y curl zip git && curl -fsSL https://deb.nodesource.com/setup_16.x | bash - \
    && apt install -y nodejs
RUN git clone https://github.com/MapColonies/openstreetmap-carto /tmp/openstreetmap-carto  \ 
    && cd /tmp/openstreetmap-carto \
    && git checkout flex/master \
    && ./scripts/get-fonts.sh \
    && npm install -g carto \
    && carto project.mml > mapnik.xml \
    && mkdir /carto \
    && cp -r patterns symbols fonts mapnik.xml /carto 


FROM ubuntu:20.04
WORKDIR /mapproxy

ENV \
    # Run
    PROCESSES=6 \
    THREADS=10 \
    UWSGI_SOCKET_PATH=/mnt/socket/mapproxy.sock \
    # Run using uwsgi. This is the default behaviour. Alternatively run using the dev server. Not for production settings
    PRODUCTION=true \
    TELEMETRY_TRACING_ENABLED='false' \
    # Set telemetry endpoint
    TELEMETRY_ENDPOINT='localhost:4317' \
    OTEL_RESOURCE_ATTRIBUTES='service.name=mapcolonies,application=mapproxy' \
    OTEL_SERVICE_NAME='mapproxy' \
    TELEMETRY_SAMPLING_RATIO_DENOMINATOR=1000 \
    # without this python-mapnik fails to locate the mapnik lib
    LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib \
    PATH="/opt/venv/bin:$PATH" \
    DEBIAN_FRONTEND=noninteractive

# copying all the compilation artifacts into the final image
COPY --from=boost_build /tmp/boost/ /usr/local/
COPY --from=proj_build /tmp/proj/ /usr/local/
COPY --from=mapnik_build /opt/mapnik/ /usr/local/

# installing all the operating system dependencies - mostly libs
RUN apt-get update && apt install -y --no-install-recommends software-properties-common wget gpg-agent && \
  sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' && \
  wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - && apt-get update && \
  add-apt-repository ppa:deadsnakes/ppa && apt update && apt install -y --no-install-recommends python3.8 \
  libicu-dev libbz2-dev sqlite3 libsqlite3-dev libharfbuzz-dev libfreetype-dev libxml2-dev libpq-dev libpython3.8-dev gettext-base

# copying all the python dependencies
COPY --from=mapnik_build /opt/venv /opt/venv
COPY --from=python_deps /opt/venv /opt/venv

# mapproxy setup
COPY mapproxy/uwsgi.default.ini /settings/uwsgi.default.ini
COPY mapproxy/. .
RUN chmod a+x start.sh && chgrp -R 0 /mapproxy /settings && \
    chmod -R g=u /mapproxy /settings && \
    # setup for postgresql certs directory
    mkdir /.postgresql && chmod g+w /.postgresql 

# style setup
COPY --from=style /carto /carto

# creating user to simulate openshift
RUN useradd -ms /bin/bash user && usermod -a -G root user
USER user

ENTRYPOINT [ "/mapproxy/start.sh" ]
CMD ["mapproxy-util", "serve-develop", "-b", "0.0.0.0:8080", "mapproxy.yaml"]
