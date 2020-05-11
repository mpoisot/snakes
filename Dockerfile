FROM python:3.8-slim-buster as prod

RUN apt-get update && \
  apt-get install -y --no-install-recommends python3-dev gcc && \
  rm -rf /var/lib/apt/lists/*

RUN pip install torch~=1.5 fastai~=1.0
RUN pip install starlette uvicorn python-multipart aiohttp

WORKDIR /app
COPY cougar.py cougar.py
COPY export.pkl export.pkl

# Run it once to trigger resnet download
RUN python cougar.py

EXPOSE 8008

# Start the server
CMD ["python", "cougar.py", "serve"]


##########################################

FROM prod as dev

# TODO
# install dev friendly apt-get and pip stuff. Git. VScode remote connection stuff. Jupiter packages.
RUN apt-get install -y --no-install-recommends git && \
  rm -rf /var/lib/apt/lists/*
RUN pip install jupyter

WORKDIR /app

EXPOSE 8008

# Start the server
CMD ["python", "cougar.py", "serve"]
