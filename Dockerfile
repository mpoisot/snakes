FROM python:3.8-slim-buster as base

RUN apt-get update && \
  apt-get install -y --no-install-recommends python3-dev gcc && \
  rm -rf /var/lib/apt/lists/*

# Non-cuda (CPU only) pytorch libs save almost 2 GIGs off the final docker image.
RUN pip install --no-cache-dir \
  starlette uvicorn python-multipart aiohttp \
  torch==1.5.0+cpu torchvision==0.6.0+cpu -f https://download.pytorch.org/whl/torch_stable.html \
  fastai~=1.0

WORKDIR /app
COPY cougar.py cougar.py
COPY export.pkl export.pkl

# Run it once to trigger resnet download
RUN python cougar.py


##########################################

FROM base as prod

EXPOSE ${PORT}

# Run the image as a non-root user to ensure it will work on Heroku
RUN adduser --disabled-password --gecos '' someuser
USER someuser

# Start the server. Shell CMD so process sees all ENV vars
CMD python cougar.py serve


##########################################

FROM base as dev

RUN apt-get update && \
  apt-get install -y --no-install-recommends git && \
  rm -rf /var/lib/apt/lists/*

RUN pip install --quiet --no-cache-dir jupyter pylint black

WORKDIR /app

EXPOSE ${PORT}

# Start the server. Shell CMD so process sees all ENV vars
CMD python cougar.py serve
