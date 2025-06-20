FROM ghcr.io/apeworx/ape:v0.8.36

USER 1000
WORKDIR /home/harambe/project

COPY requirements.txt .

RUN pip install -r requirements.txt && rm -f requirements.txt

