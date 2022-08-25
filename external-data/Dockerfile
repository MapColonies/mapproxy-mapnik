FROM osgeo/gdal:ubuntu-small-3.5.1

WORKDIR /app

RUN apt update && apt install -y wget python3 python3-pip

RUN mkdir /data  \
    && wget -P /data https://osmdata.openstreetmap.de/download/simplified-water-polygons-split-3857.zip \
    && wget -P /data https://osmdata.openstreetmap.de/download/water-polygons-split-4326.zip \
    && wget -P /data https://osmdata.openstreetmap.de/download/antarctica-icesheet-polygons-3857.zip \
    && wget -P /data https://osmdata.openstreetmap.de/download/antarctica-icesheet-outlines-3857.zip \
    && wget -P /data https://naturalearth.s3.amazonaws.com/110m_cultural/ne_110m_admin_0_boundary_lines_land.zip \
    && wget -P /data https://naciscdn.org/naturalearth/10m/cultural/ne_10m_admin_0_countries_isr.zip \
    && wget -P /data https://naciscdn.org/naturalearth/10m/cultural/ne_10m_admin_0_boundary_lines_land.zip \
    && wget -P /data https://naciscdn.org/naturalearth/10m/cultural/ne_10m_populated_places.zip
COPY requirements.txt requirements.txt
RUN pip install -r requirements.txt
COPY external-data.yml .
COPY get-external-data.py .
RUN chmod a+x get-external-data.py
ENTRYPOINT [ "./get-external-data.py" ]