# stage 1 - build APBS and PDB2PQR
FROM ubuntu:18.04 as apbs_pdb2pqr-build
WORKDIR /app
RUN apt update -y \
    && apt install -y python-pip swig cmake g++ make git curl wget
    # && apt install -y python-pip swig cmake g++ make git curl wget \
    # && git clone https://github.com/Electrostatics/apbs-pdb2pqr.git
    # expected output:
    # $RELEASE_TARBALL_URL = https://api.github.com/repos/Electrostatics/apbs-pdb2pqr/tarball/apbs-1.5
RUN RELEASE_TARBALL_URL=$( \
        curl -s https://api.github.com/repos/Electrostatics/apbs-pdb2pqr/releases/latest \
        | grep tarball_url \
        | cut -d "\"" -f 4 \
    ) \
    # expected output:
    # $RELEASE_FILENAME = apbs-1.5
    && RELEASE_FILENAME=$(          \
        echo $RELEASE_TARBALL_URL | rev | cut -d "/" -f 1 | rev \
    ) \
    && echo $RELEASE_FILENAME\
    && echo $RELEASE_TARBALL_URL\
    && wget -q $RELEASE_TARBALL_URL \
    # expected output
    # $EXTRACTED_DIRNAME = Electrostatics-apbs-pdb2pqr-c0c65e4/
    && EXTRACTED_DIRNAME=$( \
        tar -tf $RELEASE_FILENAME | head -1 \
    ) \
    && tar -xzf $RELEASE_FILENAME \
    && mv $EXTRACTED_DIRNAME apbs-pdb2pqr


COPY docker_materials/build_config.py /app/apbs-pdb2pqr/pdb2pqr/build_config.py

WORKDIR /app/apbs-pdb2pqr/apbs
# RUN git submodule init \
#     && git submodule update \
#     && mkdir /app/apbs_build \
RUN mkdir /app/apbs_build \
    && cd /app/apbs_build \
    && cmake /app/apbs-pdb2pqr/apbs -DENABLE_PYTHON=ON -DBUILD_SHARED_LIBS=ON \
    && make
# WORKDIR /app/apbs_build
# RUN cmake /app/apbs-pdb2pqr/apbs -DENABLE_PYTHON=ON -DBUILD_SHARED_LIBS=ON \
#     && make

WORKDIR /app/apbs-pdb2pqr/pdb2pqr
RUN python scons/scons.py install
# COPY build_config.py apbs-pdb2pqr/pdb2pqr/build_config.py

# stage 2 - config and deploy Flask app
FROM python:2.7-alpine
WORKDIR /app
COPY . ./
COPY --from=apbs_pdb2pqr-build /app/apbs_build ./apbs_build
COPY --from=apbs_pdb2pqr-build /app/pdb2pqr_build ./pdb2pqr_build
RUN cp main_cgi.py querystatus.py ./pdb2pqr_build \
    && python -m pip install -r requirements.txt
# RUN export FLASK_APP=server.py
# RUN export FLASK_DEBUG=1
# ENV FLASK_APP=server.py
# ENV FLASK_DEBUG=1

EXPOSE 5555

ENTRYPOINT [ "python" ]
CMD [ "server.py" ]