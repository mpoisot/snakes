FROM python:3.8-slim-buster as base

RUN apt-get update && \
  apt-get install -y --no-install-recommends python3-dev gcc && \
  rm -rf /var/lib/apt/lists/*

# Non-cuda (CPU only) pytorch libs save more than a GIG vs a simple `pip install torch torchvision`.
# Even so, python libs still contribute >700 MB.
# Get exact pytorch PIP cmd from this page, using settings: stable, linux, pip, python, CUDA=none.
# https://pytorch.org/get-started/locally/

RUN pip install --quiet --no-cache-dir \
  starlette uvicorn python-multipart aiohttp \
  torch==1.5.0+cpu torchvision==0.6.0+cpu -f https://download.pytorch.org/whl/torch_stable.html \
  fastai~=1.0


##########################################

FROM python:3.8-slim-buster as prod

COPY --from=base /usr/local/lib/python3.8/site-packages /usr/local/lib/python3.8/site-packages

WORKDIR /app
COPY cougar.py cougar.py
COPY training/trained_model.pkl training/trained_model.pkl

EXPOSE ${PORT}

# Run the image as a non-root user to ensure it will work on Heroku
RUN adduser --disabled-password --gecos '' someuser
USER someuser

# Start the server. Shell CMD so process sees all ENV vars
CMD python cougar.py serve


##########################################

FROM base as dev

# Download pretrained models
COPY download.py download.py
RUN python download.py

RUN apt-get update && \
  apt-get install -y --no-install-recommends git && \
  rm -rf /var/lib/apt/lists/*

RUN pip install --quiet --no-cache-dir jupyter notebook jupyter_contrib_nbextensions pylint black

WORKDIR /app

EXPOSE ${PORT}

# Start the server. Shell CMD so process sees all ENV vars
# Expects code to be mounted over /app
CMD python cougar.py serve
